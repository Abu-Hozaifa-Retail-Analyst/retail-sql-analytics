/* ============================================================
   Project: Purchase Timing Patterns (Day-of-Week & Hour-of-Day)
   Business Question: When do customers actually shop? Are there
   real peak days or hours that should drive staffing, flash-sale
   timing, or promotional scheduling?

   Dialect: SQL Server (T-SQL)
   ============================================================ */

-- SET DATEFIRST makes weekday numbering deterministic (1 = Sunday)
-- regardless of the server's regional/locale settings. Without this,
-- DATEPART(WEEKDAY, ...) can silently return different numbers on
-- a different server, breaking the sort order below.
SET DATEFIRST 7;

WITH day_of_week AS (
    -- DATENAME(WEEKDAY, ...) gives a readable label ("Monday"), but
    -- sorting on that label alphabetically would put "Friday" before
    -- "Monday" -- wrong. DATEPART(WEEKDAY, ...) gives the correct
    -- chronological sort key (a number) without displaying it.
    SELECT
        DATENAME(WEEKDAY, o.order_purchase_timestamp) AS weekday_name,
        DATEPART(WEEKDAY, o.order_purchase_timestamp) AS weekday_sort_key,
        o.order_id,
        p.payment_value
    FROM orders o
    JOIN payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
)

SELECT
    weekday_name,
    COUNT(*) AS order_count,
    ROUND(SUM(payment_value), 2) AS revenue
FROM day_of_week
GROUP BY weekday_name, weekday_sort_key
ORDER BY weekday_sort_key;

/* ------------------------------------------------------------
   Hour-of-day breakdown
   ------------------------------------------------------------ */

WITH hour_of_day AS (
    SELECT
        DATEPART(HOUR, o.order_purchase_timestamp) AS order_hour,
        o.order_id,
        p.payment_value
    FROM orders o
    JOIN payments p ON o.order_id = p.order_id
    WHERE o.order_status = 'delivered'
)

SELECT
    order_hour,
    COUNT(*) AS order_count,
    ROUND(SUM(payment_value), 2) AS revenue
FROM hour_of_day
GROUP BY order_hour
ORDER BY order_hour;

/* ------------------------------------------------------------
   Peak windows: top day + hour combinations by order volume
   ------------------------------------------------------------ */

WITH day_hour AS (
    SELECT
        DATENAME(WEEKDAY, o.order_purchase_timestamp) AS weekday_name,
        DATEPART(HOUR, o.order_purchase_timestamp) AS order_hour,
        o.order_id
    FROM orders o
    WHERE o.order_status = 'delivered'
)

SELECT TOP 5
    weekday_name,
    order_hour,
    COUNT(*) AS order_count
FROM day_hour
GROUP BY weekday_name, order_hour
ORDER BY order_count DESC;
