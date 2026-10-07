# Correlation Analysis — Frequency, Order Value & Freight

## 1. Business Question

Is there a linear relationship between how often a customer orders and how much they spend per order? As a secondary check, does higher line-item price appear to be associated with higher freight cost?

The project uses Pearson correlation to quantify the strength and direction of these linear relationships.

## 2. Dataset & Analytical Grain

The analysis uses the repository's SQL Server retail dataset.

### Primary analysis

- **Analytical grain:** one row per `customer_unique_id`
- **Frequency metric:** delivered order count
- **Spend metric:** delivered payment value divided by delivered order count
- **Customers analyzed:** **2,845**

`customer_unique_id` is used for the customer-level analysis because it represents the person across order records.

### Secondary analysis

- **Analytical grain:** one row per `order_items` line item
- **Variable 1:** `price`
- **Variable 2:** `freight_value`
- **Line items analyzed:** **7,624**

Both analyses use the exact metrics defined in the SQL query; no additional filtering or transformation is applied beyond the documented delivered-order scope for the primary analysis.

## 3. Methodology

SQL Server does not provide a built-in `CORR()` function in this implementation, so the Pearson correlation coefficient is calculated manually from its underlying components.

For the primary analysis:

1. Build per-customer delivered-order metrics.
2. Calculate `order_count` and `avg_order_value`.
3. Aggregate the six components required for Pearson correlation: `n`, `Σx`, `Σy`, `Σxy`, `Σx²`, and `Σy²`.
4. Apply the Pearson formula.
5. Use `NULLIF()` to protect the denominator from a zero-variance edge case.

The secondary analysis applies the same mathematical approach directly to line-item `price` and `freight_value`.

Pearson's `r` ranges from **-1 to +1**:

- Values near **+1** indicate a strong positive linear relationship.
- Values near **-1** indicate a strong negative linear relationship.
- Values near **0** indicate little or no linear relationship.

genui{"learning_viz":{"type_id":"CORRELATION","initial_values":{"pattern":"positive"}}}

## 4. SQL Implementation

The project demonstrates practical T-SQL techniques including:

- CTEs
- Customer-level aggregation
- `COUNT()` and `SUM()`
- Derived metrics
- `POWER()`
- `SQRT()`
- `NULLIF()`
- Manual Pearson correlation
- Separate analytical grains for customer and line-item analysis
- SQL Server / T-SQL

See [query.sql](./query.sql) for the implementation.

## 5. Validation

The output was checked against the underlying dataset counts:

- Primary analysis: **2,845 customers analyzed**.
- Secondary analysis: **7,624 line items analyzed**.
- The primary query restricts the order population to `order_status = 'delivered'`.
- `avg_order_value` is calculated as total delivered payment value divided by delivered order count.
- The denominator is protected with `NULLIF(..., 0)`.
- The correlation results are rounded to three decimal places.

A key methodological validation is that the primary analysis uses `customer_unique_id`, rather than treating each `customer_id` order record as a separate person.

## 6. Observed Findings

### Order frequency vs. average order value

The Pearson correlation is **r = 0.013** across **2,845 customers**.

This is extremely close to zero, indicating **essentially no linear relationship** between order frequency and average order value in this dataset.

In practical terms, frequent customers do not systematically show higher or lower average order values based on this measure.

### Price vs. freight

The Pearson correlation is **r = 0.003** across **7,624 line items**.

This is also effectively zero, indicating no meaningful linear relationship between line-item price and freight value in the available data.

These are valid analytical results even though they are weak or null relationships. A good analyst should not manufacture a relationship when the data does not show one.

## 7. Business Implication

The frequency/value result suggests that **purchase frequency and average order value can be treated as separate customer-management dimensions** in this dataset.

For example, a frequency-focused initiative could target reorder behavior or loyalty engagement, while an order-value initiative could focus on upselling, cross-selling, or bundling. The correlation result alone does not prove that either initiative will work; it only indicates that the two observed customer metrics are not moving together linearly.

The price/freight result is primarily a diagnostic signal. It suggests that freight in this dataset is not simply increasing with item price. Before applying that conclusion operationally, the underlying freight-pricing logic should be validated against the actual shipping model.

## 8. Recommendations

### Business analysis

- Treat customer frequency and average order value as separate segmentation dimensions.
- Combine them with RFM, category mix, customer tenure, and margin where available.
- Use targeted experiments to test whether frequency-focused and basket-value-focused initiatives produce incremental impact.
- Investigate freight pricing separately from product price rather than assuming a direct relationship.

### Analytical next steps

- Segment the correlation by customer cohort, category, geography, or channel to identify relationships that may be hidden in the overall population.
- Inspect scatter plots and distributions before relying on a single correlation coefficient.
- Test Spearman correlation if the relationship may be monotonic but not linear.
- Assess statistical significance and confidence intervals when the analysis is used for formal decision-making.
- Investigate nonlinear relationships and outliers before concluding that two variables are completely unrelated.

## 9. Limitations

- Pearson correlation measures **linear association**, not causation.
- A near-zero Pearson correlation does not prove that no relationship of any kind exists.
- The analysis does not calculate a p-value, confidence interval, or statistical power assessment.
- The primary analysis uses delivered orders only; the secondary line-item analysis does not apply an order-status filter.
- Customer frequency and average order value may have nonlinear or segment-specific relationships that a single overall `r` can hide.
- Correlation can be influenced by outliers and distribution shape.
- The freight analysis does not model weight, distance, destination, shipping method, or other operational drivers.
- The dataset is a practice/synthetic retail dataset, so these relationships should not be presented as real-world market behavior.

## 10. Reproducibility

1. Complete the database setup described in [datasets/README.md](../datasets/README.md).
2. Select the `RetailAnalytics` database in SQL Server.
3. Run [query.sql](./query.sql).
4. Compare the two result sets with [sample_output.csv](./sample_output.csv).

The query is written for **SQL Server / T-SQL**.

## 11. Portfolio Skills Demonstrated

- Retail customer analytics
- Relationship analysis
- Pearson correlation
- Manual statistical implementation in SQL
- Customer-level analytical grain
- Line-item analytical grain
- SQL Server / T-SQL
- Metric validation
- Interpreting null/weak relationships
- Avoiding correlation-versus-causation errors

## 12. Project Files

| File | Purpose |
|---|---|
| [query.sql](./query.sql) | Primary and secondary Pearson correlation calculations |
| [sample_output.csv](./sample_output.csv) | Correlation results for both analyses |