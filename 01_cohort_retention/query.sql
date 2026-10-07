/* ============================================================
   Project: Customer Cohort Retention Analysis
   Business Question: Of customers who made their first purchase
   in a given month, what % are still buying 1, 2, 3+ months later?

   Dialect: SQL Server (T-SQL)

   Naming convention: CTE names say what they hold; base tables are
   referenced by their full names; output column names are unchanged.
   ============================================================ */

WITH customer_first_purchase AS (
    -- Step 1: find each real customer's first purchase month.
    -- NOTE: customer_id is unique per ORDER in this schema;
    -- customer_unique_id identifies the actual person. Grouping
    -- by customer_id instead would make every customer look like
    -- a one-time buyer -- a common trap in Olist-style schemas.
    SELECT
        customers.customer_unique_id,
        MIN(DATEFROMPARTS(
            YEAR(orders.order_purchase_timestamp),
            MONTH(orders.order_purchase_timestamp),
            1
        )) AS cohort_month
    FROM orders
    JOIN customers
        ON orders.customer_id = customers.customer_id
    GROUP BY customers.customer_unique_id
),

customer_order_months AS (
    -- Step 2: for every order a customer ever placed, measure how
    -- many months after their first purchase it happened.
    -- (DATEDIFF(MONTH, ...) counts calendar-month boundaries, not 30-day periods.)
    SELECT
        customer_first_purchase.customer_unique_id,
        customer_first_purchase.cohort_month,
        DATEDIFF(MONTH,
                 customer_first_purchase.cohort_month,
                 orders.order_purchase_timestamp) AS months_since_first_purchase
    FROM customer_first_purchase
    JOIN customers
        ON customers.customer_unique_id = customer_first_purchase.customer_unique_id
    JOIN orders
        ON orders.customer_id = customers.customer_id
),

cohort_active_customers AS (
    -- Step 3: count distinct customers active at each month offset
    -- per cohort. (A month with zero active customers has no row.)
    SELECT
        cohort_month,
        months_since_first_purchase,
        COUNT(DISTINCT customer_unique_id) AS customers_active
    FROM customer_order_months
    GROUP BY cohort_month, months_since_first_purchase
),

cohort_sizes AS (
    -- Step 4: isolate the month-0 count per cohort as the
    -- denominator for retention %.
    SELECT
        cohort_month,
        customers_active AS cohort_size
    FROM cohort_active_customers
    WHERE months_since_first_purchase = 0
)

SELECT
    active.cohort_month,
    active.months_since_first_purchase,
    active.customers_active,
    sizes.cohort_size,
    CAST(100.0 * active.customers_active / sizes.cohort_size AS DECIMAL(5,1)) AS retention_pct
FROM cohort_active_customers AS active
JOIN cohort_sizes AS sizes
    ON active.cohort_month = sizes.cohort_month
ORDER BY active.cohort_month, active.months_since_first_purchase;


/* ------------------------------------------------------------
   Validation checks (run each one and compare with the main query)
   ------------------------------------------------------------ */

-- V1. Cohort sizes must add up to the number of real customers who ordered.
--     Compare with SUM(cohort_size) over the month-0 rows (3,000 in sample_output.csv).
SELECT COUNT(DISTINCT customers.customer_unique_id) AS distinct_customers_who_ordered
FROM orders
JOIN customers
    ON orders.customer_id = customers.customer_id;

-- V2. The data-model trap: customer_id (one per order) vs customer_unique_id (one per person).
--     If customer_ids is larger than unique_customers, grouping by customer_id
--     would split one person into several "customers".
SELECT COUNT(DISTINCT customer_id)        AS customer_ids,
       COUNT(DISTINCT customer_unique_id) AS unique_customers
FROM customers;

-- V3. In the main query's output:
--     month 0 must show retention_pct = 100.0 for every cohort, and
--     customers_active must never exceed cohort_size.
