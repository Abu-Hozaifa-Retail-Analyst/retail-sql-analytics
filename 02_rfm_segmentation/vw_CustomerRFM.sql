/* ============================================================
   View: vw_CustomerRFM
   Wraps Project 2's RFM segmentation logic as a reusable view,
   so any future query (or BI tool) can treat customer segments
   as a plain table instead of re-pasting the full 6-CTE query.

   Example usage:
     SELECT * FROM dbo.vw_CustomerRFM;

     SELECT rfm_segment, COUNT(*) AS customer_count
     FROM dbo.vw_CustomerRFM
     GROUP BY rfm_segment
     ORDER BY customer_count DESC;

   Dialect: SQL Server (T-SQL)
   ============================================================ */

CREATE OR ALTER VIEW dbo.vw_CustomerRFM AS
WITH recency AS (
    SELECT
        c.customer_unique_id,
        DATEDIFF(DAY, MAX(o.order_purchase_timestamp),
            (SELECT MAX(order_purchase_timestamp) FROM orders)) AS recency_days
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
),

frequency AS (
    SELECT
        c.customer_unique_id,
        COUNT(*) AS order_count
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

monetary AS (
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

/* ------------------------------------------------------------
   Example usage
   ------------------------------------------------------------ */
-- SELECT * FROM dbo.vw_CustomerRFM;
--
-- SELECT rfm_segment, COUNT(*) AS customer_count
-- FROM dbo.vw_CustomerRFM
-- GROUP BY rfm_segment
-- ORDER BY customer_count DESC;
USE RetailAnalytics1;
GO

-- Run this once, to create the snapshot table
CREATE TABLE dbo.CustomerRFMSnapshot (
    customer_unique_id VARCHAR(20) NOT NULL,
    recency_score       INT,
    frequency_score      INT,
    monetary_score        INT,
    recency_bucket         VARCHAR(10),
    fm_bucket                VARCHAR(10),
    rfm_segment                VARCHAR(30)
);

CREATE OR ALTER PROCEDURE dbo.usp_RefreshRFMSnapshot 
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Step 1: clear out the old snapshot
        TRUNCATE TABLE dbo.CustomerRFMSnapshot;

        -- Step 2: reload it from the live view
        INSERT INTO dbo.CustomerRFMSnapshot
        SELECT * FROM dbo.vw_CustomerRFM;

        COMMIT TRANSACTION;

        PRINT 'RFM snapshot refreshed successfully.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50000, @ErrorMessage, 1;
    END CATCH
END

EXEC dbo.usp_RefreshRFMSnapshot

SELECT COUNT(*) FROM dbo.CustomerRFMSnapshot;

SELECT
    COUNT(*)
FROM dbo.CustomerRFMSnapshot