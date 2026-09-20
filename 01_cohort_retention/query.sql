/* ============================================================
   Project: Customer Cohort Retention Analysis
   Business Question: Of customers who made their first purchase
   in a given month, what % are still buying 1, 2, 3+ months later?

   Dialect: SQL Server (T-SQL)
   ============================================================ */

WITH first_purchase AS (
    -- Step 1: find each real customer's first purchase month.
    -- NOTE: customer_id is unique per ORDER in this schema;
    -- customer_unique_id identifies the actual person. Grouping
    -- by customer_id instead would make every customer look like
    -- a one-time buyer -- a common trap in Olist-style schemas.
    SELECT
        c.customer_unique_id,
        MIN(DATEFROMPARTS(
            YEAR(o.order_purchase_timestamp),
            MONTH(o.order_purchase_timestamp),
            1
        )) AS cohort_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
),

step2 AS (
    -- Step 2: for every order a customer ever placed, measure how
    -- many months after their first purchase it happened.
    SELECT
        fp.customer_unique_id,
        fp.cohort_month,
        DATEDIFF(MONTH, fp.cohort_month, o.order_purchase_timestamp) AS months_since_first_purchase
    FROM first_purchase fp
    JOIN customers c ON c.customer_unique_id = fp.customer_unique_id
    JOIN orders o ON o.customer_id = c.customer_id
),

cohort_counts AS (
    -- Step 3: count distinct customers active at each month offset
    -- per cohort.
    SELECT
        cohort_month,
        months_since_first_purchase,
        COUNT(DISTINCT customer_unique_id) AS customers_active
    FROM step2
    GROUP BY cohort_month, months_since_first_purchase
),

cohort_size AS (
    -- Step 4: isolate the month-0 count per cohort as the
    -- denominator for retention %.
    SELECT
        cohort_month,
        customers_active AS cohort_size
    FROM cohort_counts
    WHERE months_since_first_purchase = 0
)

SELECT
    cc.cohort_month,
    cc.months_since_first_purchase,
    cc.customers_active,
    cs.cohort_size,
    CAST(100.0 * cc.customers_active / cs.cohort_size AS DECIMAL(5,1)) AS retention_pct
FROM cohort_counts cc
JOIN cohort_size cs ON cc.cohort_month = cs.cohort_month
ORDER BY cc.cohort_month, cc.months_since_first_purchase;
