# Churn Risk Detection

## 1. Business Question

Which customers have gone materially longer without purchasing than their own historical ordering pattern would suggest?

The analysis uses each customer's historical purchase gap to identify customers whose current inactivity exceeds **2× their average historical gap**.

## 2. Dataset & Analytical Grain

The analysis uses the repository's SQL Server retail dataset.

- **Customer grain:** customer_unique_id
- **Order grain:** order_id
- **Historical gap grain:** consecutive delivered orders for the same customer
- **Source tables:** orders and customers
- **Order-status scope for historical gaps and last order:** delivered
- **Snapshot date:** the maximum order_purchase_timestamp available in orders, used by the query as the analysis reference date

Customers with only one delivered order are excluded from the historical-gap calculation because they do not have a repeat-purchase interval from which to establish an individual ordering pattern.

## 3. Methodology

The SQL workflow is:

1. **Build consecutive-order history** with LAG() partitioned by customer_unique_id and ordered by purchase timestamp.
2. **Calculate the gap in days** between each delivered order and the customer's previous delivered order.
3. **Calculate each customer's average historical gap**. This naturally requires at least two delivered orders.
4. **Identify each customer's most recent delivered order**.
5. **Calculate days since the last delivered order** using the dataset's maximum order timestamp as the reference date.
6. **Calculate overdue_ratio:** days_since_last_order / avg_gap_days.
7. **Flag customers where the current gap is greater than 2× their historical average gap**.

This relative threshold is designed to account for different natural purchasing rhythms. A customer who normally buys every 10 days should not be evaluated using the same absolute inactivity threshold as a customer who normally buys every 60 days.

## 4. SQL Implementation

The project demonstrates practical T-SQL techniques including:

- LAG() window functions
- PARTITION BY
- ORDER BY within window functions
- DATEDIFF()
- CTE-based query organization
- Customer-level aggregation with AVG() and MAX()
- Scalar subqueries
- Relative threshold logic
- Derived risk metrics

See [query.sql](./query.sql) for the implementation.

## 5. Validation

The query design includes several useful controls:

- Historical gaps are calculated only between consecutive delivered orders.
- LAG() is partitioned by customer_unique_id, keeping each customer's purchase history separate.
- Customers without a previous delivered order do not contribute an artificial gap.
- Customers with only one delivered order are excluded from the average-gap calculation.
- The final filter requires the current inactivity period to exceed **2×** the customer's historical average gap.
- The checked sample output contains 19 flagged customers.

### Scope check

There is an important implementation detail to review before production use:

The historical-gap and last-order CTEs filter to order_status = 'delivered', but the reference date in the final calculation is:

    (SELECT MAX(order_purchase_timestamp) FROM orders)

That subquery does **not** explicitly filter to delivered orders. Therefore, the reference date may reflect a non-delivered order if one exists at the dataset maximum timestamp. The current README documents the behavior rather than silently changing the underlying query or sample results.

## 6. Observed Findings

The current analysis identifies **19 customers** whose inactivity exceeds twice their own average historical ordering gap.

The documented sample-level result reports an average overdue ratio of **31.5×**. **15 of the 19 flagged customers are at least 20× beyond their normal ordering cycle.**

The most extreme sample rows show overdue ratios of 82.1×, 77.4×, and 60.3×.

These values indicate that the current 2× threshold is identifying customers who are, in many cases, far beyond their normal purchase cycle rather than customers who are only slightly overdue.

## 7. Business Implication

The result suggests that the current 2× threshold may be better interpreted as a **late-stage churn/win-back signal** for this dataset than as an early-warning indicator.

A customer who is already 20× beyond their normal ordering interval is very different from a customer who has only recently exceeded their expected purchase cycle. Treating both groups as one generic "churn-risk" population could lead to poorly timed retention activity.

The analysis therefore supports separating customers by **degree of overdue behavior**, while treating the exact thresholds as business hypotheses that require validation.

## 8. Recommendations

### Immediate business actions to test

- Introduce an **earlier intervention band**, such as customers around 1.5–2× their normal ordering gap.
- Create a separate **win-back/reactivation segment** for customers with extremely high overdue ratios.
- Prioritize high-value overdue customers by combining the churn signal with the RFM segments from Project 02.
- Test different retention treatments by customer value and overdue severity rather than using one message for everyone.

### Analytical next steps

- Backtest multiple thresholds (for example, 1.5×, 2×, 3×) to determine which threshold provides useful lead time.
- Measure whether flagged customers actually become inactive after the warning point.
- Add customer monetary value, order frequency, product category, and channel where available.
- Evaluate retention campaign outcomes using a controlled test rather than assuming the churn flag itself causes improvement.

## 9. Limitations

- The current 2× threshold is a rule-based heuristic, not a statistically validated churn model.
- The query identifies customers with unusually long purchase gaps; it does not directly prove that a customer has permanently churned.
- Customers with only one delivered order cannot establish an individual historical ordering pattern and are excluded.
- The reference date uses the maximum timestamp across **all** orders, while the historical and last-order calculations use delivered orders; this scope mismatch should be resolved before production use.
- The analysis does not explicitly account for seasonality, promotions, holidays, product lifecycle, or channel-specific buying patterns.
- Average historical gaps can be affected by irregular purchase behavior and may not represent a stable customer cadence.
- The dataset is a practice/synthetic retail dataset, so the observed churn behavior should not be presented as real-world customer behavior.

## 10. Reproducibility

1. Complete the database setup described in [datasets/README.md](../datasets/README.md).
2. Select the RetailAnalytics database in SQL Server.
3. Run [query.sql](./query.sql).
4. Compare the result with [sample_output.csv](./sample_output.csv).

The query is written for **SQL Server / T-SQL**.

## 11. Portfolio Skills Demonstrated

- Retail customer churn-risk analysis
- Customer lifecycle thinking
- SQL Server / T-SQL
- Window functions with LAG()
- Customer-level behavioral analysis
- Relative-threshold design
- Data-grain awareness
- Validation and scope checking
- Business segmentation
- Retention and win-back strategy thinking

## 12. Project Files

| File | Purpose |
|---|---|
| [query.sql](./query.sql) | Main churn-risk detection SQL analysis |
| [sample_output.csv](./sample_output.csv) | Sample output containing flagged customers and overdue metrics |