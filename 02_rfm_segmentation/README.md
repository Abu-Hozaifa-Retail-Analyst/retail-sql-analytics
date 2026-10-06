# RFM Customer Segmentation

## 1. Business Question
**Which customers are most valuable to protect, which are showing signs of declining engagement, and where should retention effort be prioritized?**

RFM segmentation combines **Recency, Frequency, and Monetary value** to move from a single customer average to actionable customer groups.

---

## 2. Dataset & Analytical Grain
The analysis uses the SQL Server retail dataset documented in [`datasets/README.md`](../datasets/README.md).

Key tables:
- `customers` — customer identity
- `orders` — order dates and status
- `payments` — order payment value

### Customer identity

The dataset contains `customer_id` (order-level customer record) and `customer_unique_id` (person-level customer identifier). The RFM analysis uses **`customer_unique_id` as the customer grain**.

### Metric scope
- **Recency:** days since the customer's most recent order, measured against the latest order timestamp in the dataset.
- **Frequency:** count of delivered orders.
- **Monetary:** total payment value associated with delivered orders.

Because the dataset is a historical snapshot, the latest order timestamp is treated as the analysis reference date rather than the actual current date.

---

## 3. Methodology
The SQL implementation builds the segmentation through six CTE stages:

1. **Recency calculation** — identify each customer's latest order and calculate days since that order.
2. **Frequency calculation** — count delivered orders per customer.
3. **Monetary calculation** — sum payment value for delivered orders.
4. **RFM base** — combine the three customer-level measures.
5. **RFM scoring** — use `NTILE(5)` to assign 1–5 scores.
6. **Segment mapping** — combine recency with the average of frequency and monetary scores to map customers into a 3×3, nine-segment RFM grid.

### Score direction
- lower `recency_days` = more recent = better
- higher frequency = better
- higher monetary value = better

Therefore, the SQL orders the recency `NTILE()` in the opposite direction from frequency and monetary scoring.

---

## 4. SQL Implementation
Primary analytical query: [`query.sql`](./query.sql)

Reusable customer-level view: [`vw_CustomerRFM.sql`](./vw_CustomerRFM.sql)

The view allows downstream SQL or BI work to query the segmentation as a reusable dataset instead of repeating the full CTE logic.

```sql
SELECT * FROM dbo.vw_CustomerRFM;

SELECT rfm_segment, COUNT(*) AS customer_count
FROM dbo.vw_CustomerRFM
GROUP BY rfm_segment
ORDER BY customer_count DESC;
```

---

## 5. Validation
Before using the segments for customer targeting, validate:

- Recency is based on each customer's latest order.
- Frequency counts only the intended order statuses.
- Monetary value uses the same delivered-order scope as frequency.
- Customer-level aggregation is performed at `customer_unique_id`.
- Each RFM score is on the intended 1–5 scale.
- Lower recency days receive better recency scores.
- Higher frequency and monetary values receive better scores.
- The final mapping covers all nine High/Mid/Low combinations.

The supplied [`sample_output.csv`](./sample_output.csv) contains all nine segments. Its displayed customer shares sum to approximately 100%, subject to one-decimal rounding.

---

## 6. Observed Findings
The supplied project output shows a clear concentration of value in several segments:

| Segment | Customers | Customer Share | Avg. Spend |
|---|---:|---:|---:|
| Lost | 812 | 28.5% | $301.42 |
| Champions | 474 | 16.7% | $1,688.59 |
| Potential Loyalists | 377 | 13.3% | $383.81 |
| New Customers | 287 | 10.1% | $106.29 |
| Promising | 235 | 8.3% | $161.36 |
| About to Sleep | 185 | 6.5% | $1,256.99 |
| Need Attention | 174 | 6.1% | $743.43 |
| Loyal Customers | 160 | 5.6% | $1,629.11 |
| At Risk | 141 | 5.0% | $1,540.34 |

The most important pattern is the value of customers classified as **About to Sleep**. Their average spend is **$1,256.99**, substantially above Lost customers at **$301.42**, and close to the Loyal and Champions segments.

---

## 7. Business Implication
The segmentation indicates that **customer count and customer value are not the same thing**.

The Lost segment is the largest segment by customer count at 28.5%, but its average spend is much lower than the high-value segments.

Conversely, the smaller **About to Sleep** segment represents customers whose historical monetary value is high despite weaker recency. That makes this group particularly relevant for retention prioritization.

This is a **descriptive segmentation**, not proof that a campaign will recover revenue. The segments identify where a test may be valuable; campaign effectiveness still needs to be measured.

---

## 8. Recommendations
1. **Prioritize high-value disengaging customers** — test a targeted win-back strategy for **About to Sleep** customers before they progress into lower-value inactive states.
2. **Protect Champions** — use differentiated retention treatment for Champions rather than applying the same offer to every customer.
3. **Avoid treating Lost as one homogeneous opportunity** — compare expected recovery value and campaign cost before allocating the same retention budget to the entire segment.
4. **Combine RFM with other behavioral signals** — use cohort retention, purchase timing, product/category behavior, and churn indicators to determine whether segment membership translates into actionable behavior.

---

## 9. Limitations
- **Relative scoring:** `NTILE(5)` creates relative customer rankings; a score of 5 means top quintile of this dataset, not a universal business threshold.
- **Reference date:** recency is measured against the latest timestamp in the dataset, not today's date.
- **Status scope:** frequency and monetary use delivered orders, while recency currently considers orders without the same explicit status filter. This should be reviewed before production use.
- **F&M simplification:** frequency and monetary scores are averaged into one value signal, which can hide high-frequency/low-spend versus low-frequency/high-spend differences.
- **Synthetic practice dataset:** results demonstrate analytical technique and business reasoning but should not be treated as representative of a production customer population.
- **Causal limitation:** segment membership does not prove why customers behave differently or whether a particular retention action will work.

---

## 10. Reproducibility
From the repository root:

1. Set up the SQL Server database using [`datasets/01_create_and_load.sql`](../datasets/01_create_and_load.sql).
2. Confirm the database is `RetailAnalytics`.
3. Execute [`query.sql`](./query.sql).
4. Review the nine-segment summary.
5. Optionally create [`vw_CustomerRFM.sql`](./vw_CustomerRFM.sql) for reusable customer-level segmentation.
6. Compare the resulting segment structure with [`sample_output.csv`](./sample_output.csv).

The dataset setup, file-path requirements, and database relationships are documented in [`datasets/README.md`](../datasets/README.md).

---

## 11. Portfolio Skills Demonstrated
| Skill | Application |
|---|---|
| SQL Server / T-SQL | Customer-level RFM analysis |
| CTEs | Multi-stage metric and segmentation pipeline |
| `NTILE()` | Relative quintile scoring |
| Window functions | Customer scoring and segment-share calculations |
| `CASE` logic | Business segmentation rules |
| Data modeling | Person-level customer grain |
| Reusable SQL | Customer RFM view |
| Data validation | Metric scope, scoring, and output checks |
| Retail analytics | Customer value and retention prioritization |
| Business reasoning | Segment-specific recommendations |

---

## 12. Project Files

```text
02_rfm_segmentation/
├── README.md
├── query.sql
├── vw_CustomerRFM.sql
└── sample_output.csv
```