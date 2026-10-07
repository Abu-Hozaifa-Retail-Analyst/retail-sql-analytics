# Sales Forecasting — Trend + Seasonality

## 1. Business Question

Based on historical monthly sales, what should the business expect for the next month when recent trend and recurring calendar seasonality point in different directions?

This project builds a transparent SQL-native forecast for **January 2025** by combining a recent 3-month trend signal with a calendar-month seasonality index.

## 2. Dataset & Analytical Grain

The analysis uses the repository's SQL Server retail dataset.

- **Time grain:** calendar month
- **Transaction scope:** orders where `order_status = 'delivered'`
- **Revenue measure:** `SUM(order_items.price)`
- **Historical period:** monthly sales available through December 2024
- **Forecast target:** January 2025
- **Seasonality grain:** calendar month number (1–12)

The forecast is intentionally lightweight and interpretable. It does not use an external machine-learning library or claim to be a production forecasting model.

## 3. Methodology

The forecast combines two independent signals:

### 3.1 Monthly sales baseline

Delivered order-item revenue is aggregated to calendar month using `DATEFROMPARTS(YEAR(...), MONTH(...), 1)`.

### 3.2 Seasonality index

For each calendar month, the analysis calculates:

`seasonality index = average revenue for that calendar month / overall average monthly revenue`

This allows January 2023 and January 2024 to contribute to a shared January seasonal pattern.

### 3.3 Recent trend

A **trailing 3-month moving average** is calculated using:

`ROWS BETWEEN 2 PRECEDING AND CURRENT ROW`

The latest available moving average becomes the recent trend signal.

### 3.4 Forecast

The January forecast is calculated as:

`forecasted revenue = latest 3-month moving average × January seasonality index`

A trend-only value is retained as a naive comparison so the business impact of the seasonal adjustment can be seen directly.

## 4. SQL Implementation

The project demonstrates practical T-SQL techniques including:

- CTEs
- Monthly aggregation
- `DATEFROMPARTS()`
- `MONTH()`
- Scalar subqueries
- `AVG()`
- Window functions
- Explicit window frames
- `ROWS BETWEEN ... PRECEDING AND CURRENT ROW`
- `TOP 1` with ordered latest-period selection
- `CROSS JOIN` for combining independent single-row signals
- SQL-native baseline forecasting

See [query.sql](./query.sql) for the implementation.

## 5. Validation

The analysis includes several validation checks:

- The seasonality output contains **12 calendar months**, one for each month number from 1 to 12.
- The overall average monthly revenue is consistently **81,463.64** across the seasonality calculations.
- January's seasonality index is **0.86**, meaning its historical average revenue is approximately 14% below the overall monthly average.
- February has the lowest seasonality index at **0.66**.
- November and December have the strongest seasonal indices at **1.59** and **1.54**.
- The latest 3-month moving average used by the forecast is **123,883.51**.
- The final forecast is calculated directly as `123,883.51 × 0.86 = 106,539.82` after rounding.
- The naive forecast without seasonality remains **123,883.51**, making the seasonal adjustment transparent.

These checks validate the arithmetic and structure of the forecast; they do **not** establish that the forecast is accurate on future unseen data.

## 6. Observed Findings

The trend-only January 2025 forecast is **123,883.51**, while the seasonality-adjusted forecast is **106,539.82**.

The difference is approximately **17,343.69**, or about **14.0% lower** than the trend-only value.

January has a seasonality index of **0.86**, while November and December have much stronger historical indices of **1.59** and **1.54**. The latest 3-month trend is therefore influenced by the strong November–December period, while the January seasonal factor pulls the forecast downward.

The result illustrates why a short trailing trend should not automatically be carried into the next calendar period without considering recurring seasonal behavior.

## 7. Business Implication

A retailer using only the recent 3-month trend could plan around approximately **123.9K** of January revenue, while the simple seasonality-adjusted baseline suggests approximately **106.5K**.

This difference can matter for planning decisions such as sales targets, staffing, inventory allocation, and purchasing. However, the forecast should be treated as a planning baseline rather than a guaranteed outcome.

The SQL-native approach is particularly useful as a transparent benchmark: more advanced forecasting methods can be compared against this baseline to determine whether added complexity actually improves out-of-sample accuracy.

## 8. Recommendations

### Business planning

- Use the seasonality-adjusted result as a **baseline scenario**, not as a committed target.
- Compare the forecast with inventory, staffing, and sales-capacity plans before operational decisions are made.
- Review November and December separately because holiday-period strength can materially influence a short trailing window.

### Analytical next steps

- Backtest the forecasting method on historical periods rather than evaluating it only on the January 2025 point.
- Compare against simple baselines such as naive and seasonal-naive forecasts.
- Measure MAE, RMSE, WAPE, and forecast bias on out-of-sample periods.
- Test longer and shorter moving-average windows.
- Add promotion, pricing, inventory availability, store, category, and channel drivers when reliable data becomes available.
- Evaluate whether more advanced models provide a meaningful accuracy improvement over this transparent baseline.

## 9. Limitations

- This is a **single-period forecast example** for January 2025, not a validated production forecasting system.
- The model uses only historical revenue, recent trend, and calendar-month seasonality.
- The 3-month moving average can be sensitive to unusual recent periods.
- The seasonality index is estimated from the available historical years and may be unstable with a small number of observations.
- No chronological backtesting or out-of-sample accuracy metrics are included in this SQL project.
- No confidence or prediction intervals are produced.
- No promotions, pricing, inventory availability, holidays, store changes, customer mix, or channel effects are modeled.
- The revenue measure is `SUM(order_items.price)` and does not represent a full financial profit or cash-flow measure.
- The dataset is a practice/synthetic retail dataset, so the forecast should not be presented as a real market forecast.

## 10. Reproducibility

1. Complete the database setup described in [datasets/README.md](../datasets/README.md).
2. Select the `RetailAnalytics` database in SQL Server.
3. Run [query.sql](./query.sql).
4. Compare the result with [sample_output.csv](./sample_output.csv).

The query is written for **SQL Server / T-SQL**.

## 11. Portfolio Skills Demonstrated

- Retail sales forecasting
- Trend and seasonality analysis
- SQL Server / T-SQL
- Moving averages
- Window functions and window frames
- Seasonality indices
- Baseline forecasting
- Forecast transparency and validation
- Business planning interpretation
- Recognizing the difference between a baseline and a validated forecasting model

## 12. Project Files

| File | Purpose |
|---|---|
| [query.sql](./query.sql) | SQL-native trend + seasonality forecast for January 2025 |
| [sample_output.csv](./sample_output.csv) | Seasonality indices and final forecast output |