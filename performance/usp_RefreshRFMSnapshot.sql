/* ============================================================
   Table + Procedure: CustomerRFMSnapshot / usp_RefreshRFMSnapshot
   Demonstrates a production-style pattern: snapshotting a live
   view into a physical table on a schedule, wrapped in a
   transaction with TRY/CATCH error handling so a failure never
   leaves the table half-loaded or empty.

   Dialect: SQL Server (T-SQL)
   ============================================================ */

-- Run once: creates the physical snapshot table.
CREATE TABLE dbo.CustomerRFMSnapshot (
    customer_unique_id  VARCHAR(20) NOT NULL,
    recency_score       INT,
    frequency_score     INT,
    monetary_score      INT,
    recency_bucket      VARCHAR(10),
    fm_bucket            VARCHAR(10),
    rfm_segment           VARCHAR(30)
);
GO

CREATE OR ALTER PROCEDURE dbo.usp_RefreshRFMSnapshot
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Step 1: clear out the old snapshot. TRUNCATE is faster
        -- than DELETE for a full-table clear, and is still fully
        -- rollback-safe as long as it's inside an explicit
        -- transaction (as it is here).
        TRUNCATE TABLE dbo.CustomerRFMSnapshot;

        -- Step 2: reload it from the live view.
        INSERT INTO dbo.CustomerRFMSnapshot
        SELECT * FROM dbo.vw_CustomerRFM;

        COMMIT TRANSACTION;

        PRINT 'RFM snapshot refreshed successfully.';
    END TRY
    BEGIN CATCH
        -- Undo any partial work (e.g. the TRUNCATE) if something
        -- failed before COMMIT was reached.
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- Re-raise the original error so a caller (a scheduled job,
        -- another script) knows the refresh failed and why, instead
        -- of the failure being silently swallowed.
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        THROW 50000, @ErrorMessage, 1;
    END CATCH
END
GO

/* ------------------------------------------------------------
   Verified failure test (documented, not hypothetical)

   A deliberate runtime error (SELECT 1/0;) was inserted between
   the TRUNCATE and the INSERT to force a genuine runtime failure
   that SQL Server cannot catch at compile time (unlike an invalid
   column reference, which SQL Server rejects immediately when the
   procedure is created, before it can ever run).

   Result:
     - Row count before the forced failure: 2845
     - EXEC dbo.usp_RefreshRFMSnapshot -> Msg 50000: "Divide by
       zero error encountered." (the original SQL Server error,
       re-thrown by our CATCH block)
     - Row count after the forced failure: 2845 (unchanged)

   This confirms TRUNCATE + ROLLBACK behaved correctly together:
   even though TRUNCATE executed before the error was hit, the
   transaction rollback fully undid it, leaving the snapshot table
   exactly as it was -- never empty, never half-loaded.
   ------------------------------------------------------------ */

-- Example usage:
-- EXEC dbo.usp_RefreshRFMSnapshot;
-- SELECT COUNT(*) FROM dbo.CustomerRFMSnapshot;
