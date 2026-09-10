/* ============================================================
   Project: RFM Customer Segmentation
   Business Question: Which customers are most valuable and worth
   protecting, and which are showing signs of churn risk?

   Dialect: SQL Server (T-SQL)
   ============================================================ */

WITH recency AS (
    -- Days since each customer's most recent order, measured
    -- against the latest date present in the dataset (treated as
    -- "today" since this is a historical snapshot, not live data).
    SELECT
        c.customer_unique_id,
        DATEDIFF(DAY, MAX(o.order_purchase_timestamp),
            (SELECT MAX(order_purchase_timestamp) FROM orders)) AS recency_days
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
),

frequency AS (
    -- Total delivered orders per customer. Canceled orders are
    -- excluded -- they aren't real engagement.
    SELECT
        c.customer_unique_id,
        COUNT(*) AS order_count
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

monetary AS (
    -- Total amount spent across delivered orders.
    SELECT
        c.customer_unique_id,
        SUM(p.payment_value) AS total_spent
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN payments p ON o.order_id = p.order_id
    WHERE order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

rfm_base AS (
    -- Combine the three metrics per customer.
    SELECT
        r.customer_unique_id,
        r.recency_days,
        f.order_count,
        m.total_spent
    FROM recency r
    JOIN frequency f ON r.customer_unique_id = f.customer_unique_id
    JOIN monetary m ON r.customer_unique_id = m.customer_unique_id
),

rfm_scores AS (
    -- Score each dimension 1-5 using NTILE. Recency is sorted
    -- DESC because a SMALLER recency_days (bought more recently)
    -- should map to a HIGHER score -- the opposite direction of
    -- frequency/monetary, where a bigger raw number is already "better."
    SELECT
        customer_unique_id,
        recency_days,
        order_count,
        total_spent,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS recency_score,
        NTILE(5) OVER (ORDER BY order_count ASC) AS frequency_score,
        NTILE(5) OVER (ORDER BY total_spent ASC) AS monetary_score
    FROM rfm_base
),

rfm_buckets AS (
    -- Average F and M into one "value" signal, then bucket both
    -- R and F&M into High/Mid/Low for the segment grid.
    SELECT
        customer_unique_id,
        recency_score,
        frequency_score,
        monetary_score,
        (frequency_score + monetary_score) / 2.0 AS fm_avg,
        CASE
            WHEN recency_score >= 4 THEN 'High'
            WHEN recency_score = 3 THEN 'Mid'
            ELSE 'Low'
        END AS recency_bucket,
        CASE
            WHEN (frequency_score + monetary_score) / 2.0 >= 4 THEN 'High'
            WHEN (frequency_score + monetary_score) / 2.0 >= 3 THEN 'Mid'
            ELSE 'Low'
        END AS fm_bucket
    FROM rfm_scores
),

rfm_segments AS (
    -- Map the (recency_bucket, fm_bucket) pair to the classic
    -- 9-segment RFM grid.
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

-- Final output: segment-level summary with size, share of base,
-- and average spend -- this is the table that drives the business finding.
SELECT
    rfm_segment,
    COUNT(*) AS customer_count,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,1)) AS pct_of_customers,
    CAST(AVG(total_spent) AS DECIMAL(10,2)) AS avg_spent
FROM rfm_segments r
JOIN rfm_base b ON r.customer_unique_id = b.customer_unique_id
GROUP BY rfm_segment
ORDER BY customer_count DESC;
