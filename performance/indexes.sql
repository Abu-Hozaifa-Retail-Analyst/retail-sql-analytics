/* ============================================================
   Performance: Recommended Indexes
   Indexes derived from analyzing actual JOIN and WHERE patterns
   used across all six projects in this repo, not applied
   speculatively.

   Dialect: SQL Server (T-SQL)
   ============================================================ */

-- --------------------------------------------------------------
-- 1. order_items (order_id, product_id)
-- --------------------------------------------------------------
-- Used by: Project 3 (Market Basket Analysis), whose self-join
-- matches every pair of products within the same order:
--   FROM order_items a
--   JOIN order_items b
--       ON a.order_id = b.order_id
--       AND a.product_id < b.product_id
-- order_id is listed first because it's an equality match -- it
-- lets SQL Server narrow down to one order's rows immediately.
-- product_id is listed second to efficiently support the range
-- comparison (<) within that already-narrowed group.
CREATE NONCLUSTERED INDEX IX_OrderItems_OrderID_ProductID
ON order_items (order_id, product_id);

-- --------------------------------------------------------------
-- 2. orders (customer_id)
-- --------------------------------------------------------------
-- Used by: nearly every project (1, 2, 3, 4, 5, 6), all of which
-- join orders to customers:
--   JOIN customers c ON o.customer_id = c.customer_id
-- customers.customer_id is already covered by its PRIMARY KEY
-- (which auto-creates a clustered index), but orders.customer_id
-- has no automatic index -- every one of these joins was
-- table-scanning the orders table to find matches until this
-- index exists.
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID
ON orders (customer_id);

-- --------------------------------------------------------------
-- 3. orders (order_id) WHERE order_status = 'delivered'  [FILTERED]
-- --------------------------------------------------------------
-- Used by: Projects 2, 3, 4, 6, all of which filter:
--   WHERE order_status = 'delivered'
-- order_status is NOT a good candidate for a plain index -- it's
-- low-selectivity (only 3 distinct values, and ~94% of rows are
-- 'delivered'), so a normal index would still point to nearly the
-- whole table, and SQL Server's optimizer would likely ignore it
-- in favor of a full scan anyway.
-- A FILTERED index solves this: it only indexes the specific
-- slice of rows queries actually ask for, making it small and
-- genuinely useful instead of redundant with the base table.
CREATE NONCLUSTERED INDEX IX_Orders_Delivered
ON orders (order_id)
WHERE order_status = 'delivered';

-- --------------------------------------------------------------
-- 4. orders (customer_id, order_purchase_timestamp)
-- --------------------------------------------------------------
-- Used by: Project 4 (Churn Detection), whose LAG() window function
-- requires rows grouped by customer and ordered by purchase date:
--   LAG(o.order_purchase_timestamp) OVER (
--       PARTITION BY c.customer_unique_id
--       ORDER BY o.order_purchase_timestamp
--   )
-- Without this index, SQL Server must perform an expensive sort
-- operation every time this query runs, just to satisfy the
-- PARTITION BY / ORDER BY combination. customer_id is listed first
-- (the PARTITION BY / grouping role), order_purchase_timestamp
-- second (the ORDER BY / sorting-within-group role) -- with data
-- already physically stored in this order, SQL Server can
-- potentially skip the sort step entirely.
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID_PurchaseTimestamp
ON orders (customer_id, order_purchase_timestamp);
