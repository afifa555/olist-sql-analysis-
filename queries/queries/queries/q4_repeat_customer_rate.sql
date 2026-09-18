WITH ranked_orders AS (
  SELECT
    c.customer_unique_id,
    o.order_purchase_timestamp,
    ROW_NUMBER() OVER (
      PARTITION BY c.customer_unique_id 
      ORDER BY o.order_purchase_timestamp ASC
    ) AS rn
  FROM read_csv_auto('/Users/afifagilani/Documents/sql project 1st/olist_dataset_9csvs/olist_orders_dataset.csv') o
  JOIN read_csv_auto('/Users/afifagilani/Documents/sql project 1st/olist_dataset_9csvs/olist_customers_dataset.csv') c
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
