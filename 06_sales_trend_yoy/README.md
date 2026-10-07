# Sales Trend & Year-over-Year Growth

## 1. Business Question

How are retail sales changing month to month and year over year? Are there months with genuinely zero sales that could disappear from a normal aggregation, and which growth measure is more useful for management reporting?

The analysis builds a gap-safe monthly sales trend for January 2023 through December 2024 and compares both short-term MoM movement and same-month YoY growth.

## 2. Dataset & Analytical Grain

The analysis uses the repository's SQL Server retail dataset.

- **Time grain:** calendar month
- **Transaction scope:** orders where `order_status = 'delivered'`
- **Revenue measure:** `SUM(order_items.price)` for delivered orders
- **Date field:** `orders.order_purchase_timestamp`
- **Analysis window:** January 2023 to December 2024
- **Output grain:** one row per calendar month

A recursive month spine is generated independently of transaction activity. This means a month with no delivered sales remains visible with revenue of `0` instead of disappearing from the result.

## 3. Methodology

The SQL workflow is:

1. **Generate a complete month spine** from January 2023 through December 2024 using a recursive CTE.
2. **Aggregate delivered sales by calendar month** using `DATEFROMPARTS(YEAR(...), MONTH(...), 1)`.
3. **Left join monthly sales to the month spine** so months without sales are retained.
4. **Replace missing monthly revenue with zero** using `ISNULL()`.
5. **Calculate MoM growth** using `LAG(..., 1)`.
6. **Calculate YoY growth** using `LAG(..., 12)` so each month is compared with the same month in the prior year.
7. **Protect growth calculations** with `NULLIF(..., 0)` to avoid division-by-zero when the comparison period has zero revenue.

Using a full calendar spine is important for reliable trend reporting: a missing row and a true zero-sales month are different business situations.

## 4. SQL Implementation

The project demonstrates practical T-SQL techniques including:

- Recursive CTEs
- `DATEADD()`
- `DATEFROMPARTS()`
- `YEAR()` and `MONTH()`
- `LEFT JOIN`
- `ISNULL()`
- `LAG()` with explicit offsets
- `NULLIF()` for safe ratio calculations
- Month-level aggregation
- MoM and YoY growth calculations
- `OPTION (MAXRECURSION 100)`

See [query.sql](./query.sql) for the implementation.

## 5. Validation

The analysis includes several important validation checks:

- The generated month spine contains **24 consecutive months**, covering January 2023 through December 2024.
- The sample output contains **24 monthly rows**, one for each month in the requested window.
- January 2023 has no prior month or prior year in the analysis window, so its MoM and YoY growth values are correctly `NULL`.
- MoM compares each month with the immediately preceding month using `LAG(..., 1)`.
- YoY compares each month with the same calendar month one year earlier using `LAG(..., 12)`.
- Monthly revenue is based only on `delivered` orders, matching the business scope defined in the query.
- The date logic keeps year and month together; using `MONTH()` alone would incorrectly combine January 2023 with January 2024.
- The `NULLIF()` guard prevents a divide-by-zero failure if a comparison month has zero revenue.

## 6. Observed Findings

Every month in 2024 recorded positive YoY growth versus the corresponding month in 2023.

2024 YoY growth ranged from **20.6% to 144.5%**. The strongest increases occurred in **January (+143.3%)** and **February (+144.5%)**, while the lowest was **December (+20.6%)**.

MoM movement was considerably more volatile. For example, October 2024 was almost flat at **-0.6% MoM**, followed by a **+59.5% MoM** increase in November. However, November's YoY growth was only **+24.8%**, showing that the large MoM swing does not necessarily represent a comparable change in the underlying annual trend.

November 2024 also had the highest monthly revenue in the output at **143,927.70**, followed by December at **137,469.46**.

These results are descriptive: they show the pattern of sales movement but do not identify why sales changed.

## 7. Business Implication

For management reporting, **YoY is the stronger primary trend metric** when seasonality or recurring monthly patterns can make MoM comparisons noisy.

MoM remains useful for operational monitoring because it can identify sudden changes that require investigation. However, a large MoM movement should be investigated alongside YoY, historical seasonality, promotions, pricing, inventory availability, and other business drivers before interpreting it as a change in business health.

The month-spine design also improves dashboard reliability. A genuine zero-sales month will appear as zero rather than disappearing from a trend chart and potentially exaggerating the apparent recovery in the following month.

## 8. Recommendations

### Business reporting

- Use YoY as a primary management KPI for monthly sales trend reporting.
- Keep MoM as a short-term operational monitoring metric.
- Investigate unusually large MoM movements before presenting them as structural business changes.
- Add sales targets or budget to distinguish growth from performance against plan.

### Analytical next steps

- Break YoY growth down by store, category, product, and customer segment.
- Add promotion, pricing, inventory availability, and channel dimensions to investigate drivers.
- Separate volume growth from price/mix effects using units and average selling price where available.
- Add rolling 3-month and 12-month views to reduce short-term volatility.
- Monitor data completeness so missing transaction periods are distinguished from genuine zero-sales periods.

## 9. Limitations

- The revenue measure is `SUM(order_items.price)` and does not include or subtract other financial components such as freight, payment values, discounts, returns, or cost.
- The query includes only orders with `order_status = 'delivered'`.
- The analysis covers January 2023 through December 2024 only.
- MoM and YoY growth are descriptive and do not establish causal drivers.
- No adjustment is made for promotions, pricing, inventory availability, holidays, store openings/closures, customer mix, or channel changes.
- A zero revenue month can be represented correctly by the month spine, but a zero may require business investigation to distinguish true inactivity from upstream data failure.
- The dataset is a practice/synthetic retail dataset, so the observed growth rates should not be presented as real-world market performance.

## 10. Reproducibility

1. Complete the database setup described in [datasets/README.md](../datasets/README.md).
2. Select the `RetailAnalytics` database in SQL Server.
3. Run [query.sql](./query.sql).
4. Compare the result with [sample_output.csv](./sample_output.csv).

The query is written for **SQL Server / T-SQL** and uses a recursive CTE with `OPTION (MAXRECURSION 100)`.

## 11. Portfolio Skills Demonstrated

- Retail sales trend analysis
- MoM and YoY KPI analysis
- Time-series data preparation in SQL
- Gap-safe calendar/month-spine design
- Recursive CTEs
- Window functions
- SQL Server / T-SQL
- Metric validation
- Business KPI interpretation
- Translating analytical results into management reporting recommendations

## 12. Project Files

| File | Purpose |
|---|---|
| [query.sql](./query.sql) | Monthly sales trend, MoM, and YoY analysis |
| [sample_output.csv](./sample_output.csv) | Full monthly result for January 2023–December 2024 |