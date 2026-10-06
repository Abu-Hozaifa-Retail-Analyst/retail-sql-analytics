/* ============================================================
   Retail Analytics Practice DB — Schema + Load Script
   SQL Server (T-SQL)

   1. Creates the RetailAnalytics database
   2. Creates 5 tables matching the CSV files
   3. Loads the CSVs using BULK INSERT
   4. Adds foreign-key constraints to validate relationships
   5. Runs row-count sanity checks

   BEFORE RUNNING:
   - SQL Server 2017+ is required because FORMAT = 'CSV' is used.
   - Update ONLY @DataPath below to the local/server folder that
     contains the five CSV files from this repository.
   - BULK INSERT reads files from the SQL Server machine/server,
     not from the SSMS client machine. For a remote SQL Server,
     place the CSVs on a readable server/network path first.
   - The SQL Server service/login must have permission to read the
     source folder, and the executing principal needs bulk-import
     permission.

   Expected source folder contents:
     customers.csv
     products.csv
     orders.csv
     order_items.csv
     payments.csv
   ============================================================ */

IF DB_ID(N'RetailAnalytics') IS NULL
BEGIN
    CREATE DATABASE RetailAnalytics;
END
GO

USE RetailAnalytics;
GO

/* ------------------------------------------------------------
   Re-runnable setup
   ------------------------------------------------------------ */

IF OBJECT_ID('dbo.order_items', 'U') IS NOT NULL DROP TABLE dbo.order_items;
IF OBJECT_ID('dbo.payments', 'U') IS NOT NULL DROP TABLE dbo.payments;
IF OBJECT_ID('dbo.orders', 'U') IS NOT NULL DROP TABLE dbo.orders;
IF OBJECT_ID('dbo.customers', 'U') IS NOT NULL DROP TABLE dbo.customers;
IF OBJECT_ID('dbo.products', 'U') IS NOT NULL DROP TABLE dbo.products;
GO

CREATE TABLE dbo.customers (
    customer_id         VARCHAR(20) NOT NULL PRIMARY KEY,  -- per-order customer id
    customer_unique_id  VARCHAR(20) NOT NULL,              -- actual person
    customer_state      VARCHAR(5)  NOT NULL
);

CREATE TABLE dbo.products (
    product_id             VARCHAR(20) NOT NULL PRIMARY KEY,
    product_category_name  VARCHAR(50) NOT NULL,
    base_price              DECIMAL(10,2) NOT NULL,
    weight_g                INT NOT NULL
);

CREATE TABLE dbo.orders (
    order_id                    VARCHAR(20) NOT NULL PRIMARY KEY,
    customer_id                 VARCHAR(20) NOT NULL,
    order_purchase_timestamp    DATETIME NOT NULL,
    order_status                VARCHAR(20) NOT NULL
);

CREATE TABLE dbo.order_items (
    order_id        VARCHAR(20) NOT NULL,
    order_item_id   INT NOT NULL,
    product_id      VARCHAR(20) NOT NULL,
    price            DECIMAL(10,2) NOT NULL,
    freight_value   DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE dbo.payments (
    order_id                 VARCHAR(20) NOT NULL,
    payment_type             VARCHAR(20) NOT NULL,
    payment_installments    INT NOT NULL,
    payment_value            DECIMAL(10,2) NOT NULL
);
GO

/* ------------------------------------------------------------
   LOAD DATA

   Change only this line.
   Example:
     N'D:\GitHub\retail-sql-analytics\datasets'
   ------------------------------------------------------------ */

DECLARE @DataPath NVARCHAR(4000) =
    N'C:\path\to\retail-sql-analytics\datasets';

IF @DataPath = N'C:\path\to\retail-sql-analytics\datasets'
BEGIN
    THROW 50001, 'Update @DataPath before running the BULK INSERT section.', 1;
END;

/* BULK INSERT requires a server-accessible path. Dynamic SQL is
   used so the five file paths can be controlled from one variable. */

DECLARE @BulkSQL NVARCHAR(MAX);

SET @BulkSQL = N'
BULK INSERT dbo.customers
FROM ''' + REPLACE(@DataPath + N'\customers.csv', '''', '''''') + N'''
WITH (FORMAT = ''CSV'', FIRSTROW = 2, TABLOCK);';
EXEC sys.sp_executesql @BulkSQL;

SET @BulkSQL = N'
BULK INSERT dbo.products
FROM ''' + REPLACE(@DataPath + N'\products.csv', '''', '''''') + N'''
WITH (FORMAT = ''CSV'', FIRSTROW = 2, TABLOCK);';
EXEC sys.sp_executesql @BulkSQL;

SET @BulkSQL = N'
BULK INSERT dbo.orders
FROM ''' + REPLACE(@DataPath + N'\orders.csv', '''', '''''') + N'''
WITH (FORMAT = ''CSV'', FIRSTROW = 2, TABLOCK);';
EXEC sys.sp_executesql @BulkSQL;

SET @BulkSQL = N'
BULK INSERT dbo.order_items
FROM ''' + REPLACE(@DataPath + N'\order_items.csv', '''', '''''') + N'''
WITH (FORMAT = ''CSV'', FIRSTROW = 2, TABLOCK);';
EXEC sys.sp_executesql @BulkSQL;

SET @BulkSQL = N'
BULK INSERT dbo.payments
FROM ''' + REPLACE(@DataPath + N'\payments.csv', '''', '''''') + N'''
WITH (FORMAT = ''CSV'', FIRSTROW = 2, TABLOCK);';
EXEC sys.sp_executesql @BulkSQL;
GO

/* ------------------------------------------------------------
   REFERENTIAL INTEGRITY

   These constraints validate the loaded relationships:
     orders.customer_id        -> customers.customer_id
     order_items.order_id      -> orders.order_id
     order_items.product_id    -> products.product_id
     payments.order_id         -> orders.order_id

   New foreign keys validate existing rows when created, so an
   orphaned record will stop the setup instead of being silently
   accepted.
   ------------------------------------------------------------ */

ALTER TABLE dbo.orders
ADD CONSTRAINT FK_Orders_Customers
    FOREIGN KEY (customer_id)
    REFERENCES dbo.customers(customer_id);

ALTER TABLE dbo.order_items
ADD CONSTRAINT FK_OrderItems_Orders
    FOREIGN KEY (order_id)
    REFERENCES dbo.orders(order_id);

ALTER TABLE dbo.order_items
ADD CONSTRAINT FK_OrderItems_Products
    FOREIGN KEY (product_id)
    REFERENCES dbo.products(product_id);

ALTER TABLE dbo.payments
ADD CONSTRAINT FK_Payments_Orders
    FOREIGN KEY (order_id)
    REFERENCES dbo.orders(order_id);
GO

/* ------------------------------------------------------------
   SANITY CHECK
   Expected counts are based on the CSV files committed to this
   repository. If the source files are changed, update these
   expected values deliberately.
   ------------------------------------------------------------ */

SELECT
    'customers' AS table_name,
    COUNT(*) AS actual_rows,
    4421 AS expected_rows,
    CASE WHEN COUNT(*) = 4421 THEN 'PASS' ELSE 'FAIL' END AS status
FROM dbo.customers

UNION ALL

SELECT
    'products',
    COUNT(*),
    239,
    CASE WHEN COUNT(*) = 239 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.products

UNION ALL

SELECT
    'orders',
    COUNT(*),
    4421,
    CASE WHEN COUNT(*) = 4421 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.orders

UNION ALL

SELECT
    'order_items',
    COUNT(*),
    7624,
    CASE WHEN COUNT(*) = 7624 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.order_items

UNION ALL

SELECT
    'payments',
    COUNT(*),
    4421,
    CASE WHEN COUNT(*) = 4421 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.payments;
GO

/* ------------------------------------------------------------
   OPTIONAL: SQL Server 2017+ CSV support

   FORMAT = 'CSV' is supported from SQL Server 2017 (14.x).
   For older SQL Server versions, use an alternative import
   method or upgrade the instance.
   ------------------------------------------------------------ */

/* ------------------------------------------------------------
   ALTERNATIVE: SSMS "Import Flat File" wizard

   If BULK INSERT is unavailable in your environment, you can
   right-click the RetailAnalytics database in SSMS and use:
       Tasks > Import Flat File

   The wizard can load the CSVs, but review inferred data types
   before accepting the generated table definitions.

   NOTE ON DOCKER / REMOTE SQL SERVER:
   The source files must be accessible from the SQL Server
   environment. A local Windows path on your laptop will not work
   if the Database Engine is running inside another machine or
   container. Use a server-accessible local path or UNC path.
   ------------------------------------------------------------ */
