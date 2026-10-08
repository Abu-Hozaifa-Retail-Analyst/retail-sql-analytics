/* ============================================================
   View: vw_CustomerRFM
   Wraps Project 02's RFM segmentation as a reusable view, so any
   query or BI tool can treat customer segments as a plain table.
   Same logic as query.sql (delivered orders only, fixed-rule
   frequency score, deterministic tie-breaking).

   Example usage:
     SELECT * FROM dbo.vw_CustomerRFM;

     SELECT rfm_segment, COUNT(*) AS customer_count
     FROM dbo.vw_CustomerRFM
     GROUP BY rfm_segment
     ORDER BY customer_count DESC;

   Dialect: SQL Server (T-SQL)
   ============================================================ */
USE RetailAnalytics;
GO

CREATE OR ALTER VIEW dbo.vw_CustomerRFM AS
WITH data_end AS (
    -- "Today" for recency: the latest order in the dataset
    -- (a historical snapshot, not live data).
    SELECT MAX(order_purchase_timestamp) AS latest_order_date
    FROM orders
),

recency AS (
    -- Days since each customer's most recent DELIVERED order.
    SELECT
        customers.customer_unique_id,
        DATEDIFF(DAY, MAX(orders.order_purchase_timestamp),
                 data_end.latest_order_date) AS recency_days
    FROM orders
    JOIN customers
        ON orders.customer_id = customers.customer_id
    CROSS JOIN data_end
    WHERE orders.order_status = 'delivered'
    GROUP BY customers.customer_unique_id, data_end.latest_order_date
),

frequency AS (
    -- Delivered orders per customer. Canceled and shipped orders are
    -- excluded: they are not completed engagement.
    SELECT
        customers.customer_unique_id,
        COUNT(*) AS order_count
    FROM orders
    JOIN customers
        ON orders.customer_id = customers.customer_id
    WHERE orders.order_status = 'delivered'
    GROUP BY customers.customer_unique_id
),

monetary AS (
    -- Total amount paid across delivered orders.
    SELECT
        customers.customer_unique_id,
        SUM(payments.payment_value) AS total_spent
    FROM orders
    JOIN customers
        ON orders.customer_id = customers.customer_id
    JOIN payments
        ON orders.order_id = payments.order_id
    WHERE orders.order_status = 'delivered'
    GROUP BY customers.customer_unique_id
),

rfm_base AS (
    -- One row per customer with at least one delivered order.
    SELECT
        recency.customer_unique_id,
        recency.recency_days,
        frequency.order_count,
        monetary.total_spent
    FROM recency
    JOIN frequency
        ON recency.customer_unique_id = frequency.customer_unique_id
    JOIN monetary
        ON recency.customer_unique_id = monetary.customer_unique_id
),

rfm_scores AS (
    -- Score each dimension 1 (worst) to 5 (best).
    -- Recency is sorted DESC: fewer days since the last order = higher score.
    SELECT
        customer_unique_id,
        recency_days,
        order_count,
        total_spent,
        NTILE(5) OVER (ORDER BY recency_days DESC, customer_unique_id) AS recency_score,
        CASE WHEN order_count >= 3 THEN 5
             WHEN order_count  = 2 THEN 3
             ELSE 1 END                                                AS frequency_score,
        NTILE(5) OVER (ORDER BY total_spent ASC, customer_unique_id)   AS monetary_score
    FROM rfm_base
),

rfm_buckets AS (
    -- Average F and M into one "value" signal, then bucket both
    -- recency and F&M into High / Mid / Low for the segment grid.
    SELECT
        customer_unique_id,
        recency_score,
        frequency_score,
        monetary_score,
        CASE WHEN recency_score >= 4 THEN 'High'
             WHEN recency_score = 3  THEN 'Mid'
             ELSE 'Low' END AS recency_bucket,
        CASE WHEN (frequency_score + monetary_score) / 2.0 >= 4 THEN 'High'
             WHEN (frequency_score + monetary_score) / 2.0 >= 3 THEN 'Mid'
             ELSE 'Low' END AS fm_bucket
    FROM rfm_scores
),

rfm_segments AS (
    -- Map (recency_bucket, fm_bucket) to the classic 9-segment RFM grid.
    SELECT
        customer_unique_id,
        recency_score,
        frequency_score,
        monetary_score,
        recency_bucket,
        fm_bucket,
        CASE
            WHEN recency_bucket = 'High' AND fm_bucket = 'High' THEN 'Champions'
            WHEN recency_bucket = 'Mid'  AND fm_bucket = 'High' THEN 'Loyal Customers'
            WHEN recency_bucket = 'Low'  AND fm_bucket = 'High' THEN 'At Risk'
            WHEN recency_bucket = 'High' AND fm_bucket = 'Mid'  THEN 'Potential Loyalists'
            WHEN recency_bucket = 'Mid'  AND fm_bucket = 'Mid'  THEN 'Need Attention'
            WHEN recency_bucket = 'Low'  AND fm_bucket = 'Mid'  THEN 'About to Sleep'
            WHEN recency_bucket = 'High' AND fm_bucket = 'Low'  THEN 'New Customers'
            WHEN recency_bucket = 'Mid'  AND fm_bucket = 'Low'  THEN 'Promising'
            WHEN recency_bucket = 'Low'  AND fm_bucket = 'Low'  THEN 'Lost'
        END AS rfm_segment
    FROM rfm_buckets
)

SELECT * FROM rfm_segments;
GO

-- SELECT * FROM dbo.vw_CustomerRFM;
