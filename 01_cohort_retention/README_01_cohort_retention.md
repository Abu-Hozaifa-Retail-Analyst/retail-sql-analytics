# Customer Cohort Retention Analysis

SQL Server project: is growth coming from repeat customers, or from new one-time buyers?

## 1. Business problem

Of customers who made their first purchase in a given month, what percentage are still buying 1, 2, 3+ months later? Is the business retaining customers, or is growth entirely dependent on acquiring new one-time buyers?

## 2. Data

| Item | Value |
|---|---|
| Schema | Olist-style e-commerce: `orders` and `customers` |
| Used from `orders` | `customer_id`, `order_purchase_timestamp` |
| Used from `customers` | `customer_id`, `customer_unique_id` |
| Customers (real people) | 3,000 |
| Monthly cohorts | 24 (Jan 2023 - Dec 2024) |
| Cohort size | 77 to 212 customers |

> Data source: [add one line: synthetic practice data / public Olist sample / other]

**Data-modeling trap:** in this schema `customer_id` is assigned per *order*, while `customer_unique_id` identifies the actual person. Grouping by `customer_id` would make every customer look like a one-time buyer and inflate churn.

## 3. Methodology

- **Cohort:** the month of a customer's first purchase
- **Active:** at least one order in the month
- **Month offset:** `DATEDIFF(MONTH, ...)` from the first purchase month
- **Retention %:** active customers / cohort size (the month-0 count)

Steps: (1) first purchase month per real customer, (2) month offset of every order, (3) distinct active customers per cohort and offset, (4) divide by the cohort size.

## 4. SQL

- [`query.sql`](./query.sql): the full analysis using CTEs (`customer_first_purchase`, `customer_order_months`, `cohort_active_customers`, `cohort_sizes`)
- [`usp_CohortRetention.sql`](./usp_CohortRetention.sql): the same logic as a reusable stored procedure with optional `@start_date` / `@end_date`

```sql
EXEC dbo.usp_CohortRetention;                                    -- all cohorts
EXEC dbo.usp_CohortRetention @start_date = '2023-06-01';         -- from June 2023 onward
EXEC dbo.usp_CohortRetention @start_date = '2023-01-01',
                              @end_date   = '2023-06-30';        -- H1 2023 cohorts only
```

## 5. Validation

Checked on [`sample_output.csv`](./sample_output.csv) (248 rows):

| Check | Result |
|---|---|
| Month 0 is 100% in every cohort | 24 of 24 cohorts, pass |
| Retention % equals active / cohort size | 248 of 248 rows, pass |
| Active customers never exceed cohort size | 248 of 248 rows, pass |
| No duplicate (cohort, month) rows | 0 duplicates, pass |

`query.sql` also contains two data-model checks to run against the database: **V1** (cohort sizes must add up to the distinct real customers who ordered; 3,000 in the output) and **V2** (`customer_id` count vs `customer_unique_id` count, which shows the one-per-order trap).

## 6. Finding

| Month after first purchase | 1 | 2 | 3 | 4 | 5 | 6 | 12 |
|---|---|---|---|---|---|---|---|
| Average retention | 8.2% | 10.7% | 8.1% | 9.8% | 5.0% | 5.0% | 1.2% |

- Only **8.2%** of customers return in month 1 on average (range 2.3% to 13.7%). Most customers are one-time buyers.
- Retention holds between 8% and 11% for months 1 to 4, then **halves to 5.0% in month 5**. Month 5 is lower than month 4 in all 19 cohorts that reached it.
- Month 2 (10.7%) is higher than month 1 (8.2%) in **14 of 22 cohorts**. This hints at a reorder cycle, but a simple sign test gives p of about 0.29, so treat it as a hypothesis, not a proven pattern.

## 7. Business meaning

- Most customers buy once: about 8 in 100 return in month 1.
- Growth is acquisition-driven: the average cohort grew from 116 customers (2023) to 134 (2024), +16%, while month-1 retention stayed flat (8.2% vs 8.1%).
- The repurchase window is roughly months 1 to 4. After that, the chance of returning roughly halves.

## 8. Recommendation

1. **Focus retention effort on months 1 to 4** after a first purchase.
2. **Test the timing:** A/B test a win-back message at day 30 against day 45 to 60, since a month-1 campaign may reach customers before their reorder window opens.
3. **Confirm with day-level data:** measure the days between first and second order, because calendar-month buckets blur the window.
4. **Find the repeat buyers:** segment returning customers (RFM, see Project 2) to see who drives the long-tail retention.

## Limitations

- Months are calendar months (`DATEDIFF(MONTH)` counts month boundaries), not 30-day windows.
- A month with no returning customers has no row, so it is missing rather than shown as 0%.
- Later months only include older cohorts, so averages at month 12 rest on fewer cohorts than month 1.
- The month-2 pattern is suggestive, not statistically established.

## Sample output

| cohort_month | months_since_first_purchase | customers_active | cohort_size | retention_pct |
|---|---|---|---|---|
| 2023-01-01 | 0 | 90 | 90 | 100.0 |
| 2023-01-01 | 1 | 5 | 90 | 5.6 |
| 2023-01-01 | 2 | 11 | 90 | 12.2 |
| 2023-01-01 | 3 | 9 | 90 | 10.0 |

Full output: [`sample_output.csv`](./sample_output.csv)
