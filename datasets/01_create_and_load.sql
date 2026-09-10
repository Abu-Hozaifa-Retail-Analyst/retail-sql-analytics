/* ============================================================
   Retail Analytics Practice DB — Schema + Load Script
   SQL Server (T-SQL)

   1. Creates a database + 5 tables mirroring the Olist schema
   2. Loads data from the CSVs using BULK INSERT

   BEFORE RUNNING:
   - Update the file paths below to wherever you saved the CSVs
     on the machine/server SQL Server is running on.
   - SQL Server's BULK INSERT reads files from the SERVER's
     filesystem, not your local machine. If you're on SQL Server
     Express/Developer running locally, that's the same machine —
     just point to the local folder. If your SQL Server is remote
     (e.g. Docker container, Azure), copy the CSVs into that
     environment first (see notes at bottom).
   ============================================================ */

IF DB_ID('RetailAnalytics') IS NULL
BEGIN
    CREATE DATABASE RetailAnalytics;
END
GO

USE RetailAnalytics;
GO

-- Drop tables if re-running
IF OBJECT_ID('dbo.order_items', 'U') IS NOT NULL DROP TABLE dbo.order_items;
IF OBJECT_ID('dbo.payments', 'U') IS NOT NULL DROP TABLE dbo.payments;
IF OBJECT_ID('dbo.orders', 'U') IS NOT NULL DROP TABLE dbo.orders;
IF OBJECT_ID('dbo.customers', 'U') IS NOT NULL DROP TABLE dbo.customers;
IF OBJECT_ID('dbo.products', 'U') IS NOT NULL DROP TABLE dbo.products;
GO

CREATE TABLE dbo.customers (
    customer_id         VARCHAR(20) NOT NULL PRIMARY KEY,  -- per-order customer id (Olist quirk)
    customer_unique_id  VARCHAR(20) NOT NULL,               -- the actual person
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
    freight_value    DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE dbo.payments (
    order_id                VARCHAR(20) NOT NULL,
    payment_type            VARCHAR(20) NOT NULL,
    payment_installments     INT NOT NULL,
    payment_value            DECIMAL(10,2) NOT NULL
);
GO

/* ------------------------------------------------------------
   LOAD DATA
   Update these paths to match where the CSVs live relative to
   the SQL Server instance.
   ------------------------------------------------------------ */

BULK INSERT dbo.customers
FROM 'C:\retail_data\customers.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, TABLOCK);

BULK INSERT dbo.products
FROM 'C:\retail_data\products.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, TABLOCK);

BULK INSERT dbo.orders
FROM 'C:\retail_data\orders.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, TABLOCK);

BULK INSERT dbo.order_items
FROM 'C:\retail_data\order_items.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, TABLOCK);

BULK INSERT dbo.payments
FROM 'C:\retail_data\payments.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, TABLOCK);
GO

-- Sanity check
SELECT 'customers' AS tbl, COUNT(*) AS row_count FROM dbo.customers
UNION ALL SELECT 'products', COUNT(*) FROM dbo.products
UNION ALL SELECT 'orders', COUNT(*) FROM dbo.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM dbo.order_items
UNION ALL SELECT 'payments', COUNT(*) FROM dbo.payments;
GO

/* ------------------------------------------------------------
   ALTERNATIVE: if you're using SSMS's "Import Flat File" wizard
   instead of BULK INSERT — right-click the database > Tasks >
   Import Flat File — you can skip this script's BULK INSERT
   section entirely and just use the CREATE TABLE statements
   above (or let the wizard infer types, then adjust).

   NOTE ON DOCKER: if running SQL Server in a Docker container,
   copy the CSVs in first:
     docker cp customers.csv <container_id>:/var/opt/mssql/data/
   then reference '/var/opt/mssql/data/customers.csv' in BULK INSERT.
   ------------------------------------------------------------ */
