/* ============================================================
   Project: Market Basket Analysis
   Business Question: Which products are commonly bought together,
   so we can improve cross-sell recommendations and merchandising?

   Dialect: SQL Server (T-SQL)
   ============================================================ */

WITH product_pairs AS (
    -- Self-join order_items to itself, matching rows from the same
    -- basket (order_id) but different products. The a.product_id <
    -- b.product_id condition does double duty: it excludes a
    -- product pairing with itself, and it ensures each real-world
    -- pair is counted once (not once as A-B and again as B-A).
    SELECT
        a.product_id AS product_a,
        b.product_id AS product_b,
        COUNT(*) AS how_often
    FROM order_items a
    JOIN order_items b
        ON a.order_id = b.order_id
        AND a.product_id < b.product_id
    GROUP BY a.product_id, b.product_id
)

-- Join products twice (once per side of the pair) to bring in
-- readable category names, then surface the most frequent pairs.
SELECT TOP 20
    pp.product_a,
    pa.product_category_name AS category_a,
    pp.product_b,
    pb.product_category_name AS category_b,
    pp.how_often
FROM product_pairs pp
JOIN products pa ON pp.product_a = pa.product_id
JOIN products pb ON pp.product_b = pb.product_id
ORDER BY pp.how_often DESC;
