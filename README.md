# Olist E-Commerce SQL Analysis

A SQL-based exploratory data analysis of the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), a public dataset of ~100k orders from a Brazilian marketplace, spanning 9 relational CSV files (orders, order items, products, customers, payments, reviews, sellers, geolocation, and category translation).

This is my first SQL data analysis project, built to practice writing analytical SQL queries, working with multi-table joins, and drawing business insights from raw transactional data.

## Tools Used
- **SQL** (queries written and tested in DBeaver, using DuckDB's `read_csv_auto` to query CSVs directly)
- **Dataset:** Olist Brazilian E-Commerce Public Dataset (9 CSV files)

## Project Structure
```
├── README.md
├── queries/
│   └── q1_revenue_by_category.sql
└── outputs/
    └── q1_results.csv
```

> All monetary values are in Brazilian Real (R$), the currency used in the Olist dataset.

## Questions & Findings

### Q1: Which product categories generate the most total revenue, and what's the average order value per category?

**Query:** [`queries/q1_revenue_by_category.sql`](queries/q1_revenue_by_category.sql)

```sql
SELECT 
    p.product_category_name,
    SUM(oi.price) AS total_revenue,
    SUM(oi.price) / COUNT(DISTINCT oi.order_id) AS avg_order_value
FROM read_csv_auto('olist_order_items_dataset.csv') oi
JOIN read_csv_auto('olist_products_dataset.csv') p
    ON p.product_id = oi.product_id
GROUP BY p.product_category_name
ORDER BY total_revenue DESC;
```

**Findings:**
- `beleza_saude` (health & beauty) generates the highest total revenue at **R$ 1,258,681.34**.
- `pcs` (computers) has the highest average order value at **R$ 1,231.84** per order — far above every other category.
- These are two very different kinds of "winners": `beleza_saude` wins on volume — lots of relatively low-priced items sold often — while `pcs` wins on price per order, likely a low-volume, high-ticket category (computers are expensive but bought less frequently). This suggests different business strategies could apply: `beleza_saude` benefits from marketing that drives repeat/high-frequency purchases, while `pcs` may benefit more from optimizing margin per sale.

---

### Q2: What's the month-over-month revenue growth across the entire store — did revenue go up or down each month, and by how much?

**Query:** [`queries/q2_mom_revenue_growth.sql`](queries/q2_mom_revenue_growth.sql)

```sql
SELECT 
    sales_month,
    total_revenue,
    previous_month_sales,
    total_revenue - previous_month_sales AS revenue_change,
    ROUND(
        (total_revenue - previous_month_sales) / previous_month_sales * 100, 
    2) AS growth_pct
FROM (
    SELECT sales_month, total_revenue,
           LAG(total_revenue, 1) OVER (ORDER BY sales_month) AS previous_month_sales
    FROM (
        SELECT DATE_TRUNC('Month', o.order_purchase_timestamp) AS sales_month,
               SUM(oi.price) AS total_revenue
        FROM read_csv_auto('olist_orders_dataset.csv') o
        JOIN read_csv_auto('olist_order_items_dataset.csv') oi
            ON o.order_id = oi.order_id
        GROUP BY sales_month
    ) monthly
) with_lag
ORDER BY sales_month;
```

**Findings:**

Before trusting the month-over-month percentages, I checked the raw revenue by month and found two data quality issues at the edges of the dataset:

- **Launch period (Sept–Nov 2016):** revenue was R$267.36, R$49,507.66, and R$10.90 respectively — the store was just starting, so these early months are extremely low-volume and unstable. This is what produced the enormous 18,417% and 1,103,688% "growth" spikes in the raw output — a mathematical artifact of dividing by a near-zero prior month, not real business growth.
- **Final month (Sept 2018):** revenue was only R$145, compared to a full month's typical revenue elsewhere in the dataset. This is a data collection cutoff (the dataset ends mid-month), not an actual revenue crash — it's the source of the -99.98% drop at the end of the series.

**Excluding these three edge months**, the stable trend (2017 through mid-2018) shows month-over-month growth mostly ranging between **-26% and +52%**, with no single month showing catastrophic, sustained decline. Revenue growth is volatile month-to-month rather than steadily trending in one direction, which is typical for a marketplace still in a growth phase — worth investigating seasonality (e.g. holiday months) as a follow-up question.

---

*More questions and queries coming soon as this project develops.*
