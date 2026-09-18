# Olist E-Commerce SQL Analysis

A SQL-based exploratory data analysis of the [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), a public dataset of ~100k orders from a Brazilian marketplace, spanning 9 relational CSV files (orders, order items, products, customers, payments, reviews, sellers, geolocation, and category translation).

This is my first SQL data analysis project, built to practice writing analytical SQL queries, working with multi-table joins, and drawing business insights from raw transactional data.

## Tools Used
- **SQL** (queries written and tested in DBeaver, using DuckDB's `read_csv_auto` to query CSVs directly)
- **Dataset:** Olist Brazilian E-Commerce Public Dataset (9 CSV files)

## Project Structure
```
├── README.md
└── queries/
    ├── q1_revenue_by_category.sql
    ├── q2_mom_revenue_growth.sql
    ├── q3_top3_products_per_category.sql
    ├── q4_repeat_customer_rate.sql
    └── q5_late_delivery_review_impact.sql
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

### Q3: What are the top 3 best-selling products (by revenue) within each category?

**Query:** [`queries/q3_top3_products_per_category.sql`](queries/q3_top3_products_per_category.sql)

```sql
SELECT
    product_category_name,
    product_id,
    total_revenue
FROM (
    SELECT
        p.product_category_name,
        oi.product_id,
        SUM(oi.price) AS total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY p.product_category_name
            ORDER BY SUM(oi.price) DESC
        ) AS rn
    FROM read_csv_auto('olist_products_dataset.csv') p
    JOIN read_csv_auto('olist_order_items_dataset.csv') oi
        ON p.product_id = oi.product_id
    GROUP BY
        p.product_category_name,
        oi.product_id
) ranked_products
WHERE rn <= 3
ORDER BY
    product_category_name,
    total_revenue DESC;
```

**Findings:**

Note: Olist's dataset anonymizes products — there are no product names, only category + a `product_id` hash — so findings here are framed around revenue patterns rather than specific product identities.

The query correctly returns exactly 3 rows per category, ordered by descending revenue. In `agro_industria_e_comercio`, for example, the top 3 products generated R$9,111, R$8,043, and R$6,885 respectively — the #2 and #3 products still bring in 88% and 75% of the top product's revenue. This is a fairly even spread rather than a "hero product" pattern: the category's revenue isn't dependent on a single standout item, but shared across a small handful of similarly-performing products.

*(Worth checking a few more categories to see if this even-spread pattern holds store-wide, or if some categories are more concentrated around one dominant product.)*

---

### Q4: What percentage of customers placed more than one order, and what's the average time gap between their first and second order?

**Query:** [`queries/q4_repeat_customer_rate.sql`](queries/q4_repeat_customer_rate.sql)

```sql
WITH ranked_orders AS (
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id 
            ORDER BY o.order_purchase_timestamp ASC
        ) AS rn
    FROM read_csv_auto('olist_orders_dataset.csv') o
    JOIN read_csv_auto('olist_customers_dataset.csv') c
        ON o.customer_id = c.customer_id
),

customer_orders AS (
    SELECT
        customer_unique_id,
        MAX(CASE WHEN rn = 1 THEN order_purchase_timestamp END) AS first_order,
        MAX(CASE WHEN rn = 2 THEN order_purchase_timestamp END) AS second_order
    FROM ranked_orders
    GROUP BY customer_unique_id
)

SELECT
    COUNT(second_order) * 100.0 / COUNT(DISTINCT customer_unique_id) AS pct_repeat_customers,
    AVG(second_order - first_order) AS avg_gap_between_orders
FROM customer_orders;
```

**Findings:**

Only **~3.12% of customers** placed more than one order. For the customers who did return, the average gap between their first and second order was about **79 days**.

A key detail here: this query correctly groups by `customer_unique_id` rather than `customer_id`. In this dataset, `customer_id` is actually generated per *order*, not per person — grouping on it would make every customer look like a one-time buyer. Using `customer_unique_id` is what makes it possible to detect real repeat behavior at all.

A ~3% repeat rate is notably low compared to typical e-commerce benchmarks (often 20-30%+), but this appears to be a real characteristic of Olist rather than a data issue — Olist is a multi-seller marketplace, so customers may build loyalty toward individual sellers rather than the platform itself, reducing platform-level repeat purchases.

---

### Q5: Is there a relationship between late deliveries and low review scores?

**Query:** [`queries/q5_late_delivery_review_impact.sql`](queries/q5_late_delivery_review_impact.sql)

```sql
SELECT
    CASE
        WHEN o.order_delivered_customer_date IS NULL THEN 'Not Delivered / In Transit'
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 'On-Time / Early'
        ELSE 'Late'
    END AS delivery_status,
    AVG(r.review_score) AS avg_review_score
FROM read_csv_auto('olist_orders_dataset.csv') o
JOIN read_csv_auto('olist_order_reviews_dataset.csv') r
    ON o.order_id = r.order_id
GROUP BY delivery_status;
```

**Findings:**

There's a clear, strong relationship between delivery timing and customer satisfaction:

| Delivery Status | Avg. Review Score |
|---|---|
| On-Time / Early | 4.29 |
| Late | 2.57 |
| Not Delivered / In Transit | 1.76 |

Orders delivered late score **1.7 points lower on average** than on-time orders — a substantial drop on a 5-point scale. This suggests delivery reliability is one of the strongest drivers of customer satisfaction in this dataset, and likely a high-leverage area for the business to invest in (e.g. logistics, carrier selection, more accurate estimated delivery dates).

One caveat: the "Not Delivered / In Transit" bucket includes orders with a missing `order_delivered_customer_date`, which isn't always a literal "never arrived" — in some cases delivery data may simply be missing or a review was left before delivery was recorded. The very low score here likely still reflects real dissatisfaction (delayed or failed deliveries), but the label itself is an approximation rather than a guarantee the package never arrived.

---

## Key Takeaways

- **Revenue is unevenly distributed but not monopolized**: `beleza_saude` leads in total revenue through volume, while niche categories like `pcs` earn more per order — different categories succeed in different ways, and even within a category, revenue tends to be shared across several products rather than one dominant item (Q1, Q3).
- **Growth is volatile, not broken**: raw month-over-month percentages looked alarming at first glance, but tracing them back to the underlying revenue numbers showed the extreme swings were caused by an early launch period and a mid-month data cutoff — not real business instability (Q2).
- **Customer loyalty is low**: only ~3% of customers return for a second order, which is atypical for e-commerce but consistent with Olist's multi-seller marketplace model, where loyalty may sit with individual sellers rather than the platform (Q4).
- **Delivery speed strongly predicts satisfaction**: late deliveries are associated with a ~1.7-point drop in average review score — one of the clearest, most actionable patterns in the dataset (Q5).

## What I'd Explore Next
- Seasonality in monthly revenue (e.g. holiday spikes)
- Whether repeat customers (Q4) also leave higher review scores than one-time buyers
- Delivery time by seller or region, to see if late deliveries are concentrated in specific areas

---

* — feedback and suggestions are welcome.*
