/* ============================================================
   Project: Sales Trend & Year-over-Year Growth
   Business Question: What does month-over-month and year-over-year
   sales growth actually look like -- and are we sure we're not
   missing months where sales were genuinely zero?

   Dialect: SQL Server (T-SQL)
   ============================================================ */

WITH month_spine AS (
    -- Recursive CTE: generate every month in the analysis window,
    -- whether or not any sales happened in it. Without this, a
    -- genuinely zero-sales month would simply have no row in
    -- orders/order_items and would silently vanish from a plain
    -- GROUP BY -- making a recovery look bigger than it really was,
    -- or hiding a real gap in the business entirely.
    SELECT CAST('2023-01-01' AS DATE) AS month_start

    UNION ALL

    SELECT DATEADD(MONTH, 1, month_start)
    FROM month_spine
    WHERE month_start < '2024-12-01'
),

monthly_sales AS (
    -- Real monthly revenue. DATEFROMPARTS(YEAR(...), MONTH(...), 1)
    -- keeps year and month together -- MONTH() alone would collapse
    -- Jan 2023 and Jan 2024 into the same bucket.
    SELECT
        DATEFROMPARTS(YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp), 1) AS sales_month,
        SUM(oi.price) AS total_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY DATEFROMPARTS(YEAR(o.order_purchase_timestamp), MONTH(o.order_purchase_timestamp), 1)
),

final AS (
    -- LEFT JOIN the spine to real sales so every month survives,
    -- even one with zero orders. ISNULL turns a missing match into
    -- an honest 0 instead of a gap.
    SELECT
        ms.month_start,
        ISNULL(sales.total_revenue, 0) AS total_revenue,
        LAG(ISNULL(sales.total_revenue, 0), 1) OVER (ORDER BY ms.month_start) AS prev_month_revenue,
        LAG(ISNULL(sales.total_revenue, 0), 12) OVER (ORDER BY ms.month_start) AS prev_year_revenue
    FROM month_spine ms
    LEFT JOIN monthly_sales sales ON ms.month_start = sales.sales_month
)

-- MoM uses LAG(..., 1) -- one row/month back.
-- YoY uses LAG(..., 12) -- twelve rows/months back, i.e. same month
-- last year. NULLIF guards against divide-by-zero if a prior period
-- genuinely had $0 revenue.
SELECT
    month_start,
    total_revenue,
    ROUND(100.0 * (total_revenue - prev_month_revenue) / NULLIF(prev_month_revenue, 0), 1) AS mom_growth_pct,
    ROUND(100.0 * (total_revenue - prev_year_revenue) / NULLIF(prev_year_revenue, 0), 1) AS yoy_growth_pct
FROM final
ORDER BY month_start
OPTION (MAXRECURSION 100);
