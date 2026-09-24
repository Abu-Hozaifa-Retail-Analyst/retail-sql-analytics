# Sales Forecasting (Trend + Seasonality)

## Business Question
Based on historical sales patterns, what should we expect revenue to look
like next month — accounting for the fact that some months (like
November/December) are naturally bigger than others? A forecast built on
trend alone risks being misled by whatever happened most recently, without
knowing whether that period was typical or unusual for the calendar.

## Approach
Built a lightweight, SQL-native forecast (no external ML library) by
combining two independent signals:
1. **Seasonality index** — for each calendar month, `(average revenue for
   that month) / (average revenue across all months)`. A scalar subquery
   supplies the overall average alongside each grouped row, since a plain
   `AVG()` inside `GROUP BY` can't see across groups on its own
2. **Trailing 3-month moving average** — using a window function with an
   explicit **window frame** (`ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`),
   smoothing out single-month noise to surface the underlying trend
   direction. This is a different window function pattern than earlier
   projects — instead of the whole partition or one fixed offset row, it
   defines a sliding 3-row window that moves forward one month at a time
3. **Combined forecast** — `(most recent moving average) × (seasonality
   index for the target month)`, joined together with a `CROSS JOIN`
   since both sides are single, unrelated values with nothing to match on

See [`query.sql`](./query.sql) for the full implementation.

## Finding
A trend-only forecast for January 2025 projects **$123,884** in revenue,
but adjusting for January's seasonal weakness — a **0.86 seasonality
index**, meaning the month historically runs 14% below average — drops the
forecast to **$106,540**, a gap of roughly **$17,300**. This gap exists
because the 3-month trailing average pulls the trend upward from November
and December's holiday peak (the highest revenue of the entire dataset),
so a naive forecast effectively assumes that holiday-level momentum
carries straight into January — when historically, January is one of the
two weakest months of the year (0.86, second only to February's 0.66).

**So what:** Relying on trend alone would lead the business to
over-forecast January — risking over-ordering inventory, over-staffing, or
setting a sales target that undershoots by design. Any forecast built on a
short trailing window should be paired with a seasonality adjustment
before it's used for planning, not treated as a standalone number.

## Sample Output

**Seasonality index by month:**
| calendar_month | seasonality_index |
|---|---|
| 1 (Jan) | 0.86 |
| 2 (Feb) | 0.66 |
| 11 (Nov) | 1.59 |
| 12 (Dec) | 1.54 |

**Final forecast:**
| forecast_month | recent_trend | january_seasonality_index | forecasted_revenue | naive_forecast_no_seasonality |
|---|---|---|---|---|
| 2025-01-01 | 123883.51 | 0.86 | 106539.82 | 123883.51 |

*(Full output in [`sample_output.csv`](./sample_output.csv))*
