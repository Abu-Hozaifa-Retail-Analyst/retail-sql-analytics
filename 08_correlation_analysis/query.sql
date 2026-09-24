/* ============================================================
   Project: Correlation Analysis (Order Frequency vs. Order Value)
   Business Question: Is there a relationship between how often a
   customer orders and how much they spend per order? Are frequent
   buyers bargain-hunters (small, frequent purchases), big spenders
   who also happen to buy often, or is there no relationship at all?

   SQL Server has no built-in CORR() function (unlike some other
   databases), so the Pearson correlation coefficient is computed
   manually here from its underlying formula:

     r = (n*sum_xy - sum_x*sum_y) /
         SQRT((n*sum_x2 - sum_x^2) * (n*sum_y2 - sum_y^2))

   r ranges from -1 (perfectly inverse) to +1 (perfectly together),
   with 0 meaning no linear relationship.

   Dialect: SQL Server (T-SQL)
   ============================================================ */

WITH customer_metrics AS (
    -- Per-customer order frequency and total spend, delivered
    -- orders only (same "real engagement" filter used throughout
    -- this repo).
    SELECT
        c.customer_unique_id,
        COUNT(*) AS order_count,
        SUM(p.payment_value) AS total_spent
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
),

metrics_with_avg AS (
    -- Derive average order value: how much a customer spends per
    -- order, independent of how many orders they've placed.
    SELECT
        customer_unique_id,
        order_count,
        total_spent,
        total_spent * 1.0 / order_count AS avg_order_value
    FROM customer_metrics
),

correlation_stats AS (
    -- The six building blocks the Pearson formula needs: n, and
    -- the sums of x, y, x*y, x^2, y^2 across every customer.
    SELECT
        COUNT(*) AS n,
        SUM(order_count * 1.0) AS sum_x,
        SUM(avg_order_value) AS sum_y,
        SUM(order_count * 1.0 * avg_order_value) AS sum_xy,
        SUM(POWER(order_count * 1.0, 2)) AS sum_x2,
        SUM(POWER(avg_order_value, 2)) AS sum_y2
    FROM metrics_with_avg
)

SELECT
    n AS customers_analyzed,
    ROUND(
        (n * sum_xy - sum_x * sum_y) /
        NULLIF(SQRT((n * sum_x2 - POWER(sum_x, 2)) * (n * sum_y2 - POWER(sum_y, 2))), 0)
    , 3) AS correlation_order_count_vs_avg_order_value
FROM correlation_stats;

/* ------------------------------------------------------------
   Secondary check, for contrast: does line-item price correlate
   with freight (shipping) cost? A reasonable person might expect
   higher-priced items to cost more to ship.
   ------------------------------------------------------------ */

WITH freight_stats AS (
    SELECT
        COUNT(*) AS n,
        SUM(price * 1.0) AS sum_x,
        SUM(freight_value * 1.0) AS sum_y,
        SUM(price * 1.0 * freight_value) AS sum_xy,
        SUM(POWER(price * 1.0, 2)) AS sum_x2,
        SUM(POWER(freight_value * 1.0, 2)) AS sum_y2
    FROM order_items
)

SELECT
    n AS line_items_analyzed,
    ROUND(
        (n * sum_xy - sum_x * sum_y) /
        NULLIF(SQRT((n * sum_x2 - POWER(sum_x, 2)) * (n * sum_y2 - POWER(sum_y, 2))), 0)
    , 3) AS correlation_price_vs_freight
FROM freight_stats;
