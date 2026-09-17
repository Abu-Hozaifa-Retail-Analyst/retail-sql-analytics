# Sales Trend & Year-over-Year Growth

## Business Question
What does month-over-month and year-over-year sales growth actually look
like — and are we sure we're not missing months where sales were
genuinely zero? A trend built only from a `GROUP BY` on real orders can
silently drop a dead month entirely, rather than showing it as the zero it
actually was.

## Approach
Built a gap-safe monthly sales trend in SQL Server, combining a recursive
CTE with `LAG()`:
1. Used a **recursive CTE** (`month_spine`) to generate every month in the
   analysis window (Jan 2023–Dec 2024), independent of whether any sales
   happened — an anchor row (the first month) `UNION ALL`'d with a
   recursive step that adds one more month each pass, until the end date
2. Computed real monthly revenue via `DATEFROMPARTS(YEAR(...), MONTH(...),
   1)` — critical because `MONTH()` alone would collapse January 2023 and
   January 2024 into the same bucket, silently merging two different
   years of data
3. `LEFT JOIN`ed the spine to real sales so every month survives in the
   output, using `ISNULL(..., 0)` to turn a missing match into an honest
   zero rather than a gap
4. Used `LAG(revenue, 1)` for month-over-month comparison and
   `LAG(revenue, 12)` for year-over-year — the first time in this
   portfolio using `LAG`'s offset argument for anything other than "the
   immediately previous row"
5. Wrapped both growth calculations in `NULLIF(..., 0)` to prevent a
   divide-by-zero error if a prior period genuinely had no revenue

See [`query.sql`](./query.sql) for the full implementation.

## Finding
Every month in 2024 outgrew the same month in 2023, with YoY growth
ranging from **20.6% to 143.3%** — a full year of consistent, real
growth rather than an isolated good month. Month-over-month growth,
though, is highly volatile and can be misleading on its own: **November
2024 jumped 59.5% right after October was nearly flat (-0.6%)**, while the
underlying YoY trend for both months stayed steady in the low-to-mid 20s —
showing the noisy MoM swing wasn't signaling any real change in business
health.

**So what:** For leadership reporting, YoY should be the primary growth
metric, with MoM reserved for short-term operational monitoring rather
than trend conclusions. Building the report on a generated date spine
(via recursive CTE) also matters operationally — it ensures that if a
future month genuinely has zero sales, it shows up as an honest zero in
the trend rather than silently vanishing from the report, which is a
common way dashboards mislead without anyone noticing.

## Sample Output
| month_start | total_revenue | mom_growth_pct | yoy_growth_pct |
|---|---|---|---|
| 2024-01-01 | 98989.82 | -13.2 | 143.3 |
| 2024-02-01 | 76812.53 | -22.4 | 144.5 |
| 2024-10-01 | 90253.37 | -0.6 | 23.1 |
| 2024-11-01 | 143927.70 | 59.5 | 24.8 |
| 2024-12-01 | 137469.46 | -4.5 | 20.6 |

*(Full output in [`sample_output.csv`](./sample_output.csv))*
