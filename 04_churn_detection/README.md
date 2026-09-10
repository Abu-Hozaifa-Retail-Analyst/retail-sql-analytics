# Churn Risk Detection

## Business Question
Which currently-active customers show a purchase gap that's meaningfully
longer than their own historical pattern — an early warning sign of churn,
before they go fully silent?

## Approach
Built a churn-risk flag in SQL Server using `LAG()` to compare each
customer's current inactivity against their own historical ordering
rhythm, rather than a single fixed threshold applied to everyone:
1. Used `LAG(order_purchase_timestamp) OVER (PARTITION BY customer_unique_id
   ORDER BY order_purchase_timestamp)` to pull each customer's previous
   order date into the same row as their current order — no self-join
   required
2. Computed the day-gap between consecutive orders per customer, then
   averaged those gaps to get each customer's normal ordering rhythm
   (customers with only one order are naturally excluded — there's no
   "gap" to measure for a one-time buyer)
3. Measured days since each customer's most recent order against the
   dataset's own max date (the historical-snapshot pattern used in
   earlier projects)
4. Computed an `overdue_ratio` — days since last order ÷ average
   historical gap — so a customer who normally orders every 10 days and
   has gone quiet for 25 days is flagged more urgently than a customer
   who normally orders every 60 days and is at the same 25-day mark

See [`query.sql`](./query.sql) for the full implementation.

## Finding
Customers flagged as churn-risk are overdue by an average of **31.5x**
their normal ordering gap — meaning a customer who once ordered every 3
weeks hasn't purchased in nearly two years. The overdue ratios are so
extreme that these customers are no longer just early churn risks — they
appear to have already churned, with **15 of the 19 flagged customers at
least 20x beyond their normal ordering cycle**.

**So what:** The business should use a much earlier overdue threshold
(e.g. 1.5-2x, rather than letting ratios climb into the double digits) to
trigger retention actions while customers are still plausibly savable.
Customers already 20x+ overdue should be moved into a separate
win-back/reactivation program rather than treated as ordinary churn-risk
customers — they're functionally equivalent to the "Lost" segment
identified in the RFM analysis (Project 2), not customers who can still be
caught with a routine nudge.

## Sample Output
| customer_unique_id | last_order_date | avg_gap_days | days_since_last_order | overdue_ratio |
|---|---|---|---|---|
| CUST102997 | 2023-06-01 | 7.0 | 575 | 82.1 |
| CUST102762 | 2023-07-04 | 7.0 | 542 | 77.4 |
| CUST101560 | 2023-05-04 | 10.0 | 603 | 60.3 |
| CUST100032 | 2023-02-13 | 17.0 | 683 | 40.2 |
| CUST100939 | 2023-03-04 | 19.0 | 664 | 34.9 |

*(Full output in [`sample_output.csv`](./sample_output.csv))*
