/* ============================================================
   Performance: Recommended Indexes
   Indexes derived from the actual JOIN, WHERE, and ordering
   patterns used across the nine analytical projects in this repo.

   Dialect: SQL Server (T-SQL)

   IMPORTANT:
   These are recommended index definitions based on query structure.
   They are not presented as benchmarked performance improvements.
   Actual benefit depends on data volume, distribution, existing
   indexes, statistics, execution plans, and workload.
   ============================================================ */

-- 1. order_items (order_id, product_id)
-- Used by Project 3 (Market Basket Analysis):
--   FROM order_items a
--   JOIN order_items b
--       ON a.order_id = b.order_id
--       AND a.product_id < b.product_id
--
-- order_id is first for the equality condition; product_id follows
-- for the within-order comparison.
CREATE NONCLUSTERED INDEX IX_OrderItems_OrderID_ProductID
ON order_items (order_id, product_id);

-- 2. orders (customer_id)
-- Used by customer-based analytical queries that join:
--   JOIN customers c ON o.customer_id = c.customer_id
--
-- customers.customer_id is already indexed by its primary key.
-- This index supports the orders side of the relationship.
CREATE NONCLUSTERED INDEX IX_Orders_CustomerID
ON orders (customer_id);

-- 3. delivered orders: (customer_id, order_purchase_timestamp)
--    FILTERED INDEX
-- Used by delivered-order analysis, including Project 4
-- (Churn Detection), which joins by customer_id, filters delivered
-- orders, and works with purchase timestamps.
--
-- The filtered index contains only delivered rows and supports the
-- recurring customer join/filter/date-access pattern.
CREATE NONCLUSTERED INDEX IX_Orders_Delivered_CustomerID_PurchaseTimestamp
ON orders (customer_id, order_purchase_timestamp)
WHERE order_status = 'delivered';

-- Window-function clarification
-- Project 4 partitions by customers.customer_unique_id:
--
--   LAG(o.order_purchase_timestamp) OVER (
--       PARTITION BY c.customer_unique_id
--       ORDER BY o.order_purchase_timestamp
--   )
--
-- customer_unique_id is in customers, while customer_id and
-- order_purchase_timestamp are in orders. Therefore this index
-- supports the join/filter/date-access pattern, but does NOT
-- guarantee that SQL Server can avoid a sort for the window function.
--
-- Validate actual benefit with an execution plan and representative
-- data volume before treating this as a production optimization.
