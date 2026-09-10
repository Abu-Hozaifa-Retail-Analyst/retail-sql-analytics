# Customer Cohort Retention Analysis

## Business Question
Of customers who made their first purchase in a given month, what percentage
are still buying 1, 2, 3+ months later? Is the business retaining customers,
or is growth entirely dependent on acquiring new one-time buyers?

## Approach
Built a cohort retention table in SQL Server using CTEs and window-style
aggregation:
1. Identify each customer's first purchase month (their "cohort")
2. Measure the month-offset of every subsequent order relative to that
   first purchase, using `DATEDIFF(MONTH, ...)`
3. Count distinct active customers per (cohort, month-offset) pair
4. Divide by each cohort's starting size to get a retention percentage

A key data-modeling detail handled here: this schema (mirroring Olist's
structure) assigns a new `customer_id` per *order*, while
`customer_unique_id` identifies the actual person. Grouping by the wrong
column would make every customer look like a one-time buyer — a common
trap in e-commerce schemas that inflates churn if missed.

See [`query.sql`](./query.sql) for the full implementation.

## Finding
Retention drops sharply immediately after the first purchase — across
cohorts, only **8.2% of customers on average return in month 1**, confirming
that most of the customer base is one-time buyers rather than repeat
purchasers. Retention doesn't decay monotonically, though: **month-2
retention averages 10.7%, higher than month 1**, in nearly every cohort
observed. This consistent "second-month bump" suggests a behavioral reorder
cycle rather than pure random decay — customers who don't return
immediately are more likely to return roughly 60 days out than 30 days out.

**So what:** A month-1 win-back campaign timed too early may be hitting
customers before their natural reorder window opens. Retargeting efforts
(email, remarketing, loyalty nudges) may perform better if timed around the
30-60 day mark rather than immediately post-purchase. This also flags a
small, consistent segment (~15% of customers, per the loyalty patterns in
this dataset) driving most of the long-tail retention — worth a follow-up
RFM segmentation to identify and prioritize them directly (see Project 2).

## Sample Output
| cohort_month | months_since_first_purchase | customers_active | cohort_size | retention_pct |
|---|---|---|---|---|
| 2023-01-01 | 0 | 90 | 90 | 100.0 |
| 2023-01-01 | 1 | 5 | 90 | 5.6 |
| 2023-01-01 | 2 | 11 | 90 | 12.2 |
| 2023-01-01 | 3 | 9 | 90 | 10.0 |

*(Full output in [`sample_output.csv`](./sample_output.csv))*
