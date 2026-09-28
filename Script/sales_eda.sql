-- Sales data EDA in MySQL
-- Data: Train.csv (US superstore orders, 2015 to 2018, 9,800 rows)
-- Needs MySQL 8.0 or newer because I use window functions and CTEs.


-- ==========================================================
-- 1. Setup (run this part only once)
-- ==========================================================

USE sales_data;

-- I load everything as plain text first. The dates in the file
-- are written in two ways (08-11-2017 and 16/06/2017), so I fix
-- them in the next step instead of letting MySQL guess.
DROP TABLE IF EXISTS train_raw;

CREATE TABLE train_raw (
    order_id       VARCHAR(20),
    order_date     VARCHAR(15),
    ship_date      VARCHAR(15),
    ship_mode      VARCHAR(30),
    customer_id    VARCHAR(15),
    customer_name  VARCHAR(60),
    segment        VARCHAR(20),
    country        VARCHAR(30),
    city           VARCHAR(60),
    state          VARCHAR(40),
    postal_code    VARCHAR(10),
    region         VARCHAR(15),
    product_id     VARCHAR(20),
    category       VARCHAR(30),
    sub_category   VARCHAR(30),
    product_name   VARCHAR(255),
    sales          VARCHAR(20)
);

-- MySQL only reads files from its secure folder. Check the path with:
--   SHOW VARIABLES LIKE 'secure_file_priv';
-- and copy Train.csv into that folder first.
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/Train.csv'
INTO TABLE train_raw
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 LINES;

-- Should be 9800
SELECT COUNT(*) FROM train_raw;


-- ==========================================================
-- 2. Clean the data
-- ==========================================================
-- What I fix here:
--   * turn the date text into real dates (day-month-year)
--   * empty postal codes become NULL
--   * sales becomes a decimal number
--   * one order line is repeated twice, DISTINCT removes it

DROP TABLE IF EXISTS orders;

CREATE TABLE orders (
    order_id       VARCHAR(20),
    order_date     DATE,
    ship_date      DATE,
    ship_mode      VARCHAR(30),
    customer_id    VARCHAR(15),
    customer_name  VARCHAR(60),
    segment        VARCHAR(20),
    country        VARCHAR(30),
    city           VARCHAR(60),
    state          VARCHAR(40),
    postal_code    VARCHAR(10),
    region         VARCHAR(15),
    product_id     VARCHAR(20),
    category       VARCHAR(30),
    sub_category   VARCHAR(30),
    product_name   VARCHAR(255),
    sales          DECIMAL(12,4)
);

INSERT INTO orders (
    order_id, order_date, ship_date, ship_mode, customer_id, customer_name,
    segment, country, city, state, postal_code, region, product_id,
    category, sub_category, product_name, sales
)
SELECT DISTINCT
    TRIM(order_id),
    STR_TO_DATE(REPLACE(TRIM(order_date), '/', '-'), '%d-%m-%Y'),
    STR_TO_DATE(REPLACE(TRIM(ship_date),  '/', '-'), '%d-%m-%Y'),
    TRIM(ship_mode),
    TRIM(customer_id),
    TRIM(customer_name),
    TRIM(segment),
    TRIM(country),
    TRIM(city),
    TRIM(state),
    NULLIF(TRIM(postal_code), ''),
    TRIM(region),
    TRIM(product_id),
    TRIM(category),
    TRIM(sub_category),
    TRIM(product_name),
    CAST(TRIM(sales) AS DECIMAL(12,4))
FROM train_raw;

-- 9800 raw rows and 9799 clean rows, so one duplicate was removed
SELECT
    (SELECT COUNT(*) FROM train_raw) AS raw_rows,
    (SELECT COUNT(*) FROM orders)    AS clean_rows;


-- ==========================================================
-- 3. Quick data checks
-- ==========================================================

-- Did every date convert properly? Both numbers should be 0.
SELECT
    SUM(order_date IS NULL) AS bad_order_dates,
    SUM(ship_date  IS NULL) AS bad_ship_dates
FROM orders;

-- Any missing values?
SELECT
    SUM(order_id    IS NULL OR order_id    = '') AS missing_order_id,
    SUM(customer_id IS NULL OR customer_id = '') AS missing_customer_id,
    SUM(city        IS NULL OR city        = '') AS missing_city,
    SUM(postal_code IS NULL)                     AS missing_postal_code,
    SUM(sales       IS NULL)                     AS missing_sales
FROM orders;

-- Only postal code has gaps. Which rows?
SELECT city, state, COUNT(*) AS rows_missing
FROM orders
WHERE postal_code IS NULL
GROUP BY city, state;
-- Finding: all 11 are from Burlington, Vermont.

-- Does any order ship before it was placed? Should be 0.
SELECT COUNT(*) AS ship_before_order
FROM orders
WHERE ship_date < order_date;

-- Any zero or negative sales? Should be 0.
SELECT COUNT(*) AS bad_sales
FROM orders
WHERE sales <= 0;

-- How many different things are in the data?
SELECT
    COUNT(*)                     AS n_rows,
    COUNT(DISTINCT order_id)     AS n_orders,
    COUNT(DISTINCT customer_id)  AS n_customers,
    COUNT(DISTINCT product_id)   AS n_products,
    COUNT(DISTINCT city)         AS n_cities,
    COUNT(DISTINCT state)        AS n_states,
    COUNT(DISTINCT sub_category) AS n_sub_categories
FROM orders;

-- Does one customer id always have one name? Should return no rows.
SELECT customer_id, COUNT(DISTINCT customer_name) AS names
FROM orders
GROUP BY customer_id
HAVING names > 1;

-- What dates does the data cover?
SELECT MIN(order_date) AS first_order, MAX(order_date) AS last_order
FROM orders;


-- ==========================================================
-- 4. Big numbers
-- ==========================================================

SELECT
    ROUND(SUM(sales), 2)                            AS total_sales,
    COUNT(DISTINCT order_id)                        AS orders,
    COUNT(DISTINCT customer_id)                     AS customers,
    ROUND(AVG(sales), 2)                            AS avg_line_sales,
    ROUND(MAX(sales), 2)                            AS biggest_line,
    ROUND(SUM(sales) / COUNT(DISTINCT order_id), 2) AS avg_order_value
FROM orders;
-- Finding: total sales are about 2.26M from 4,922 orders and 793 customers.
-- An average order is worth about 459.


-- ==========================================================
-- 5. Sales by category, region, segment and shipping
-- ==========================================================

-- Which category sells the most?
SELECT
    category,
    ROUND(SUM(sales), 2)                                 AS total_sales,
    ROUND(100 * SUM(sales) / SUM(SUM(sales)) OVER (), 2) AS pct_of_sales
FROM orders
GROUP BY category
ORDER BY total_sales DESC;
-- Finding: the three categories are close. Technology 36.6%,
-- Furniture 32.2%, Office Supplies 31.2%.

-- Which sub-categories are the best sellers?
SELECT
    category,
    sub_category,
    ROUND(SUM(sales), 2)                                 AS total_sales,
    ROUND(100 * SUM(sales) / SUM(SUM(sales)) OVER (), 2) AS pct_of_sales
FROM orders
GROUP BY category, sub_category
ORDER BY total_sales DESC;
-- Finding: Phones (14.5%) and Chairs (14.3%) are far ahead of the rest.

-- Sales by region
SELECT
    region,
    COUNT(DISTINCT order_id)                             AS orders,
    ROUND(SUM(sales), 2)                                 AS total_sales,
    ROUND(100 * SUM(sales) / SUM(SUM(sales)) OVER (), 2) AS pct_of_sales
FROM orders
GROUP BY region
ORDER BY total_sales DESC;
-- Finding: West is the biggest region (31.4%) and South is the smallest.

-- Category by region
SELECT
    category,
    ROUND(SUM(CASE WHEN region = 'West'    THEN sales END), 2) AS west,
    ROUND(SUM(CASE WHEN region = 'East'    THEN sales END), 2) AS east,
    ROUND(SUM(CASE WHEN region = 'Central' THEN sales END), 2) AS central,
    ROUND(SUM(CASE WHEN region = 'South'   THEN sales END), 2) AS south
FROM orders
GROUP BY category
ORDER BY category;

-- Sales by customer segment
SELECT
    segment,
    COUNT(DISTINCT customer_id)                        AS customers,
    ROUND(SUM(sales), 2)                               AS total_sales,
    ROUND(SUM(sales) / COUNT(DISTINCT customer_id), 2) AS sales_per_customer
FROM orders
GROUP BY segment
ORDER BY total_sales DESC;
-- Finding: Consumer brings the most sales because it has the most customers.
-- Per customer, the three segments are almost the same.

-- Which shipping mode do people choose?
SELECT
    ship_mode,
    COUNT(DISTINCT order_id)                                AS orders,
    ROUND(100 * COUNT(DISTINCT order_id)
          / SUM(COUNT(DISTINCT order_id)) OVER (), 2)       AS pct_of_orders
FROM orders
GROUP BY ship_mode
ORDER BY orders DESC;
-- Finding: Standard Class is used for about 60% of orders.

-- How many days does each shipping mode take?
SELECT
    ship_mode,
    ROUND(AVG(DATEDIFF(ship_date, order_date)), 2) AS avg_days,
    MIN(DATEDIFF(ship_date, order_date))           AS min_days,
    MAX(DATEDIFF(ship_date, order_date))           AS max_days
FROM orders
GROUP BY ship_mode
ORDER BY avg_days;


-- ==========================================================
-- 6. Where do the sales come from?
-- ==========================================================

-- Top 10 states
SELECT state, ROUND(SUM(sales), 2) AS total_sales
FROM orders
GROUP BY state
ORDER BY total_sales DESC
LIMIT 10;
-- Finding: California (about 446K) and New York (about 306K) lead.

-- Top 10 cities
SELECT city, state, ROUND(SUM(sales), 2) AS total_sales
FROM orders
GROUP BY city, state
ORDER BY total_sales DESC
LIMIT 10;
-- Finding: New York City is number one with 252,462.55.

-- Top 10 products
SELECT product_name, sub_category, ROUND(SUM(sales), 2) AS total_sales
FROM orders
GROUP BY product_id, product_name, sub_category
ORDER BY total_sales DESC
LIMIT 10;


-- ==========================================================
-- 7. Customers
-- ==========================================================

-- Top 10 customers
SELECT
    customer_name,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(sales), 2)     AS total_sales
FROM orders
GROUP BY customer_id, customer_name
ORDER BY total_sales DESC
LIMIT 10;
-- Finding: Sean Miller is the top customer with 25,043.05.

-- How much do the best customers matter?
-- I split customers into 10 equal groups. Group 1 is the top 10%.
WITH customer_sales AS (
    SELECT customer_id, SUM(sales) AS s
    FROM orders
    GROUP BY customer_id
),
grouped AS (
    SELECT s, NTILE(10) OVER (ORDER BY s DESC) AS grp
    FROM customer_sales
)
SELECT
    grp,
    COUNT(*)                                       AS customers,
    ROUND(SUM(s), 2)                               AS sales,
    ROUND(100 * SUM(s) / SUM(SUM(s)) OVER (), 2)   AS pct_of_sales
FROM grouped
GROUP BY grp
ORDER BY grp;
-- Finding: the top 10% of customers bring about 31% of all sales.

-- How many orders does a customer place?
WITH per_customer AS (
    SELECT customer_id, COUNT(DISTINCT order_id) AS n_orders
    FROM orders
    GROUP BY customer_id
)
SELECT n_orders, COUNT(*) AS customers
FROM per_customer
GROUP BY n_orders
ORDER BY n_orders;


-- ==========================================================
-- 8. Sales over time
-- ==========================================================

-- Sales and growth for each year
WITH yearly AS (
    SELECT YEAR(order_date) AS yr, SUM(sales) AS s
    FROM orders
    GROUP BY YEAR(order_date)
)
SELECT
    yr,
    ROUND(s, 2) AS total_sales,
    ROUND(100 * (s - LAG(s) OVER (ORDER BY yr)) / LAG(s) OVER (ORDER BY yr), 2) AS growth_pct
FROM yearly
ORDER BY yr;
-- Finding: sales dropped 4.2% in 2016, then grew 30.6% in 2017.

-- Which months are strong or weak? (all years together)
SELECT
    MONTH(order_date)        AS month_no,
    ROUND(SUM(sales), 2)     AS total_sales,
    COUNT(DISTINCT order_id) AS orders
FROM orders
GROUP BY MONTH(order_date)
ORDER BY month_no;
-- Finding: sales are low in January and February and highest in
-- September, November and December.

-- Month by month, with a running total and a 3 month average
WITH monthly AS (
    SELECT DATE_FORMAT(order_date, '%Y-%m') AS ym, SUM(sales) AS s
    FROM orders
    GROUP BY DATE_FORMAT(order_date, '%Y-%m')
)
SELECT
    ym,
    ROUND(s, 2)                                                                  AS sales,
    ROUND(SUM(s) OVER (ORDER BY ym), 2)                                          AS running_total,
    ROUND(AVG(s) OVER (ORDER BY ym ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS avg_3_months
FROM monthly
ORDER BY ym;

-- Best month of each year
WITH monthly AS (
    SELECT YEAR(order_date) AS yr, MONTH(order_date) AS mo, SUM(sales) AS s
    FROM orders
    GROUP BY YEAR(order_date), MONTH(order_date)
),
ranked AS (
    SELECT monthly.*, ROW_NUMBER() OVER (PARTITION BY yr ORDER BY s DESC) AS rn
    FROM monthly
)
SELECT yr, mo, ROUND(s, 2) AS sales
FROM ranked
WHERE rn = 1
ORDER BY yr;

-- Category sales by year
SELECT
    YEAR(order_date) AS yr,
    ROUND(SUM(CASE WHEN category = 'Furniture'       THEN sales END), 2) AS furniture,
    ROUND(SUM(CASE WHEN category = 'Office Supplies' THEN sales END), 2) AS office_supplies,
    ROUND(SUM(CASE WHEN category = 'Technology'      THEN sales END), 2) AS technology
FROM orders
GROUP BY YEAR(order_date)
ORDER BY yr;


-- ==========================================================
-- 9. Order size and outliers
-- ==========================================================

-- How big are the order lines?
SELECT
    CASE
        WHEN sales <   50 THEN '1) under 50'
        WHEN sales <  200 THEN '2) 50 to 200'
        WHEN sales <  500 THEN '3) 200 to 500'
        WHEN sales < 1000 THEN '4) 500 to 1000'
        WHEN sales < 5000 THEN '5) 1000 to 5000'
        ELSE                   '6) 5000 and above'
    END                                                  AS bucket,
    COUNT(*)                                             AS n_lines,
    ROUND(SUM(sales), 2)                                 AS total_sales,
    ROUND(100 * SUM(sales) / SUM(SUM(sales)) OVER (), 2) AS pct_of_sales
FROM orders
GROUP BY bucket
ORDER BY bucket;

-- Median and quartiles. MySQL has no median function,
-- so I pick the middle rows by their position.
WITH ordered AS (
    SELECT sales,
           ROW_NUMBER() OVER (ORDER BY sales) AS rn,
           COUNT(*)     OVER ()               AS n
    FROM orders
)
SELECT
    (SELECT sales FROM ordered WHERE rn = CAST(n * 0.25 AS SIGNED) + 1) AS q1,
    (SELECT sales FROM ordered WHERE rn = CAST(n * 0.50 AS SIGNED) + 1) AS median,
    (SELECT sales FROM ordered WHERE rn = CAST(n * 0.75 AS SIGNED) + 1) AS q3
FROM ordered
LIMIT 1;
-- Finding: the median line is only about 54, but the average is about 231.
-- A few very big orders pull the average up.

-- Outliers: lines above Q3 + 1.5 * (Q3 - Q1)
WITH ordered AS (
    SELECT sales,
           ROW_NUMBER() OVER (ORDER BY sales) AS rn,
           COUNT(*)     OVER ()               AS n
    FROM orders
),
q AS (
    SELECT
        (SELECT sales FROM ordered WHERE rn = CAST(n * 0.25 AS SIGNED) + 1) AS q1,
        (SELECT sales FROM ordered WHERE rn = CAST(n * 0.75 AS SIGNED) + 1) AS q3
    FROM ordered
    LIMIT 1
)
SELECT
    COUNT(*)               AS outlier_lines,
    ROUND(SUM(o.sales), 2) AS outlier_sales,
    ROUND(100 * SUM(o.sales) / (SELECT SUM(sales) FROM orders), 2) AS pct_of_total_sales
FROM orders o
CROSS JOIN q
WHERE o.sales > q.q3 + 1.5 * (q.q3 - q.q1);
-- Finding: about 1,145 large lines bring in 64% of all sales.

-- The 10 biggest single lines
SELECT order_id, customer_name, product_name, ROUND(sales, 2) AS sales
FROM orders
ORDER BY sales DESC
LIMIT 10;


-- ==========================================================
-- 10. How many products make 80% of the sales?
-- ==========================================================

WITH product_sales AS (
    SELECT product_id, SUM(sales) AS s
    FROM orders
    GROUP BY product_id
),
cumulative AS (
    SELECT
        product_id,
        SUM(s) OVER (ORDER BY s DESC) / SUM(s) OVER () AS cum_share,
        ROW_NUMBER() OVER (ORDER BY s DESC)            AS rn,
        COUNT(*) OVER ()                               AS n
    FROM product_sales
)
SELECT
    MIN(rn)                          AS products_for_80pct,
    MAX(n)                           AS total_products,
    ROUND(100 * MIN(rn) / MAX(n), 1) AS pct_of_products
FROM cumulative
WHERE cum_share >= 0.8;
-- Finding: 412 of 1,861 products (about 22%) make 80% of the sales.


-- ==========================================================
-- 11. Which sub-categories are growing or shrinking?
-- ==========================================================

-- Sales of each sub-category in 2017 vs 2018, with growth in %.
WITH sub_year AS (
    SELECT
        sub_category,
        SUM(CASE WHEN YEAR(order_date) = 2017 THEN sales END) AS s_2017,
        SUM(CASE WHEN YEAR(order_date) = 2018 THEN sales END) AS s_2018
    FROM orders
    GROUP BY sub_category
)
SELECT
    sub_category,
    ROUND(s_2017, 2)                                  AS sales_2017,
    ROUND(s_2018, 2)                                  AS sales_2018,
    ROUND(s_2018 - s_2017, 2)                         AS change_amount,
    ROUND(100 * (s_2018 - s_2017) / s_2017, 2)        AS growth_pct,
    RANK() OVER (ORDER BY (s_2018 - s_2017) DESC)     AS growth_rank
FROM sub_year
ORDER BY growth_rank;
-- Finding: Phones added the most sales in 2018 (+26.7K). Appliances grew
-- fastest (+54.6%). Machines fell 22% and Envelopes fell 24%.


-- ==========================================================
-- 12. New customers vs returning customers each year
-- ==========================================================

-- A customer is "new" in the year of their first order and
-- "returning" in every later year they buy again.
WITH first_year AS (
    SELECT customer_id, MIN(YEAR(order_date)) AS first_yr
    FROM orders
    GROUP BY customer_id
),
active AS (
    SELECT DISTINCT customer_id, YEAR(order_date) AS yr
    FROM orders
)
SELECT
    a.yr,
    COUNT(*)                                       AS active_customers,
    SUM(a.yr = f.first_yr)                         AS new_customers,
    SUM(a.yr > f.first_yr)                         AS returning_customers,
    ROUND(100 * SUM(a.yr > f.first_yr) / COUNT(*), 2) AS returning_pct
FROM active a
JOIN first_year f ON f.customer_id = a.customer_id
GROUP BY a.yr
ORDER BY a.yr;
-- Finding: the store keeps very few new customers after 2015. By 2018 only
-- 11 of 690 active customers are new, so growth comes from existing buyers.


-- ==========================================================
-- 13. RFM customer segments
-- ==========================================================
-- R = days since last order (fewer is better)
-- F = number of orders
-- M = total sales
-- Each one gets a score from 1 (worst) to 5 (best) using NTILE(5).
-- "Today" is one day after the last order in the data,
-- so the result does not change depending on when I run it.
-- Note: many customers have the same number of orders, so NTILE
-- splits those ties in an arbitrary way. Treat F as a rough score.
WITH customer_stats AS (
    SELECT
        customer_id,
        customer_name,
        DATEDIFF((SELECT MAX(order_date) FROM orders) + INTERVAL 1 DAY,
                 MAX(order_date))        AS recency_days,
        COUNT(DISTINCT order_id)         AS frequency,
        SUM(sales)                       AS monetary
    FROM orders
    GROUP BY customer_id, customer_name
),
scored AS (
    SELECT
        customer_stats.*,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency)         AS f_score,
        NTILE(5) OVER (ORDER BY monetary)          AS m_score
    FROM customer_stats
),
segmented AS (
    SELECT
        scored.*,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN '1) Champions'
            WHEN f_score >= 4 AND r_score >= 3                  THEN '2) Loyal'
            WHEN m_score >= 4                                   THEN '3) Big spenders'
            WHEN r_score <= 2 AND f_score >= 3                  THEN '4) At risk'
            WHEN r_score <= 2                                   THEN '5) Lost'
            ELSE                                                     '6) Regular'
        END AS rfm_segment
    FROM scored
)
SELECT
    rfm_segment,
    COUNT(*)                                        AS customers,
    ROUND(SUM(monetary), 2)                         AS total_sales,
    ROUND(100 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 2) AS pct_of_sales,
    ROUND(AVG(recency_days), 0)                     AS avg_days_since_last_order,
    ROUND(AVG(frequency), 1)                        AS avg_orders
FROM segmented
GROUP BY rfm_segment
ORDER BY rfm_segment;
-- Finding: Champions (102 customers) bring 23.6% of sales. Big spenders
-- bring 38.8% but last ordered about 167 days ago on average, so they are
-- the group to win back first.


-- ==========================================================
-- 14. Top 3 states inside each region
-- ==========================================================

WITH state_sales AS (
    SELECT region, state, SUM(sales) AS s
    FROM orders
    GROUP BY region, state
),
ranked AS (
    SELECT
        region,
        state,
        s,
        RANK() OVER (PARTITION BY region ORDER BY s DESC)         AS rk,
        100 * s / SUM(s) OVER (PARTITION BY region)               AS pct_of_region
    FROM state_sales
)
SELECT region, rk AS state_rank, state,
       ROUND(s, 2)             AS total_sales,
       ROUND(pct_of_region, 2) AS pct_of_region
FROM ranked
WHERE rk <= 3
ORDER BY region, rk;
-- Finding: California is 63% of the West and New York is 46% of the East.
-- Texas is 34% of Central. Sales depend heavily on one state per region.


-- ==========================================================
-- 15. Do bigger baskets (more categories) mean bigger orders?
-- ==========================================================

-- How many different categories does one order contain,
-- and what is the average order value for each group?
WITH order_stats AS (
    SELECT
        order_id,
        COUNT(DISTINCT category) AS n_categories,
        COUNT(*)                 AS n_lines,
        SUM(sales)               AS order_value
    FROM orders
    GROUP BY order_id
)
SELECT
    n_categories,
    COUNT(*)                                                 AS orders,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)         AS pct_of_orders,
    ROUND(AVG(n_lines), 2)                                   AS avg_lines,
    ROUND(AVG(order_value), 2)                               AS avg_order_value,
    ROUND(SUM(order_value), 2)                               AS total_sales
FROM order_stats
GROUP BY n_categories
ORDER BY n_categories;
-- Finding: 34% of orders contain 2 or 3 categories and average 739 to 1,433,
-- against 246 for single-category orders. Cross-selling clearly raises order value.
