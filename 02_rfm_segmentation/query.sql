/* ============================================================
   Project: RFM Customer Segmentation
   Business Question: Which customers are most valuable and worth
   protecting, and which are showing signs of churn risk?

   Dialect: SQL Server (T-SQL)
   Database: RetailAnalytics (synthetic Olist-style data)

   Design decisions (see README, "Method"):
   - Recency, frequency and monetary all use DELIVERED orders only.
   - Frequency is scored with FIXED RULES, not NTILE: about 80% of
     customers have exactly 1 order, and NTILE gives identical
     customers different scores (the result then depends on arbitrary
     row order). See validation check V5.
   - Recency and monetary use NTILE(5); customer_unique_id breaks ties
     so the result is repeatable.
   ============================================================ */
USE RetailAnalytics;
GO

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

-- Final output: segment-level summary (the first four columns are unchanged
-- from the earlier version of this project).
SELECT
    rfm_segments.rfm_segment,
    COUNT(*) AS customer_count,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1)) AS pct_of_customers,
    CAST(AVG(rfm_base.total_spent) AS DECIMAL(10,2)) AS avg_spent,
    CAST(SUM(rfm_base.total_spent) AS DECIMAL(12,2)) AS total_spent,
    CAST(100.0 * SUM(rfm_base.total_spent) / SUM(SUM(rfm_base.total_spent)) OVER () AS DECIMAL(5,1)) AS pct_of_revenue,
    CAST(AVG(rfm_base.order_count * 1.0) AS DECIMAL(5,2)) AS avg_orders,
    CAST(AVG(rfm_base.recency_days * 1.0) AS DECIMAL(6,0)) AS avg_recency_days
FROM rfm_segments
JOIN rfm_base
    ON rfm_segments.customer_unique_id = rfm_base.customer_unique_id
GROUP BY rfm_segments.rfm_segment
ORDER BY customer_count DESC;


/* ------------------------------------------------------------
   Validation checks (run each one and compare with the main query)
   ------------------------------------------------------------ */

-- V1. Segment customers must equal the customers with at least one delivered order.
--     Compare with SUM(customer_count) in the main output (2,845).
SELECT COUNT(DISTINCT customers.customer_unique_id) AS customers_with_a_delivered_order
FROM orders
JOIN customers
    ON orders.customer_id = customers.customer_id
WHERE orders.order_status = 'delivered';

-- V2. Segment revenue must equal total payments of delivered orders.
--     Compare with SUM(total_spent) in the main output (2,098,009.12).
SELECT SUM(payments.payment_value) AS total_delivered_payments
FROM payments
JOIN orders
    ON orders.order_id = payments.order_id
WHERE orders.order_status = 'delivered';

-- V3. In the main output: pct_of_customers and pct_of_revenue must each
--     add up to 100 (+/- rounding).

-- V4. The data-model trap: customer_id is per ORDER, customer_unique_id is the
--     person. customer_ids should be larger (4,421 vs 3,000).
SELECT COUNT(DISTINCT customer_id)        AS customer_ids,
       COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;

-- V5. Why frequency uses fixed rules: with NTILE, customers who all have
--     order_count = 1 are spread over several different scores.
WITH order_counts AS (
    SELECT customers.customer_unique_id, COUNT(*) AS order_count
    FROM orders
    JOIN customers
        ON orders.customer_id = customers.customer_id
    WHERE orders.order_status = 'delivered'
    GROUP BY customers.customer_unique_id
),
ntile_frequency AS (
    SELECT order_count, NTILE(5) OVER (ORDER BY order_count) AS ntile_score
    FROM order_counts
)
SELECT order_count, ntile_score, COUNT(*) AS customers
FROM ntile_frequency
WHERE order_count = 1
GROUP BY order_count, ntile_score
ORDER BY ntile_score;
