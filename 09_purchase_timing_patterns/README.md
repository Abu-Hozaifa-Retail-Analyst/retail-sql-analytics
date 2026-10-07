# Purchase Timing Patterns — Day-of-Week & Hour-of-Day

## 1. Business Question

When do customers actually place orders? Are there meaningful peak days or hours that could inform staffing, promotional timing, or operational coverage?

The project analyzes delivered-order timing by weekday, hour of day, and combined day-hour windows.

## 2. Dataset & Analytical Grain

The analysis uses the repository's SQL Server retail dataset.

- **Transaction scope:** orders where `order_status = 'delivered'`
- **Primary time field:** `orders.order_purchase_timestamp`
- **Weekday grain:** one row per weekday
- **Hourly grain:** one row per hour represented in the data
- **Peak-window grain:** one row per weekday + hour combination
- **Order metric:** `COUNT(*)` of delivered orders
- **Revenue metric:** `SUM(payments.payment_value)` for the weekday/hour breakdowns

The sample output contains **4,260 delivered orders** across the seven weekday groups and the fourteen represented hours.

## 3. Methodology

The SQL workflow has three complementary views:

### 3.1 Day-of-week analysis

`DATENAME(WEEKDAY, ...)` creates readable weekday names, while `DATEPART(WEEKDAY, ...)` creates a numeric sort key.

`SET DATEFIRST 7` makes the weekday numbering deterministic, with Sunday as day 1, regardless of SQL Server session or regional settings.

This prevents a subtle reporting problem where weekday names could otherwise be sorted alphabetically or numbered differently across environments.

### 3.2 Hour-of-day analysis

`DATEPART(HOUR, order_purchase_timestamp)` extracts the hour so order volume and revenue can be compared throughout the day.

### 3.3 Peak-window analysis

A combined weekday + hour query identifies the five highest-volume timing windows.

These windows are useful for exploration, but a top-five ranking by itself does not prove that a recurring operational peak exists.

## 4. SQL Implementation

The project demonstrates practical T-SQL techniques including:

- `SET DATEFIRST`
- `DATENAME()`
- `DATEPART()`
- CTEs
- `GROUP BY`
- Chronological weekday sorting
- Hour-of-day aggregation
- Day + hour combination analysis
- `TOP 5` ranking
- Revenue aggregation
- SQL Server / T-SQL

See [query.sql](./query.sql) for the implementation.

## 5. Validation

The analysis includes several useful validation checks:

- The weekday output contains **7 groups**, one for each day of the week.
- The weekday order is chronologically sorted using `weekday_sort_key`, not alphabetically by the displayed name.
- The weekday order counts sum to **4,260 delivered orders**.
- The hourly output contains **14 represented hours**, from hour 8 through hour 21.
- The hourly order counts also sum to **4,260**, matching the weekday-level delivered-order population.
- The peak-window output contains exactly **5** combinations.
- The analysis consistently filters orders to `order_status = 'delivered'`.

The dataset therefore supports a consistent comparison of the same delivered-order population across the weekday and hourly views.

## 6. Observed Findings

### Day of week

Delivered order counts range from **574 on Tuesday** to **612 on Wednesday**.

The difference between the highest and lowest weekday volume is approximately **6.6% relative to the lowest day**, indicating a fairly even distribution rather than a dominant weekly peak.

Wednesday has the highest order count at **612**, while Tuesday has the lowest at **574**.

### Hour of day

Order counts are also relatively distributed across the represented hours. The highest hourly volume is **337 orders at 14:00**, while the lowest is **270 at 11:00**.

### Combined timing windows

The top five weekday-hour combinations are:

| Weekday | Hour | Orders |
|---|---:|---:|
| Friday | 17:00 | 58 |
| Friday | 14:00 | 57 |
| Wednesday | 14:00 | 57 |
| Saturday | 18:00 | 56 |
| Friday | 16:00 | 55 |

Although Friday at 17:00 is the largest individual window, the relatively small differences between the top combinations do not establish a strong recurring peak by themselves.

## 7. Business Implication

The current dataset does not show a strong day-of-week or hour-of-day concentration in delivered order volume.

Therefore, the analysis does **not** provide strong evidence for major staffing or promotional changes based solely on purchase timing.

The more important analytical lesson is that operational timing decisions should be based on persistent patterns rather than a single top-five ranking. In production, the same analysis should be repeated across longer periods and segmented by store, channel, customer type, and season.

The SQL design is ready for that extension because it separates readable weekday labels from deterministic sort keys and explicitly controls the time dimensions.

## 8. Recommendations

### Business operations

- Avoid major staffing or promotional changes based solely on the current timing results.
- Monitor timing patterns continuously when production transaction data becomes available.
- If a persistent peak emerges, align staffing, fulfillment capacity, and promotional scheduling with the observed demand window.

### Analytical next steps

- Compare timing patterns across stores and channels.
- Separate weekdays from weekends.
- Analyze timing by customer segment and category.
- Compare peak windows across months and seasons.
- Calculate each hour/day-hour combination as a share of total orders rather than relying only on raw counts.
- Add confidence intervals or repeated-period comparisons to distinguish recurring patterns from random variation.
- Investigate whether revenue peaks follow the same pattern as order volume.

## 9. Limitations

- The current analysis is descriptive and does not test statistical significance of timing differences.
- It covers the available dataset rather than a validated production observation window.
- The analysis uses delivered orders and therefore does not represent cancelled or other order statuses.
- The hourly output covers only hours represented in the data; absent hours are not explicitly generated as zero-volume rows.
- No seasonal, monthly, holiday, store, channel, customer-segment, or category controls are included.
- The top-five peak windows may reflect random variation when the underlying distribution is relatively flat.
- Timing patterns from a synthetic/practice dataset should not be presented as real consumer behavior.

## 10. Reproducibility

1. Complete the database setup described in [datasets/README.md](../datasets/README.md).
2. Select the `RetailAnalytics` database in SQL Server.
3. Run [query.sql](./query.sql).
4. Compare the three result sets with [sample_output.csv](./sample_output.csv).

The query is written for **SQL Server / T-SQL**.

## 11. Portfolio Skills Demonstrated

- Retail customer behavior analysis
- Purchase timing analysis
- Operational demand analysis
- SQL Server / T-SQL
- Date and time functions
- Deterministic weekday sorting
- CTEs and aggregation
- Peak-window identification
- Data validation
- Translating descriptive patterns into operational recommendations
- Recognizing when apparent peaks are not strong enough to support a business decision

## 12. Project Files

| File | Purpose |
|---|---|
| [query.sql](./query.sql) | Day-of-week, hour-of-day, and peak-window analysis |
| [sample_output.csv](./sample_output.csv) | Full output for all three timing analyses |