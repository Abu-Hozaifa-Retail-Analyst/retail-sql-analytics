/* ============================================================
   Project: Sales Forecasting (Trend + Seasonality)
   Business Question: Based on historical sales patterns, what
   should we expect revenue to look like next month -- accounting
   for the fact that some months are naturally bigger than others?

   Dialect: SQL Server (T-SQL)
   ============================================================ */

WITH monthly_sales AS (
    -- Real monthly revenue (same pattern as Project 6).
    SELECT
        DATEFROMPARTS(YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp), 1) AS sales_month,
        SUM(oi.price) AS total_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATEFROMPARTS(YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp), 1)
),

monthly_with_calendar_month AS (
    -- Extract just the calendar month number (1-12), independent
    -- of year, so Jan 2023 and Jan 2024 can be compared together.
    SELECT
        sales_month,
        total_revenue,
        MONTH(sales_month) AS calendar_month
    FROM monthly_sales
),

seasonality AS (
    -- Seasonality index: how much each calendar month tends to run
    -- above/below the overall average. A scalar subquery supplies
    -- the overall average alongside the grouped per-month average --
    -- a plain AVG() inside GROUP BY can't see across groups.
    SELECT
        calendar_month,
        ROUND(AVG(total_revenue) /
            (SELECT AVG(total_revenue) FROM monthly_with_calendar_month), 2) AS seasonality_index
    FROM monthly_with_calendar_month
    GROUP BY calendar_month
),

moving_avg AS (
    -- Trailing 3-month moving average, to smooth out single-month
    -- noise and surface the underlying trend. ROWS BETWEEN 2
    -- PRECEDING AND CURRENT ROW defines a sliding window frame:
    -- for each row, average it with the 2 rows immediately before it.
    SELECT
        sales_month,
        total_revenue,
        AVG(total_revenue) OVER (
            ORDER BY sales_month
            ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
        ) AS moving_avg_3mo
    FROM monthly_sales
),

latest_trend AS (
    -- The single most recent month's moving average -- this is
    -- the trend signal the forecast will be built from.
    SELECT TOP 1 moving_avg_3mo
    FROM moving_avg
    ORDER BY sales_month DESC
)

-- Combine trend x seasonality for the forecast. CROSS JOIN is used
-- deliberately here: latest_trend and the target month's
-- seasonality row are each exactly one row with no shared key to
-- join on -- there's nothing to match, just two single values to
-- combine side by side.
SELECT
    '2025-01-01' AS forecast_month,
    lt.moving_avg_3mo AS recent_trend,
    s.seasonality_index AS january_seasonality_index,
    ROUND(lt.moving_avg_3mo * s.seasonality_index, 2) AS forecasted_revenue,
    ROUND(lt.moving_avg_3mo, 2) AS naive_forecast_no_seasonality
FROM latest_trend lt
CROSS JOIN seasonality s
WHERE s.calendar_month = 1;  -- forecasting January
