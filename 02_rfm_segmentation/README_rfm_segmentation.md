# RFM Customer Segmentation

SQL Server project: which customers are most valuable and worth protecting, and which are showing signs of churn risk?

> The dataset is **synthetic** (generated to mirror the Olist e-commerce schema). Results show the method, not a real business.

## 1. Business problem

Which customers are most valuable and worth protecting, and which are showing early signs of churn risk? Rather than treating all customers the same, can retention spend be prioritized toward the segments where it will have the most impact? This builds on [Project 01](../01_cohort_retention), which found that most customers buy once and that retention halves after month 4.

## 2. Data

| Item | Value |
|---|---|
| Schema | Olist-style, synthetic (see `01_create_and_load.sql`) |
| Tables | `orders`, `customers`, `payments` |
| Orders | 4,421 (4,160 delivered, 139 canceled, 122 shipped) |
| Customer IDs vs people | 4,421 `customer_id` values belong to 3,000 real people (`customer_unique_id`) |
| Period | Jan 2023 - Dec 2024 |
| Customers scored | 2,845 (the 155 customers with no delivered order are not scored) |

`customer_id` is created per order, so everything groups by `customer_unique_id` (the person).

## 3. Methodology

| Metric | Definition |
|---|---|
| Recency (R) | days between the customer's last **delivered** order and the latest order in the data |
| Frequency (F) | number of delivered orders |
| Monetary (M) | total paid on delivered orders |

All three use delivered orders only, so they describe the same set of orders.

**Scoring (1 = worst, 5 = best)**

- Recency and Monetary: `NTILE(5)` quintiles. `customer_unique_id` breaks ties, so every run gives the same result.
- Frequency: **fixed rules** (1 order = 1, 2 orders = 3, 3+ orders = 5). About 80% of scored customers have exactly 1 order. `NTILE` would give those identical customers different scores (569 / 569 / 569 / 564 customers across scores 1 to 4, see check V5), and the segments would then depend on arbitrary row order.

**Segments:** the Recency bucket (High = score 4-5, Mid = 3, Low = 1-2) and the F&M bucket (average of the F and M scores: High = 4 or more, Mid = 3 to 4, Low = under 3) map to the classic 3 x 3 grid:

| | F&M High | F&M Mid | F&M Low |
|---|---|---|---|
| **Recency High** | Champions | Potential Loyalists | New Customers |
| **Recency Mid** | Loyal Customers | Need Attention | Promising |
| **Recency Low** | At Risk | About to Sleep | Lost |

## 4. SQL

- [`query.sql`](./query.sql): the full analysis (CTEs `data_end`, `recency`, `frequency`, `monetary`, `rfm_base`, `rfm_scores`, `rfm_buckets`, `rfm_segments`) with validation checks V1 to V5
- [`vw_CustomerRFM.sql`](./vw_CustomerRFM.sql): the same logic as a reusable view, so any query or BI tool can treat segments as a table
- [`usp_RefreshRFMSnapshot.sql`](./usp_RefreshRFMSnapshot.sql): a snapshot table and a procedure that refreshes it from the view

```sql
SELECT * FROM dbo.vw_CustomerRFM;

SELECT rfm_segment, COUNT(*) AS customer_count
FROM dbo.vw_CustomerRFM
GROUP BY rfm_segment
ORDER BY customer_count DESC;

EXEC dbo.usp_RefreshRFMSnapshot;
```

## 5. Validation

| Check | Result |
|---|---|
| V1: segment customers equal customers with a delivered order | 2,845 = 2,845 |
| V2: segment revenue equals delivered payments | 2,098,009.12 = 2,098,009.12 |
| V3: `pct_of_customers` and `pct_of_revenue` add up to 100 | 100.0 and 100.0 |
| V4: customer IDs vs real people | 4,421 vs 3,000 |
| V5: `NTILE` on order_count spreads one-order customers across scores | 569 / 569 / 569 / 564 |
| Tie-break flipped (ascending vs descending customer_unique_id) | at most 1 customer changes segment per segment, average spend moves by under $9 |

## 6. Finding

| rfm_segment | customer_count | pct_of_customers | avg_spent | pct_of_revenue | avg_orders | avg_recency_days |
|---|---|---|---|---|---|---|
| Lost | 896 | 31.5 | 346.64 | 14.8 | 1.01 | 526 |
| New Customers | 770 | 27.1 | 345.50 | 12.7 | 1.02 | 86 |
| Promising | 390 | 13.7 | 345.06 | 6.4 | 1.02 | 282 |
| Champions | 196 | 6.9 | 2,484.91 | 23.2 | 4.35 | 77 |
| Potential Loyalists | 172 | 6.0 | 1,278.80 | 10.5 | 1.37 | 83 |
| About to Sleep | 149 | 5.2 | 1,337.88 | 9.5 | 1.34 | 526 |
| Loyal Customers | 99 | 3.5 | 2,037.19 | 9.6 | 3.54 | 285 |
| At Risk | 93 | 3.3 | 1,984.68 | 8.8 | 3.38 | 473 |
| Need Attention | 80 | 2.8 | 1,177.77 | 4.5 | 1.49 | 294 |

- **Champions** are 6.9% of customers and bring 23.2% of revenue. Champions, Loyal Customers and At Risk together (13.6% of customers) bring 41.6%.
- **At Risk** (93 customers) are repeat buyers (3.4 orders, $1,985 average) who last ordered about 473 days ago. **About to Sleep** (149) are mostly single-order big spenders ($1,338 average) who last ordered about 526 days ago. Together they are 8.5% of customers and 18.3% of revenue.
- **New Customers, Promising and Lost** are 72% of customers with about 1 order each, and 34% of revenue.

## 7. Business meaning

- Revenue is concentrated: a small group of repeat buyers carries over 40% of it.
- About 18% of past revenue sits with valuable customers who have gone quiet for 15 to 17 months on average.
- Most customers are one-time buyers, which matches Project 01.

## 8. Recommendation

1. **Protect the Champions** (196 customers, 23% of revenue): early access and loyalty rewards.
2. **Win back At Risk customers first** (93 repeat buyers, $185K): they have proven they come back, so test a personal win-back offer.
3. **Convert New Customers inside the repurchase window** (770 customers, about 86 days since their only order): Project 01 shows the window is months 1 to 4, so nudge a second order now.
4. **Keep Lost customers cheap** (896 customers, $347 each): low-cost email only.

## Limitations

- Synthetic data: the numbers illustrate the method.
- Scores are relative: a 5 means the top 20% of this dataset.
- Frequency cut-offs (1, 2, 3+) are a judgement call, and quintile boundaries can split tied recency or spend values (this is why a deterministic tie-break is used).
- The 155 customers with no delivered order are not scored.
- Recency is measured against the latest order in the data, so results shift if data is added.

## Sample output

Full output: [`sample_output.csv`](./sample_output.csv)

## Author

**Abu Hozaifa** | [LinkedIn](https://www.linkedin.com/in/abu-hozaifa-retail-analyst)
