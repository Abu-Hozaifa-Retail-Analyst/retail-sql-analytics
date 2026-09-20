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
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.usp_CohortRetention
    @start_date DATE = NULL,
    @end_date   DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    WITH first_purchase AS (
        -- Each real customer's first purchase month.
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
        -- Every order's distance (in months) from that customer's
        -- first purchase.
        SELECT
            fp.customer_unique_id,
            fp.cohort_month,
            DATEDIFF(MONTH, fp.cohort_month, o.order_purchase_timestamp) AS months_since_first_purchase
        FROM first_purchase fp
        JOIN customers c ON c.customer_unique_id = fp.customer_unique_id
        JOIN orders o ON o.customer_id = c.customer_id
    ),

    cohort_counts AS (
        SELECT
            cohort_month,
            months_since_first_purchase,
            COUNT(DISTINCT customer_unique_id) AS customers_active
        FROM step2
        GROUP BY cohort_month, months_since_first_purchase
    ),

    cohort_size AS (
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
    WHERE (@start_date IS NULL OR cc.cohort_month >= @start_date)
      AND (@end_date   IS NULL OR cc.cohort_month <= @end_date)
    ORDER BY cc.cohort_month, cc.months_since_first_purchase;
END
GO

/* ------------------------------------------------------------
   Example calls
   ------------------------------------------------------------ */
-- EXEC dbo.usp_CohortRetention;
-- EXEC dbo.usp_CohortRetention @start_date = '2023-06-01';
-- EXEC dbo.usp_CohortRetention @start_date = '2023-01-01', @end_date = '2023-06-30';
