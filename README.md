# 🛒 Superstore Sales Performance Analysis: MySQL EDA + Power BI Dashboard

End-to-end sales analysis of a US superstore (2015 to 2018). Raw CSV data is cleaned and explored with **MySQL 8**, then presented in an interactive **Power BI** dashboard.

| | |
|---|---|
| **Tools** | MySQL 8.0, Power BI Desktop |
| **Data** | `Train.csv` (9,800 rows, 17 columns) |
| **Period** | 3 Jan 2015 to 30 Dec 2018 |
| **Skills shown** | Data cleaning, CTEs, window functions, RFM segmentation, cohort logic, dashboard design |

---

## 📌 Key Numbers

| Metric | Value |
|---|---|
| Total sales | **$2.26M** |
| Orders | 4,922 |
| Customers | 793 |
| Products | 1,861 |
| Average order value | $459 |
| Median order line | $54 (average line is $231, so a few big orders pull the average up) |

---

## 📂 Repository Structure

```
Superstore Sales analytics
├── Data/
│   └── Train.csv                                   # Raw dataset
├── Script/
│   └── sales_eda.sql                               # Cleaning + EDA queries (MySQL 8+)
├── Power Bi/
│   └── Superstore_Sales_Performance_Dashboard.pbix # Power BI dashboard (2 pages)
├── images/
│   ├── Sales_Overview.png                          # Dashboard page 1
│   └── Regional___Customer_Deep_Dive.png           # Dashboard page 2
└── README.md
```

---

## 🗃️ Dataset

Each row is one order line of a US superstore.

| Column | Description |
|---|---|
| Order ID, Order Date, Ship Date, Ship Mode | Order and delivery details |
| Customer ID, Customer Name, Segment | Customer details (Consumer, Corporate, Home Office) |
| Country, City, State, Postal Code, Region | Location (West, East, Central, South) |
| Product ID, Category, Sub-Category, Product Name | Product details (3 categories, 17 sub-categories) |
| Sales | Sales value of the line |

---

## 🧹 Data Cleaning (SQL)

| Problem found | Fix |
|---|---|
| Dates are written in two formats (`08-11-2017` and `16/06/2017`) | Replaced `/` with `-` and converted with `STR_TO_DATE` (day-month-year) |
| 1 duplicate row | Removed with `SELECT DISTINCT` (9,800 rows became 9,799) |
| 11 missing postal codes, all from Burlington, Vermont | Stored as `NULL`, kept the rows |
| Sales stored as text | Converted to `DECIMAL(12,4)` |
| Extra spaces in text | `TRIM` on every column |

Validation checks passed: no failed date conversions, no orders shipped before they were placed, no zero or negative sales, and one name per customer ID.

---

## 🔍 What the SQL Covers

`sales_eda.sql` has 15 sections.

| # | Section | Techniques |
|---|---|---|
| 1 to 3 | Setup, cleaning, data quality checks | `LOAD DATA`, `STR_TO_DATE`, `NULLIF` |
| 4 | Headline KPIs | Aggregates |
| 5 | Category, region, segment and shipping analysis | `SUM() OVER ()` for % share, pivots with `CASE` |
| 6 | Top states, cities and products | `GROUP BY`, `LIMIT` |
| 7 | Customers: top 10, decile analysis, order frequency | `NTILE`, CTEs |
| 8 | Time trends: yearly growth, seasonality, running total, 3-month average | `LAG`, moving window |
| 9 | Order size buckets, median and outliers (IQR method) | `ROW_NUMBER` |
| 10 | Pareto: products that make 80% of sales | Cumulative window sum |
| **11** | **Sub-category growth, 2017 vs 2018** | `RANK`, conditional aggregation |
| **12** | **New vs returning customers per year** | First-order logic with CTEs |
| **13** | **RFM customer segmentation** | `NTILE(5)`, `CASE` |
| **14** | **Top 3 states inside each region** | `RANK() OVER (PARTITION BY ...)` |
| **15** | **Basket analysis: categories per order vs order value** | Two-level aggregation |

Sections 11 to 15 are the newest additions.

---

## 💡 Key Insights

### Products
- The three categories are close: **Technology 36.6%**, Furniture 32.2%, Office Supplies 31.2%.
- **Phones (14.5%)** and **Chairs (14.3%)** are far ahead of every other sub-category.
- **Pareto effect:** 412 of 1,861 products (about 22%) generate 80% of sales.
- Between 2017 and 2018, Phones added the most sales (+$26.7K) and Appliances grew fastest (+54.6%). **Machines (−22%)** and **Envelopes (−24%)** declined.

### Geography
- **West** is the largest region (31.4%), **South** the smallest (17.2%).
- **California (19.7%)** and **New York (13.6%)** lead the states. **New York City** is the top city with $252K.
- Each region depends on one state: California is 63% of West, New York is 46% of East, Texas is 34% of Central.

### Customers
- Consumer is 51% of sales, but per customer all three segments are almost equal (about $2.8K to $2.9K).
- The **top 10% of customers bring about 31% of sales**. The top customer is Sean Miller ($25K).
- **RFM result:** Champions (102 customers) give 23.6% of sales. "Big spenders" give 38.8% but last ordered about 167 days ago on average, so they are the best group to win back.
- After 2015 very few new customers join. In 2018 only 11 of 690 active customers were new, so growth comes almost entirely from existing buyers.

### Orders and Shipping
- **Standard Class** is used for about 60% of orders and takes 5 days on average. First Class takes 2.2 days and Same Day is almost immediate.
- **Cross-selling works:** orders with 2 or 3 categories average $739 to $1,433, against $246 for single-category orders. 34% of orders already contain more than one category.
- About 1,145 large lines (IQR outliers) bring in 64% of all sales, so results are sensitive to a small number of big orders.

### Time
- Sales fell 4.2% in 2016, then grew **30.6% in 2017** and **20.3% in 2018** (2018 sales: $722K).
- Strong seasonality: January and February are weakest, while **September, November and December** are the peak months.

---

## 📊 Power BI Dashboard: Superstore Sales Performance Dashboard

The dashboard (`Superstore_Sales_Performance_Dashboard.pbix`) has two pages, filtered with slicers for Year, Month, Region, Category, Ship Mode and Segment.

**Page 1: Sales Overview**
- KPI cards: total sales, average sales, max sales, unique orders
- Sales by Category, Sub-Category and Ship Mode
- Top 10 customers and top cities by sales

**Page 2: Regional & Customer Deep Dive**
- KPI cards: total sales, average sales, max sales, total customers, unique orders
- Sales by Month (trend line)
- Sales by State (map) and by Segment (donut)
- Sales by Region and Category
- Top 5 cities and top 5 customers

### Page 1: Sales Overview

![Sales Overview](images/Sales_Overview.png)

### Page 2: Regional & Customer Deep Dive

![Regional & Customer Deep Dive](images/Regional___Customer_Deep_Dive.png)

## ▶️ How to Run

**SQL**
1. Install MySQL 8.0 or newer (window functions and CTEs are required).
2. Create a database: `CREATE DATABASE sales_data;`
3. Check your allowed upload folder with `SHOW VARIABLES LIKE 'secure_file_priv';` and copy `Data/Train.csv` there.
4. Update the file path in the `LOAD DATA INFILE` line of `Script/sales_eda.sql`, then run the script section by section.

**Power BI**
1. Open `Power Bi/Superstore_Sales_Performance_Dashboard.pbix` in Power BI Desktop.
2. If asked, point the data source to your local `Train.csv`.

---

## 🚀 Recommendations

1. **Win back "Big spenders"** with targeted offers, since they hold 39% of sales but have gone quiet.
2. **Push cross-selling** with bundles across categories, because multi-category orders are worth 3 to 6 times more.
3. **Acquire new customers.** Growth relies on the existing base, which is a risk.
4. **Review Machines and Envelopes**, the only meaningful decliners.
5. **Reduce dependence on California, New York and Texas** by growing weaker states, mainly in the South.
6. **Plan stock and campaigns** for the September to December peak.

---

## ⚠️ Limitations

- The dataset has only **sales**. There is no profit, cost or discount column, so profitability cannot be analysed.
- Some customers have identical order counts, so the frequency score in the RFM model is approximate.
- The RFM "today" date is fixed at the last order date plus one day.

---

## 👤 Author

**Mohammad Mubin Mohammad Raees**
[LinkedIn](https://www.linkedin.com/in/mubin-bagwan-4131a6347) · [GitHub](https://github.com/mrmubinbagwan886-DataAnalyst)
