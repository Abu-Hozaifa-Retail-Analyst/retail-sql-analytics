/* ============================================================
   Procedure: usp_DataQualityCheck
   Generalizes the manual NULL/duplicate checks from Project 2
   into a reusable procedure that can be re-run any time source
   data refreshes, instead of writing one-off queries each time.

   Checks performed:
     1. NULLs in key business columns
     2. Duplicate customers in the RFM view (should never happen,
        since it's grouped by customer_unique_id at every stage)
     3. Orphaned order_items (line items with no matching order)

   Dialect: SQL Server (T-SQL)
   ============================================================ */

CREATE OR ALTER PROCEDURE dbo.usp_DataQualityCheck
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IssuesFound INT = 0;

    -- ------------------------------------------------------------
    -- Check 1: NULLs in vw_CustomerRFM's key columns
    -- ------------------------------------------------------------
    SELECT
        'NULL check: vw_CustomerRFM' AS check_name,
        SUM(CASE WHEN recency_score  IS NULL THEN 1 ELSE 0 END) AS null_recency_score,
        SUM(CASE WHEN frequency_score IS NULL THEN 1 ELSE 0 END) AS null_frequency_score,
        SUM(CASE WHEN monetary_score  IS NULL THEN 1 ELSE 0 END) AS null_monetary_score,
        SUM(CASE WHEN rfm_segment      IS NULL THEN 1 ELSE 0 END) AS null_rfm_segment
    FROM dbo.vw_CustomerRFM;

    -- ------------------------------------------------------------
    -- Check 2: duplicate customers in vw_CustomerRFM
    -- ------------------------------------------------------------
    SELECT
        'Duplicate check: vw_CustomerRFM' AS check_name,
        customer_unique_id,
        COUNT(*) AS row_count
    INTO #dup_check
    FROM dbo.vw_CustomerRFM
    GROUP BY customer_unique_id
    HAVING COUNT(*) > 1;

    SELECT * FROM #dup_check;
    SET @IssuesFound = @IssuesFound + (SELECT COUNT(*) FROM #dup_check);
    DROP TABLE #dup_check;

    -- ------------------------------------------------------------
    -- Check 3: orphaned order_items (a line item referencing an
    -- order_id that doesn't actually exist in orders -- would
    -- indicate a broken load/import, not normal business data)
    -- ------------------------------------------------------------
    SELECT
        'Orphan check: order_items -> orders' AS check_name,
        oi.order_id,
        oi.product_id
    INTO #orphan_check
    FROM order_items oi
    LEFT JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_id IS NULL;

    SELECT * FROM #orphan_check;
    SET @IssuesFound = @IssuesFound + (SELECT COUNT(*) FROM #orphan_check);
    DROP TABLE #orphan_check;

    -- ------------------------------------------------------------
    -- Summary
    -- ------------------------------------------------------------
    IF @IssuesFound = 0
        PRINT 'Data quality check passed: no issues found.';
    ELSE
        PRINT CONCAT('Data quality check found ', @IssuesFound, ' issue(s). See result sets above.');
END
GO

-- Example usage:
-- EXEC dbo.usp_DataQualityCheck;
