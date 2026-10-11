/* ============================================================
   Project: Market Basket Analysis
   Business Question: Which products are commonly bought together,
   so we can improve cross-sell recommendations and merchandising?

   Dialect: SQL Server (T-SQL)
   Database: RetailAnalytics (synthetic Olist-style data)

   Design decisions (see README, "Method"):
   - Only DELIVERED orders count as purchases.
   - A basket is an order. Pairs are counted once per ORDER (DISTINCT),
     not once per line item, so a product on two lines is not double counted.
   - Query 1 works at product (SKU) level. With few co-purchases per pair
     it is only indicative, so ties at the cut-off are all returned.
   - Query 2 works at category level and measures support, confidence and
     lift, which show whether a pair is bought together MORE than chance.
   ============================================================ */
USE RetailAnalytics;
GO

/* ------------------------------------------------------------
   Query 1a: Product pairs bought together most often
   TOP 20 WITH TIES returns every pair tied with the 20th one, instead of an
   arbitrary subset. Only 8 pairs reach 4 co-purchases and 62 more tie at 3,
   so ranks 9 and below would otherwise depend on how ties happen to be broken
   (see validation V3). The ORDER BY must contain only how_often for WITH TIES.
   ------------------------------------------------------------ */
WITH delivered_items AS (
    -- One row per delivered order and product.
    SELECT DISTINCT
        order_items.order_id,
        order_items.product_id
    FROM order_items
    JOIN orders
        ON order_items.order_id = orders.order_id
    WHERE orders.order_status = 'delivered'
),

product_pairs AS (
    -- Self-join: same order, different products. product_id < product_id
    -- excludes a product pairing with itself and counts each pair once
    -- (A-B, not also B-A).
    SELECT
        first_item.product_id  AS product_a,
        second_item.product_id AS product_b,
        COUNT(*)               AS how_often
    FROM delivered_items AS first_item
    JOIN delivered_items AS second_item
        ON first_item.order_id = second_item.order_id
       AND first_item.product_id < second_item.product_id
    GROUP BY first_item.product_id, second_item.product_id
)

SELECT TOP 20 WITH TIES
    product_pairs.product_a,
    product_a_details.product_category_name AS category_a,
    product_pairs.product_b,
    product_b_details.product_category_name AS category_b,
    product_pairs.how_often
FROM product_pairs
JOIN products AS product_a_details
    ON product_pairs.product_a = product_a_details.product_id
JOIN products AS product_b_details
    ON product_pairs.product_b = product_b_details.product_id
ORDER BY product_pairs.how_often DESC;


/* ------------------------------------------------------------
   Query 1b: Pairs seen at least 3 times, rolled up to category pairs
   (shows which category combinations the repeating pairs come from)
   ------------------------------------------------------------ */
WITH delivered_items AS (
    SELECT DISTINCT order_items.order_id, order_items.product_id
    FROM order_items
    JOIN orders
        ON order_items.order_id = orders.order_id
    WHERE orders.order_status = 'delivered'
),
product_pairs AS (
    SELECT
        first_item.product_id  AS product_a,
        second_item.product_id AS product_b,
        COUNT(*)               AS how_often
    FROM delivered_items AS first_item
    JOIN delivered_items AS second_item
        ON first_item.order_id = second_item.order_id
       AND first_item.product_id < second_item.product_id
    GROUP BY first_item.product_id, second_item.product_id
    HAVING COUNT(*) >= 3
)
SELECT
    CASE WHEN product_a_details.product_category_name <= product_b_details.product_category_name
         THEN product_a_details.product_category_name
         ELSE product_b_details.product_category_name END AS category_1,
    CASE WHEN product_a_details.product_category_name <= product_b_details.product_category_name
         THEN product_b_details.product_category_name
         ELSE product_a_details.product_category_name END AS category_2,
    COUNT(*) AS recurring_pairs
FROM product_pairs
JOIN products AS product_a_details
    ON product_pairs.product_a = product_a_details.product_id
JOIN products AS product_b_details
    ON product_pairs.product_b = product_b_details.product_id
GROUP BY
    CASE WHEN product_a_details.product_category_name <= product_b_details.product_category_name
         THEN product_a_details.product_category_name
         ELSE product_b_details.product_category_name END,
    CASE WHEN product_a_details.product_category_name <= product_b_details.product_category_name
         THEN product_b_details.product_category_name
         ELSE product_a_details.product_category_name END
ORDER BY recurring_pairs DESC, category_1, category_2;


/* ------------------------------------------------------------
   Query 2: Category pairs: support, confidence and lift
   Universe = delivered baskets with at least 2 different products.
     support_pct       = share of baskets containing both categories
     confidence_a_to_b = of baskets with A, the share that also have B
     expected_baskets  = baskets with both if A and B were independent
     lift              = baskets_with_both / expected_baskets
                         (above 1 = bought together more than chance)
   ------------------------------------------------------------ */
WITH multi_item_baskets AS (
    SELECT order_items.order_id
    FROM order_items
    JOIN orders
        ON order_items.order_id = orders.order_id
    WHERE orders.order_status = 'delivered'
    GROUP BY order_items.order_id
    HAVING COUNT(DISTINCT order_items.product_id) >= 2
),

basket_categories AS (
    -- One row per basket and category.
    SELECT DISTINCT
        order_items.order_id,
        products.product_category_name AS category
    FROM order_items
    JOIN multi_item_baskets
        ON order_items.order_id = multi_item_baskets.order_id
    JOIN products
        ON order_items.product_id = products.product_id
),

category_baskets AS (
    SELECT category, COUNT(*) AS baskets_with_category
    FROM basket_categories
    GROUP BY category
),

basket_total AS (
    SELECT COUNT(*) AS total_baskets
    FROM multi_item_baskets
),

category_pairs AS (
    -- category < category: each pair once, and no category paired with itself.
    SELECT
        first_category.category  AS category_a,
        second_category.category AS category_b,
        COUNT(*)                 AS baskets_with_both
    FROM basket_categories AS first_category
    JOIN basket_categories AS second_category
        ON first_category.order_id = second_category.order_id
       AND first_category.category < second_category.category
    GROUP BY first_category.category, second_category.category
)

SELECT
    category_pairs.category_a,
    category_pairs.category_b,
    category_pairs.baskets_with_both,
    ROUND(category_a_baskets.baskets_with_category * 1.0
        * category_b_baskets.baskets_with_category
        / basket_total.total_baskets, 1)                      AS expected_baskets,
    ROUND(100.0 * category_pairs.baskets_with_both
        / basket_total.total_baskets, 1)                      AS support_pct,
    ROUND(100.0 * category_pairs.baskets_with_both
        / category_a_baskets.baskets_with_category, 1)        AS confidence_a_to_b,
    ROUND(category_pairs.baskets_with_both * 1.0 * basket_total.total_baskets
        / (category_a_baskets.baskets_with_category
         * category_b_baskets.baskets_with_category), 2)      AS lift
FROM category_pairs
JOIN category_baskets AS category_a_baskets
    ON category_pairs.category_a = category_a_baskets.category
JOIN category_baskets AS category_b_baskets
    ON category_pairs.category_b = category_b_baskets.category
CROSS JOIN basket_total
ORDER BY lift DESC, category_pairs.category_a, category_pairs.category_b;


/* ------------------------------------------------------------
   Validation checks
   ------------------------------------------------------------ */

-- V1. Query 2 must return one row per category pair: 10 categories = 45 pairs.
--     (Count the rows of the Query 2 output.)

-- V2. Duplicate product lines: the same product on 2+ lines of one order.
--     Counting lines instead of distinct orders would inflate those pairs.
SELECT COUNT(*) AS orders_with_a_repeated_product
FROM (
    SELECT order_id, product_id
    FROM order_items
    GROUP BY order_id, product_id
    HAVING COUNT(*) > 1
) AS repeated_lines;

-- V3. Ties at the top-20 cut-off: how many pairs share each co-purchase count?
WITH delivered_items AS (
    SELECT DISTINCT order_items.order_id, order_items.product_id
    FROM order_items
    JOIN orders ON order_items.order_id = orders.order_id
    WHERE orders.order_status = 'delivered'
),
product_pairs AS (
    SELECT first_item.product_id AS product_a, second_item.product_id AS product_b, COUNT(*) AS how_often
    FROM delivered_items AS first_item
    JOIN delivered_items AS second_item
        ON first_item.order_id = second_item.order_id
       AND first_item.product_id < second_item.product_id
    GROUP BY first_item.product_id, second_item.product_id
)
SELECT how_often, COUNT(*) AS pairs
FROM product_pairs
GROUP BY how_often
ORDER BY how_often DESC;

-- V4. Catalog size per category (explains why small catalogs look "stronger"
--     at product-pair level).
SELECT product_category_name, COUNT(*) AS products
FROM products
GROUP BY product_category_name
ORDER BY products DESC;

-- V5. In the Query 2 output: baskets_with_both can never exceed the smaller
--     of the two category basket counts, and lift of 1.00 means "no association".
