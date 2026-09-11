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
        FROM read_csv_auto('/Users/afifagilani/Documents/sql project 1st/olist_dataset_9csvs/olist_orders_dataset.csv') o
        JOIN read_csv_auto('/Users/afifagilani/Documents/sql project 1st/olist_dataset_9csvs/olist_order_items_dataset.csv') oi
            ON o.order_id = oi.order_id
        GROUP BY sales_month
    ) monthly
) with_lag
ORDER BY sales_month;
