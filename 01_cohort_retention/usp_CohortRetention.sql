/* ============================================================
   Stored Procedure: usp_CohortRetention
   Wraps Project 1 (Cohort Retention Analysis) as a reusable,
   parameterized procedure instead of a one-off script.

   Parameters:
     @start_date  (optional) - only include cohorts starting on/after this date
     @end_date    (optional) - only include cohorts starting on/before this date
     Pass NULL (or omit) either parameter to leave that side unfiltered.

   Example usage:
     EXEC dbo.usp_CohortRetention;                                    -- all cohorts
     EXEC dbo.usp_CohortRetention @start_date = '2023-06-01';         -- from June 2023 onward
     EXEC dbo.usp_CohortRetention @start_date = '2023-01-01',
                                   @end_date   = '2023-06-30';        -- H1 2023 cohorts only

   Dialect: SQL Server (T-SQL)

   Naming convention: same as query.sql (descriptive CTE names, full table names).
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.usp_CohortRetention
    @start_date DATE = NULL,
    @end_date   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

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
    WHERE (@start_date IS NULL OR active.cohort_month >= @start_date)
      AND (@end_date   IS NULL OR active.cohort_month <= @end_date)
    ORDER BY active.cohort_month, active.months_since_first_purchase;
END
GO

/* ------------------------------------------------------------
   Example calls
   ------------------------------------------------------------ */
-- EXEC dbo.usp_CohortRetention;
-- EXEC dbo.usp_CohortRetention @start_date = '2023-06-01';
-- EXEC dbo.usp_CohortRetention @start_date = '2023-01-01', @end_date = '2023-06-30';
