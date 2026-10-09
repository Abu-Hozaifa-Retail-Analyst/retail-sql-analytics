# Retail SQL Analytics — Customer Intelligence, Sales Performance & Business Analysis

![SQL Server](https://img.shields.io/badge/SQL_Server-CC2927?style=flat&logo=microsoftsqlserver&logoColor=white)
![T-SQL](https://img.shields.io/badge/T--SQL-4479A1?style=flat&logo=databricks&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat)
![Status](https://img.shields.io/badge/status-active-brightgreen?style=flat)

A recruiter-facing **retail/e-commerce SQL analytics portfolio project** built in SQL Server and T-SQL.

The project answers practical business questions across **customer retention, customer value, churn risk, basket behavior, pricing, sales growth, forecasting, correlation, and purchase timing** while demonstrating data modeling, reusable SQL objects, data-quality checks, indexing strategy, transaction handling, and reproducible database setup.

> **Portfolio focus:** turn transactional data into validated business insights and actionable retail decisions — not just demonstrate SQL syntax.

## Business Problem

Retail teams need answers beyond total sales:

- Are customers returning after their first purchase?
- Which customer segments deserve retention attention?
- Which customers are overdue relative to their own buying pattern?
- Which products or categories are commonly purchased together?
- Is revenue growing consistently year over year?
- What should next month's revenue look like after seasonality?
- Are there meaningful relationships between purchasing behavior and order value?
- Are there genuine shopping-time peaks?

This repository addresses those questions through **nine focused SQL analyses** built on one consistent relational dataset.

## Analytical Workflow

```text
Transactional Data
       |
       v
Data Model & Relationships
       |
       v
Data Quality / Validation
       |
       v
SQL Transformation & Analysis
       |
       +--> Customer Retention
       +--> RFM Segmentation
       +--> Market Basket
       +--> Churn Risk
       +--> Pricing & Discounts
       +--> Sales Trend & YoY
       +--> Forecasting
       +--> Correlation
       +--> Purchase Timing
       |
       v
Validated Findings
       |
       v
Business Interpretation
       |
       v
Recommendations + Limitations
```

## Technical Skills Demonstrated

- SQL Server / T-SQL
- Multi-table JOINs
- CTEs and recursive CTEs
- Window functions: LAG(), NTILE(), PERCENTILE_CONT()
- Explicit window frames
- Deterministic scoring (fixed rules and tie-breakers for window functions)
- Self-joins and CROSS JOIN
- CASE-based business classification
- Aggregation and GROUP BY
- Scalar subqueries
- Date/time analysis
- Manual Pearson correlation
- Stored procedures and reusable views
- Transactions and TRY/CATCH
- Filtered/composite indexes
- Data-quality validation

## Data Model

```text
customers
   | customer_id
   v
orders -----------------> payments
   |
   | order_id
   v
order_items
   | product_id
   v
products
```

| Parent | Child | Relationship |
|---|---|---|
| customers.customer_id | orders.customer_id | Customer -> Orders |
| orders.order_id | order_items.order_id | Order -> Line Items |
| products.product_id | order_items.product_id | Product -> Line Items |
| orders.order_id | payments.order_id | Order -> Payments |

### Important customer identity rule

This is an Olist-style model where:

- customer_id identifies the customer record associated with an order.
- customer_unique_id identifies the actual person across orders.

Customer-level retention, RFM, and churn analysis therefore uses customer_unique_id. Using customer_id as the person-level identifier would incorrectly make repeat customers appear to be one-time buyers. In this dataset, 4,421 customer_id values belong to only 3,000 real people.

## Dataset

The repository contains a **synthetic e-commerce dataset** designed for controlled SQL analytics practice. It is modeled on the structure of the Olist Brazilian E-Commerce dataset, but the findings in this repository are **not claims about real Olist or real retail customers**.

| Table | Rows | Purpose |
|---|---:|---|
| customers | 4,421 | Order-level customer records and person-level identity |
| orders | 4,421 | Orders, timestamps, and status |
| order_items | 7,624 | Products purchased within orders |
| products | 239 | Product catalog and base pricing |
| payments | 4,421 | Payment information |

The synthetic data intentionally contains patterns such as seasonality, customer loyalty tiers, and cross-category purchasing signals.

Dataset documentation: [datasets/README.md](./datasets/README.md)

# Business Analysis Portfolio

## 1. Customer Cohort Retention

**Business question:** Of customers who made their first purchase in a given month, what percentage return later? Is growth coming from repeat customers, or from new one-time buyers?

**SQL:** CTEs · DATEDIFF · customer identity modeling · aggregation · parameterized stored procedure

**Observed finding:** Month-1 retention averages **8.2%** and stays between 8% and 11% through month 4, then falls to **5.0% at month 5** (lower than month 4 in all 19 cohorts that reached it). Month 2 (10.7%) beats month 1 in **14 of 22 cohorts**, which is suggestive but not statistically conclusive.

**Business implication:** Most customers buy once, and growth is acquisition-driven: the average cohort grew 16% from 2023 to 2024 while month-1 retention stayed flat (8.2% vs 8.1%). The repurchase window appears to be roughly months 1 to 4.

**Potential action:** Focus retention effort on months 1 to 4, A/B test win-back timing (day 30 vs day 45 to 60), and confirm with day-level gaps between orders, since calendar-month buckets blur the window.

[View Project 1 ->](./01_cohort_retention)

## 2. RFM Customer Segmentation

**Business question:** Which customers are most valuable and worth protecting, and which are showing signs of churn risk?

**SQL:** CTEs · NTILE() · fixed-rule scoring · CASE · reusable view · snapshot procedure

**Observed finding:** Champions are **6.9%** of scored customers and bring **23.2%** of revenue (average spend **$2,484.91**, versus **$346.64** for Lost). Champions, Loyal Customers and At Risk together (13.6% of customers) bring **41.6%**. At Risk and About to Sleep hold **18.3%** of revenue, but last ordered 15 to 17 months ago on average.

**Method note:** Frequency uses fixed rules because about 80% of customers have exactly one order. An earlier NTILE-based version gave identical customers different scores, so its segments changed with row order; the corrected version is deterministic and stable under different tie-breaks.

**Business implication:** Revenue is concentrated in a small group of repeat buyers, and a sizable share sits with valuable customers who have gone quiet.

**Potential action:** Protect Champions, test a personal win-back offer for At Risk customers first (93 repeat buyers, $185K), and nudge New Customers toward a second order inside the Project 1 repurchase window.

[View Project 2 ->](./02_rfm_segmentation)

## 3. Market Basket Analysis

**Business question:** Which products are commonly purchased together?

**SQL:** Self-joins · aggregation · product/category joins

**Observed finding:** Electronics and home-appliances appear together in **10 of the top 20 product pairs**, representing half of the top-20 ranking.

**Business implication:** The stronger signal appears at category level; individual pair counts remain modest.

**Potential action:** Test category-level cross-sell rules, then validate with larger volumes and support/confidence/lift metrics.

[View Project 3 ->](./03_market_basket_analysis)

## 4. Churn Risk Detection

**Business question:** Which repeat customers are unusually overdue compared with their own historical purchase rhythm?

**SQL:** LAG() · window functions · customer-level behavioral baselines

**Observed finding:** Flagged customers average **31.5x their normal ordering gap**, indicating the current threshold identifies customers who appear already lost rather than genuinely early-stage risks.

**Business implication:** A technically valid churn rule can still be poorly calibrated for an early-warning objective.

**Potential action:** Recalibrate the threshold around earlier warning points and evaluate it against known retention outcomes.

[View Project 4 ->](./04_churn_detection)

## 5. Pricing & Discount Analysis

**Business question:** Are lower prices or deeper discounts associated with higher sales volume?

**SQL:** PERCENTILE_CONT() · CTEs · category analysis

**Observed finding:** Median discount values cluster around **-2.1% to -3.0%** across categories. The dataset does not provide meaningful discount variation for a reliable discount-volume conclusion.

**Business implication:** This is a valid null result: the available data cannot answer the promotion-effectiveness question reliably.

**Potential action:** Add promotion IDs, promotion periods, list price, selling price, units, margin, and comparable non-promoted periods.

[View Project 5 ->](./05_pricing_discount_analysis)

## 6. Sales Trend & YoY Growth

**Business question:** Is sales growth consistent, and are zero-sales months represented correctly?

**SQL:** Recursive CTE · date spine · LAG() · NULLIF

**Observed finding:** Every month in **2024 exceeded the corresponding month in 2023**, with YoY growth ranging from **20.6% to 144.5%**.

**Business implication:** The dataset shows broad YoY growth, while month-over-month volatility can distort short-term interpretation.

**Potential action:** Evaluate YoY, MoM, and longer-term trend together.

[View Project 6 ->](./06_sales_trend_yoy)

## 7. Sales Forecasting — Trend + Seasonality

**Business question:** What should next month's revenue look like after accounting for calendar seasonality?

**SQL:** Window frames · moving average · scalar subquery · CROSS JOIN

**Observed finding:** Trend-only January 2025 forecast = **$123,884**; seasonality-adjusted forecast = **$106,540**, a difference of approximately **$17.3K**.

**Business implication:** Recent trend alone can overstate expected revenue when the target month is historically weaker.

**Potential action:** Use seasonal adjustment as a baseline, then compare stronger methods using out-of-sample validation.

[View Project 7 ->](./07_sales_forecasting)

## 8. Correlation Analysis

**Business question:** Do customers who order more frequently also have higher average order value?

**SQL:** Manual Pearson correlation · aggregation · statistical formula implementation

**Observed finding:** Frequency vs. average order value produced **r = 0.013** across 2,845 customers; price vs. freight cost produced **r = 0.003** across 7,624 line items.

Both relationships are effectively zero in this dataset.

**Important limitation:** Correlation measures linear association; it does not establish causation.

[View Project 8 ->](./08_correlation_analysis)

## 9. Purchase Timing Patterns

**Business question:** Are there meaningful day-of-week or hour-of-day purchasing peaks?

**SQL:** DATENAME() · DATEPART() · SET DATEFIRST · date/time aggregation

**Observed finding:** Daily order counts range from **574 to 612**, a range equal to about **6.4% of average daily volume**. Hourly demand is similarly distributed, with no clear dominant hour.

**Business implication:** This dataset does not show a strong recurring time-of-day demand pattern.

**Potential action:** Do not redesign staffing or promotional schedules from this dataset alone; validate with higher-volume operational data.

[View Project 9 ->](./09_purchase_timing_patterns)

# Cross-Project Business Findings

### Customer value is concentrated
RFM shows that 13.6% of customers (Champions, Loyal and At Risk) bring 41.6% of revenue, while 72% of customers are mostly one-time buyers who bring 34%. Cohort retention (Project 1) shows the same one-time-buyer pattern from a different angle, so retention decisions should consider customer value alongside recency.

### Retention windows and customer segments point to the same action
Project 1 suggests the repurchase window is months 1 to 4, and Project 2 shows that most New Customers are still inside it. A second-purchase nudge during that window is the most direct way to convert one-time buyers.

### Window-function ties can silently change results
In RFM, NTILE on a column where 80% of customers share the same value gave different segments depending on row order. Fixed scoring rules and deterministic tie-breakers made the results reproducible, and a tie-break sensitivity check confirmed they are stable.

### Churn detection needs calibration
The churn analysis demonstrates that a mathematically consistent rule can still be operationally too late. Threshold selection should be validated against the desired intervention window.

### Null results are still useful
Pricing, correlation, and purchase-timing analyses produce weak or null relationships. Good analytics includes identifying when the available data cannot support a business conclusion.

### Seasonality matters for planning
The forecasting analysis shows how calendar effects can materially change a revenue expectation compared with a trend-only baseline.

### Aggregation can reveal stronger business signals
Market basket analysis shows stronger concentration at category level than at individual SKU-pair level.

# Data Quality & Governance

Data quality is treated as part of the analytical workflow.

- Primary-key definitions
- Foreign-key validation
- NULL checks
- Duplicate checks
- Orphan-record checks
- Row-count sanity checks
- Explicit delivered-order filtering
- Customer identity validation
- Result reconciliation (segment customers and revenue match source totals)
- Tie-break sensitivity checks for window-function scoring
- Transaction rollback testing
- Reusable data-quality procedure
- Documented assumptions and limitations

Reusable validation: [performance/usp_DataQualityCheck.sql](./performance/usp_DataQualityCheck.sql)

# Advanced SQL Engineering

| Pattern | Implementation |
|---|---|
| Parameterized stored procedure | [usp_CohortRetention.sql](./01_cohort_retention/usp_CohortRetention.sql) |
| Reusable RFM view | [vw_CustomerRFM.sql](./02_rfm_segmentation/vw_CustomerRFM.sql) |
| Recursive date spine | [Project 6](./06_sales_trend_yoy) |
| Filtered/composite indexing strategy | [performance/indexes.sql](./performance/indexes.sql) |
| Transaction + TRY/CATCH | [usp_RefreshRFMSnapshot.sql](./performance/usp_RefreshRFMSnapshot.sql) |
| Reusable data-quality checks | [usp_DataQualityCheck.sql](./performance/usp_DataQualityCheck.sql) |

Performance documentation deliberately avoids unsupported claims such as guaranteed scan elimination or guaranteed runtime improvement.

# Reproducibility

The repository is designed so another analyst can reproduce the database from a fresh clone.

**Requirements**

- SQL Server **2017+**
- SSMS or another SQL Server-compatible client
- Repository cloned locally
- SQL Server Database Engine access to the CSV folder
- Database creation and bulk-import permissions

**Setup**

1. Clone the repository.
2. Open [datasets/01_create_and_load.sql](./datasets/01_create_and_load.sql).
3. Update the single @DataPath variable to the folder containing the CSV files.
4. Execute the complete script.
5. Confirm all five row-count checks return PASS.
6. Select the RetailAnalytics database.
7. Run the project queries.

Expected row counts:

| Table | Rows |
|---|---:|
| customers | 4,421 |
| products | 239 |
| orders | 4,421 |
| order_items | 7,624 |
| payments | 4,421 |

The setup script also creates and validates the required foreign-key relationships.

Full setup guide: [datasets/README.md](./datasets/README.md)

> **Important:** BULK INSERT reads files from the SQL Server Database Engine environment. If SQL Server is remote or containerized, the CSV folder must be accessible from that environment.

# Repository Structure

```text
retail-sql-analytics/
|
+-- 01_cohort_retention/
+-- 02_rfm_segmentation/
+-- 03_market_basket_analysis/
+-- 04_churn_detection/
+-- 05_pricing_discount_analysis/
+-- 06_sales_trend_yoy/
+-- 07_sales_forecasting/
+-- 08_correlation_analysis/
+-- 09_purchase_timing_patterns/
|
+-- datasets/
|   +-- *.csv
|   +-- 01_create_and_load.sql
|   +-- README.md
|
+-- performance/
|   +-- indexes.sql
|   +-- usp_DataQualityCheck.sql
|   +-- usp_RefreshRFMSnapshot.sql
|   +-- README.md
|
+-- .gitignore
+-- LICENSE
+-- README.md
```

# Project Limitations

This is a **synthetic portfolio dataset**, so findings should not be presented as actual market or customer behavior.

Important limitations:

- No promotion/campaign identifiers
- No store-level geography
- No inventory availability
- No customer demographics
- No product cost/margin structure
- No seller-level information
- No review data
- Limited ability to establish causal relationships
- Small synthetic transaction volume relative to a production retailer
- Forecasting methods are lightweight SQL baselines rather than a production forecasting system

Knowing what the data **cannot** answer is part of responsible analytics.

# Tools

**SQL Server · T-SQL · SSMS · Git · GitHub**

# Portfolio Context

This repository is part of my broader **Retail Analytics portfolio**, focused on the workflow:

```text
Data Quality
    |
    v
SQL Analysis
    |
    v
Business Interpretation
    |
    v
Recommendations
    |
    v
Portfolio Documentation
```

The project is intentionally built around retail/e-commerce business questions rather than generic SQL exercises.

# License

MIT — see [LICENSE](./LICENSE).
