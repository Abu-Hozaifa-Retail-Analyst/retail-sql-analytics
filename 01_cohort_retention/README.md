# Customer Cohort Retention Analysis

## 1. Business Question

**How well does the business retain customers after their first purchase?**

This analysis groups customers by the month of their first purchase and measures how many return in later months.

The business objective is to distinguish growth driven by **new customer acquisition** from growth supported by **repeat purchasing and retention**.

---

## 2. Dataset & Data Assumptions

The analysis uses the SQL Server retail dataset documented in [`datasets/README.md`](../datasets/README.md).

Key tables used:

- `customers` — customer records and person-level `customer_unique_id`
- `orders` — order timestamps and order status

### Important customer-identity rule

This Olist-style schema contains two customer identifiers:

- `customer_id` — associated with an individual order record
- `customer_unique_id` — identifies the actual customer across orders

For retention analysis, **`customer_unique_id` is the correct analytical grain**. Using `customer_id` would incorrectly make repeat purchasers appear to be new customers.

---

## 3. Methodology

The analysis is implemented as a sequence of CTEs:

1. **First purchase / cohort assignment** — find each customer's first purchase month.
2. **Purchase-month offset** — use `DATEDIFF(MONTH, ...)` to calculate how many months each order occurred after the customer's first purchase.
3. **Cohort activity** — count distinct customers at each cohort/month-offset combination.
4. **Cohort denominator** — use month 0 as the starting cohort size.
5. **Retention rate** — calculate `customers_active / cohort_size × 100`.

This produces a cohort retention table that can support retention reporting or a future heatmap visualization.

---

## 4. SQL Implementation

Primary query:

- [`query.sql`](./query.sql)

Reusable parameterized implementation:

- [`usp_CohortRetention.sql`](./usp_CohortRetention.sql)

The stored procedure accepts optional `@start_date` and `@end_date` parameters, making the analysis reusable for selected cohort windows.

Example:

```sql
EXEC dbo.usp_CohortRetention;

EXEC dbo.usp_CohortRetention
    @start_date = '2023-06-01',
    @end_date   = '2023-12-31';
```

---

## 5. Validation

The SQL logic should be validated at three levels before using the output for business decisions:

### Structural validation

- Every cohort should contain a month-0 row.
- Month-0 active customers should equal the cohort size.
- Month-0 retention should equal 100%.
- Retention should be calculated from distinct `customer_unique_id`, not order rows.
- Cohort and month-offset ordering should be chronological.

### Data-model validation

- Confirm `customer_unique_id` is the person-level identifier for this dataset.
- Confirm the customer-to-order joins do not create unintended duplicate customer/order relationships.
- Confirm the intended `order_status` population before using the result operationally.

### Reproducible output check

The included [`sample_output.csv`](./sample_output.csv) provides a reference output generated from the project query. The first cohort begins at 100.0% in month 0; subsequent rows show the observed return rate for that cohort at each month offset.

---

## 6. Observed Finding

The supplied sample output shows a **sharp decline after the first purchase**, with many cohorts returning only a small share of their original customers in later months.

Across the project summary, average month-1 retention is **8.2%**, while average month-2 retention is **10.7%**. The month-2 rate being higher than month 1 is an important pattern to investigate rather than assuming retention must decline monotonically.

For example, the January 2023 cohort moves from:

- Month 0: **100.0%**
- Month 1: **5.6%**
- Month 2: **12.2%**
- Month 3: **10.0%**

The result indicates that repeat purchasing is limited and that the timing of repeat purchases may not follow a simple one-month decay pattern.

---

## 7. Business Implication

The analysis suggests that **customer retention is an important business lever**, because a large proportion of customers do not appear in the immediate repeat-purchase months.

The month-2 rebound also means that a single fixed post-purchase timing assumption may not be appropriate for every customer.

This is a **descriptive finding, not proof of a causal reorder cycle**. The observed pattern should be tested against customer segment, product category, purchase frequency, and promotional behavior before changing campaign timing.

---

## 8. Recommendation

Potential business actions:

1. **Measure retention by customer segment** — combine cohort analysis with the RFM segmentation in Project 2.
2. **Test win-back timing** — compare customer reactivation at different post-purchase intervals instead of assuming month 1 is always optimal.
3. **Prioritize valuable repeat customers** — use RFM to distinguish high-value customers from low-value one-time buyers.
4. **Build retention monitoring** — track cohort retention by acquisition month and customer segment in a recurring BI report.

The appropriate next step is **testing**, not assuming that the observed month-2 increase is caused by campaign timing or customer behavior.

---

## 9. Limitations

- **Order-status scope:** the current query does not explicitly restrict orders to a production-defined status such as `delivered`. A production retention KPI should define which order statuses count as completed purchases.
- **Recent-cohort censoring:** newer cohorts have had less calendar time to generate repeat purchases, so their later-month retention rows are naturally shorter.
- **Month-level granularity:** `DATEDIFF(MONTH, ...)` measures calendar-month boundaries, not exact elapsed 30-day periods.
- **Descriptive analysis:** cohort retention identifies patterns but does not establish why customers returned or failed to return.
- **Dataset scope:** the project dataset is designed for SQL analytics practice and does not represent a production retail customer base.

---

## 10. Reproducibility

From the repository root:

1. Set up the SQL Server database using [`datasets/01_create_and_load.sql`](../datasets/01_create_and_load.sql).
2. Confirm the database is `RetailAnalytics`.
3. Execute [`query.sql`](./query.sql).
4. Review the resulting cohort/month-offset table.
5. Optionally create/use the stored procedure in [`usp_CohortRetention.sql`](./usp_CohortRetention.sql).
6. Compare the result structure with [`sample_output.csv`](./sample_output.csv).

The dataset setup and path requirements are documented in [`datasets/README.md`](../datasets/README.md).

---

## 11. Portfolio Skills Demonstrated

| Skill | Application |
|---|---|
| SQL Server / T-SQL | End-to-end cohort retention analysis |
| CTEs | Multi-stage analytical transformation |
| `DATEDIFF` | Month-offset calculation |
| Aggregation | Cohort sizing and active-customer counts |
| `COUNT(DISTINCT)` | Customer-level retention measurement |
| Data modeling | Correct person-level customer grain |
| Stored procedures | Reusable parameterized analysis |
| Business analytics | Retention measurement and action planning |
| Data validation | Structural, grain, and scope checks |

---

## 12. Project Files

```text
01_cohort_retention/
├── README.md
├── query.sql
├── usp_CohortRetention.sql
└── sample_output.csv
```