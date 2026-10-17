/* ============================================================
   Project: Pricing & Discount Analysis
   Business Question: Do lower-priced / more-discounted items sell in higher
   volume, and where does the typical selling price sit relative to list
   price, by category?

   Dialect: SQL Server (T-SQL)
   Database: RetailAnalytics (synthetic Olist-style data)

   Design decisions (see README, "Method"):
   - price_vs_list_pct = (sold price - list price) / list price * 100.
     POSITIVE = sold ABOVE list, NEGATIVE = sold below list (a discount).
     (The first version used the opposite sign and called it discount_pct.)
   - Only DELIVERED orders count as sales.
   - "Does a lower price sell more?" is tested where there are enough points:
     per product (about 239) and per month (24), with Pearson r and a 95%
     confidence interval. Ten category medians cannot answer it.
   - Nov-Dec is the volume peak: if discounts drove volume, prices there would be lower.
   ============================================================ */
USE RetailAnalytics;
GO

/* ------------------------------------------------------------
   Query 1: price vs list price, by category
   ------------------------------------------------------------ */
WITH item_prices AS (
    SELECT
        order_items.order_id,
        order_items.product_id,
        products.product_category_name,
        orders.order_purchase_timestamp AS order_date,
        (order_items.price - products.base_price) * 100.0 / products.base_price AS price_vs_list_pct
    FROM order_items
    JOIN products
        ON order_items.product_id = products.product_id
    JOIN orders
        ON order_items.order_id = orders.order_id
    WHERE orders.order_status = 'delivered'
),

category_percentiles AS (
    -- Median and quartiles by category. PERCENTILE_CONT interpolates between
    -- the two middle values when the percentile falls between them.
    SELECT DISTINCT
        product_category_name,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY price_vs_list_pct)
            OVER (PARTITION BY product_category_name) AS p25_value,
        PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY price_vs_list_pct)
            OVER (PARTITION BY product_category_name) AS median_value,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY price_vs_list_pct)
            OVER (PARTITION BY product_category_name) AS p75_value
    FROM item_prices
),

category_volume AS (
    SELECT
        product_category_name,
        COUNT(*) AS items_sold,
        ROUND(100.0 * SUM(CASE WHEN price_vs_list_pct < 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_sold_below_list
    FROM item_prices
    GROUP BY product_category_name
)

SELECT
    category_volume.product_category_name,
    category_volume.items_sold,
    ROUND(category_percentiles.p25_value, 1)    AS p25_price_vs_list_pct,
    ROUND(category_percentiles.median_value, 1) AS median_price_vs_list_pct,
    ROUND(category_percentiles.p75_value, 1)    AS p75_price_vs_list_pct,
    category_volume.pct_sold_below_list
FROM category_percentiles
JOIN category_volume
    ON category_percentiles.product_category_name = category_volume.product_category_name
ORDER BY category_volume.items_sold DESC, category_volume.product_category_name;


/* ------------------------------------------------------------
   Query 2: does a lower price go with higher volume?
   Pearson r (manual formula) and a 95% confidence interval (Fisher z)
   at product level and at month level.
   ------------------------------------------------------------ */
WITH item_prices AS (
    SELECT
        order_items.product_id,
        orders.order_purchase_timestamp AS order_date,
        (order_items.price - products.base_price) * 100.0 / products.base_price AS price_vs_list_pct
    FROM order_items
    JOIN products
        ON order_items.product_id = products.product_id
    JOIN orders
        ON order_items.order_id = orders.order_id
    WHERE orders.order_status = 'delivered'
),

product_points AS (
    -- x = the product's average price vs list, y = items sold
    SELECT 'product' AS level_name,
           CAST(AVG(price_vs_list_pct) AS FLOAT) AS x,
           CAST(COUNT(*) AS FLOAT)               AS y
    FROM item_prices
    GROUP BY product_id
),

month_points AS (
    SELECT 'month' AS level_name,
           CAST(AVG(price_vs_list_pct) AS FLOAT) AS x,
           CAST(COUNT(*) AS FLOAT)               AS y
    FROM item_prices
    GROUP BY YEAR(order_date), MONTH(order_date)
),

all_points AS (
    SELECT level_name, x, y FROM product_points
    UNION ALL
    SELECT level_name, x, y FROM month_points
),

correlations AS (
    SELECT
        level_name,
        COUNT(*) AS n,
        (COUNT(*) * SUM(x * y) - SUM(x) * SUM(y))
          / SQRT((COUNT(*) * SUM(x * x) - SUM(x) * SUM(x))
               * (COUNT(*) * SUM(y * y) - SUM(y) * SUM(y))) AS r
    FROM all_points
    GROUP BY level_name
),

fisher AS (
    SELECT level_name, n, r,
           0.5 * LOG((1 + r) / (1 - r)) AS z,
           1.0 / SQRT(n - 3)            AS standard_error
    FROM correlations
)

SELECT
    level_name,
    n,
    ROUND(r, 3) AS pearson_r,
    ROUND((EXP(2 * (z - 1.96 * standard_error)) - 1)
        / (EXP(2 * (z - 1.96 * standard_error)) + 1), 2) AS ci_low,
    ROUND((EXP(2 * (z + 1.96 * standard_error)) - 1)
        / (EXP(2 * (z + 1.96 * standard_error)) + 1), 2) AS ci_high
FROM fisher
ORDER BY level_name DESC;


/* ------------------------------------------------------------
   Query 3: peak months vs other months
   If discounts drove volume, Nov-Dec prices would be lower.
   ------------------------------------------------------------ */
WITH item_prices AS (
    SELECT
        orders.order_purchase_timestamp AS order_date,
        (order_items.price - products.base_price) * 100.0 / products.base_price AS price_vs_list_pct
    FROM order_items
    JOIN products
        ON order_items.product_id = products.product_id
    JOIN orders
        ON order_items.order_id = orders.order_id
    WHERE orders.order_status = 'delivered'
)
SELECT
    CASE WHEN MONTH(order_date) IN (11, 12) THEN 'Nov-Dec (peak)' ELSE 'Other months' END AS period,
    COUNT(*) AS items_sold,
    COUNT(DISTINCT YEAR(order_date) * 100 + MONTH(order_date)) AS months,
    ROUND(COUNT(*) * 1.0 / COUNT(DISTINCT YEAR(order_date) * 100 + MONTH(order_date)), 0) AS items_per_month,
    ROUND(AVG(price_vs_list_pct), 2) AS avg_price_vs_list_pct
FROM item_prices
GROUP BY CASE WHEN MONTH(order_date) IN (11, 12) THEN 'Nov-Dec (peak)' ELSE 'Other months' END
ORDER BY items_per_month DESC;


/* ------------------------------------------------------------
   Validation checks
   ------------------------------------------------------------ */

-- V1. With ALL orders (remove the delivered filter) and the sign flipped, the
--     Query 1 medians equal the first version's output (-2.6, -3.0, -2.1 ...).
--     With delivered orders only they move by at most 0.13 points.

-- V2. Prices are bounded around list: sold price is between 0.90x and 1.15x of list.
SELECT MIN(order_items.price / products.base_price) AS min_price_to_list,
       MAX(order_items.price / products.base_price) AS max_price_to_list
FROM order_items
JOIN products ON order_items.product_id = products.product_id;

-- V3. Row counts: delivered lines vs all lines (7,148 of 7,624).
SELECT SUM(CASE WHEN orders.order_status = 'delivered' THEN 1 ELSE 0 END) AS delivered_lines,
       COUNT(*)                                                           AS all_lines
FROM order_items
JOIN orders ON order_items.order_id = orders.order_id;

-- V4. No missing or zero list prices (a division by zero would break the ratio). Expected: 0.
SELECT COUNT(*) AS bad_list_prices
FROM products
WHERE base_price IS NULL OR base_price = 0;

-- V5. Spot check one product by hand against the product-level points.
SELECT TOP 1 products.product_id,
       COUNT(*) AS items_sold,
       AVG((order_items.price - products.base_price) * 100.0 / products.base_price) AS avg_price_vs_list_pct
FROM order_items
JOIN products ON order_items.product_id = products.product_id
JOIN orders ON order_items.order_id = orders.order_id
WHERE orders.order_status = 'delivered'
GROUP BY products.product_id
ORDER BY products.product_id;
