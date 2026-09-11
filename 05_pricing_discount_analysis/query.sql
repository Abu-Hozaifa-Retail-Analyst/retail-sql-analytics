/* ============================================================
   Project: Pricing & Discount Analysis
   Business Question: Do lower-priced / more-discounted products
   sell in higher volume, and where does typical selling price sit
   relative to list price, by category?

   Dialect: SQL Server (T-SQL)
   ============================================================ */

WITH item_discounts AS (
    -- Compare actual sold price against list price (base_price) per
    -- line item. Positive discount_pct = sold below list;
    -- negative = sold above list.
    SELECT
        oi.order_id,
        oi.product_id,
        p.product_category_name,
        p.base_price,
        oi.price AS sold_price,
        (p.base_price - oi.price) / p.base_price * 100 AS discount_pct
    FROM order_items oi
    JOIN products p ON oi.product_id = p.product_id
),

category_discount_stats AS (
    -- Median (not average) discount per category, using
    -- PERCENTILE_CONT so a handful of outlier sales don't skew the
    -- "typical" figure the way AVG() would.
    SELECT DISTINCT
        product_category_name,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY discount_pct)
            OVER (PARTITION BY product_category_name) AS median_discount_pct
    FROM item_discounts
),

category_volume AS (
    -- Sales volume per category, to check whether discount depth
    -- correlates with how much sells.
    SELECT
        product_category_name,
        COUNT(*) AS items_sold
    FROM item_discounts
    GROUP BY product_category_name
)

SELECT
    cds.product_category_name,
    ROUND(cds.median_discount_pct, 1) AS median_discount_pct,
    cv.items_sold
FROM category_discount_stats cds
JOIN category_volume cv ON cds.product_category_name = cv.product_category_name
ORDER BY cv.items_sold DESC;
