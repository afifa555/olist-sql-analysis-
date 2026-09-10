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

*More questions and queries coming soon as this project develops.*
