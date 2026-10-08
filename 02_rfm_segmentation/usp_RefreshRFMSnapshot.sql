/* ============================================================
   Snapshot table + refresh procedure for the RFM segments.
   Requires dbo.vw_CustomerRFM (see vw_CustomerRFM.sql) in the SAME database.

   Run this file once to create the table and the procedure, then
   EXEC dbo.usp_RefreshRFMSnapshot whenever the data changes.

   Dialect: SQL Server (T-SQL)
   ============================================================ */
USE RetailAnalytics;
GO

IF OBJECT_ID('dbo.CustomerRFMSnapshot', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CustomerRFMSnapshot (
        customer_unique_id  VARCHAR(20) NOT NULL PRIMARY KEY,
        recency_score       INT,
        frequency_score     INT,
        monetary_score      INT,
        recency_bucket      VARCHAR(10),
        fm_bucket           VARCHAR(10),
        rfm_segment         VARCHAR(30)
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_RefreshRFMSnapshot
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Step 1: clear the old snapshot
        TRUNCATE TABLE dbo.CustomerRFMSnapshot;

        -- Step 2: reload it from the live view
        INSERT INTO dbo.CustomerRFMSnapshot
            (customer_unique_id, recency_score, frequency_score, monetary_score,
             recency_bucket, fm_bucket, rfm_segment)
        SELECT
             customer_unique_id, recency_score, frequency_score, monetary_score,
             recency_bucket, fm_bucket, rfm_segment
        FROM dbo.vw_CustomerRFM;

        COMMIT TRANSACTION;
        PRINT 'RFM snapshot refreshed successfully.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;   -- re-raise the original error
    END CATCH
END
GO

-- EXEC dbo.usp_RefreshRFMSnapshot;
-- SELECT COUNT(*) AS snapshot_rows FROM dbo.CustomerRFMSnapshot;   -- expect 2,845
