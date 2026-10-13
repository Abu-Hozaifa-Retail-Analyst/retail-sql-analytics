# Churn Risk Detection

SQL Server project: when is a customer overdue relative to their own buying pattern, and at what overdue ratio is it still worth trying to save them?

> The dataset is **synthetic**. Results show the method, not a real business.

## 1. Business problem

Which customers show a purchase gap that is meaningfully longer than their own historical pattern, an early warning sign of churn? The decision is when to start a retention action, while customers can still be saved. The catch: a rule only helps if it fires early, so is a 2x overdue flag early, or already too late?

## 2. Data

| Item | Value |
|---|---|
| Tables | `orders`, `customers` (delivered orders only) |
| Customers with delivered orders | 2,845 |
| Repeat customers (2+ delivered orders) | 574 |
| Median gap between orders | 52 days |
| Backtest | 17 month-end snapshots (2023-04-30 to 2024-08-31), 4,059 customer-snapshots |

One-time buyers have no gap, so they are not part of this analysis. Customers are identified with `customer_unique_id` (the person), not `customer_id` (the order).

## 3. Methodology

- **Own gap:** the average number of days between a customer's delivered orders.
- **Overdue ratio:** days since the last order / the customer's own average gap.
- **Action bands:** On schedule (under 1x), Early warning (1 to 2x), Slipping (2 to 5x), Likely lost (5x and above).
- **Backtest:** at each month-end snapshot, use only the orders known up to that day, compute each repeat customer's overdue ratio, then check whether they ordered again in the next 90 days. Snapshots end early enough that every 90-day window lies inside the data.

## 4. SQL

[`query.sql`](./query.sql) contains:

- **Query 1a:** overdue status of every repeat customer (not only those above 2x)
- **Query 1b:** customers per action band right now
- **Query 2:** the backtest (recursive date spine, `LAG`, `EXISTS`, temp table), summarized by overdue band (2a) and by threshold (2b)
- **Validation checks V1 to V5**

## 5. Validation

| Check | Result |
|---|---|
| Repeat customers: Query 1a = Query 1b | 574 = 574, pass |
| Customers above 2x equal the original single-threshold query | 381 = 381, pass |
| Backtest vs an independent calculation | 4,059 of 4,059 customer-snapshots match, pass |
| Zero-day gaps (divide-by-zero guard) | 0, pass |
| Every outcome window inside the data | last window ends 2024-11-30, data ends 2024-12-27, pass |

**Correction to the first write-up:** it said flagged customers were overdue by an average of 31.5x and that 15 of 19 flagged customers were 20x or more. The query actually flags 381 customers, and only the top 19 were in the sample output. Across all 381 the average is 7.7x (median 5.7x), and 15 of 381 (4%) are 20x or more.

## 6. Finding

**Right now (repeat customers by action band):**

| action_band | customers | pct_of_repeat_customers | avg_overdue_ratio |
|---|---|---|---|
| On schedule | 126 | 22.0 | 0.4 |
| Early warning | 67 | 11.7 | 1.4 |
| Slipping | 171 | 29.8 | 3.3 |
| Likely lost | 210 | 36.6 | 11.2 |

The original 2x rule flags 381 of 574 repeat customers (66%), and 210 of them (55%) are already 5x or more overdue.

**Backtest: share who ordered again within 90 days, by overdue ratio at the snapshot:**

| overdue_band | customer_snapshots | returned | return_rate_pct |
|---|---|---|---|
| 0 to 1x | 1,549 | 784 | 50.6 |
| 1 to 1.5x | 441 | 138 | 31.3 |
| 1.5 to 2x | 324 | 59 | 18.2 |
| 2 to 3x | 455 | 42 | 9.2 |
| 3 to 5x | 563 | 16 | 2.8 |
| 5x and above | 727 | 7 | 1.0 |

Return odds roughly halve with each step. The savable window is about 1 to 2x.

**What each threshold would catch:**

| threshold | flagged snapshots | pct of snapshots flagged | pct not returning | pct of non-returners caught |
|---|---|---|---|---|
| 1.0x | 2,510 | 61.8 | 89.6 | 74.6 |
| 1.5x | 2,069 | 51.0 | 94.0 | 64.6 |
| 2.0x | 1,745 | 43.0 | 96.3 | 55.8 |
| 3.0x | 1,290 | 31.8 | 98.2 | 42.1 |
| 5.0x | 727 | 17.9 | 99.0 | 23.9 |

## 7. Business meaning

- **2x is already late:** of snapshots flagged at 2x or more, only 3.7% ordered again within 90 days.
- **The savable window is 1 to 2x:** between 1x and 2x, 18% to 31% still return. Only 67 customers are in that window now.
- **A lower trigger catches more:** at 1.5x the rule catches 64.6% of customers who do not return, versus 55.8% at 2x. At 1x it catches 74.6% but flags 62% of all snapshots.

## 8. Recommendation

1. **Act on the 67 early-warning customers now.** Query 1a lists them with their last order date.
2. **Tier the triggers:** 1x a light reminder, 1.5x an offer, 3x and above stop and hand over to a win-back program.
3. **Test, don't assume.** Customers at 1 to 1.5x return 31% without help. Use a holdout group to measure the extra return a message creates.
4. **Treat the 210 likely-lost customers as a win-back group** with about a 1% chance of returning on their own.

## Limitations

- Synthetic data.
- The outcome is a 90-day return. A longer window changes the rates.
- One customer appears in up to 17 snapshots, so rows are not independent samples.
- The median repeat customer has 3 orders, so their own average gap is a noisy estimate.
- The overdue ratio ignores seasonality.

## Sample output

- [`sample_output.csv`](./sample_output.csv): Query 1a, all 574 repeat customers
- [`sample_output_backtest.csv`](./sample_output_backtest.csv): Query 2a
- [`sample_output_thresholds.csv`](./sample_output_thresholds.csv): Query 2b

## Author

**Abu Hozaifa** | [LinkedIn](https://www.linkedin.com/in/abu-hozaifa-retail-analyst)
