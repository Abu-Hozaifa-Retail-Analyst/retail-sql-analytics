/* ============================================================
   Project: Churn Risk Detection
   Business Question: Which currently-active customers show a
   purchase gap that's meaningfully longer than their own
   historical pattern -- an early warning sign of churn?

   Dialect: SQL Server (T-SQL)
   ============================================================ */

WITH order_gaps AS (
    -- For every delivered order, look back at that same customer's
    -- previous order date using LAG (no self-join needed).
    SELECT
        c.customer_unique_id,
        o.order_purchase_timestamp AS order_date,
        LAG(o.order_purchase_timestamp) OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp
        ) AS previous_order_date
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE order_status = 'delivered'
),

gap_days AS (
    -- Convert consecutive order dates into a day-gap. A customer's
    -- first order has no previous_order_date, so it's excluded --
    -- there's no gap to measure yet.
    SELECT
        customer_unique_id,
        order_date,
        previous_order_date,
        DATEDIFF(DAY, previous_order_date, order_date) AS days_since_previous_order
    FROM order_gaps
    WHERE previous_order_date IS NOT NULL
),

customer_avg_gap AS (
    -- Each customer's average historical gap between orders.
    -- Only customers with 2+ orders appear here, which is correct --
    -- "overdue relative to your own pattern" is meaningless for a
    -- one-time buyer with no pattern.
    SELECT
        customer_unique_id,
        AVG(days_since_previous_order * 1.0) AS avg_gap_days
    FROM gap_days
    GROUP BY customer_unique_id
),

last_order AS (
    -- Each customer's most recent order date.
    SELECT
        c.customer_unique_id,
        MAX(o.order_purchase_timestamp) AS last_order_date
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

churn_risk AS (
    -- Combine last order date + average gap, measure how many days
    -- have passed since their last order (against the dataset's own
    -- max date, treated as "today").
    SELECT
        lo.customer_unique_id,
        lo.last_order_date,
        cag.avg_gap_days,
        DATEDIFF(DAY, lo.last_order_date,
            (SELECT MAX(order_purchase_timestamp) FROM orders)) AS days_since_last_order
    FROM last_order lo
    JOIN customer_avg_gap cag ON lo.customer_unique_id = cag.customer_unique_id
)

-- Flag customers currently overdue by 2x+ their own normal gap --
-- the overdue_ratio is what makes this fair across customers with
-- very different natural buying rhythms.
SELECT
    customer_unique_id,
    last_order_date,
    ROUND(avg_gap_days, 1) AS avg_gap_days,
    days_since_last_order,
    ROUND(days_since_last_order / avg_gap_days, 1) AS overdue_ratio
FROM churn_risk
WHERE days_since_last_order > avg_gap_days * 2
ORDER BY overdue_ratio DESC;
