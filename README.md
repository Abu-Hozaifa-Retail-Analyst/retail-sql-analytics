# Retail SQL Analytics

![SQL Server](https://img.shields.io/badge/SQL_Server-CC2927?style=flat&logo=microsoftsqlserver&logoColor=white)
![T-SQL](https://img.shields.io/badge/T--SQL-4479A1?style=flat&logo=databricks&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue?style=flat)
![Status](https://img.shields.io/badge/status-active-brightgreen?style=flat)

SQL portfolio project demonstrating retail/e-commerce business analysis —
customer retention, segmentation, and purchasing behavior — using T-SQL
(SQL Server) on a realistic e-commerce dataset.

Each project below solves a specific business question a retail analyst
would actually be asked, not just an isolated SQL exercise. Every folder
contains the query, a written business finding, and sample output.

## Skills demonstrated
CTEs · Window functions (`LAG`, `NTILE`, `PERCENTILE_CONT`) · Date/time
functions · CASE statements · Aggregation & GROUP BY · Multi-table JOINs ·
Self-joins · Subqueries

| Technique | Used in |
|---|---|
| CTEs (multi-step) | Projects 1, 2, 3, 4, 5 |
| Window functions — `NTILE()` | Project 2, 5 |
| Window functions — `LAG()` | Project 4 |
| Window functions — `PERCENTILE_CONT()` | Project 5 |
| `CASE` statements | Project 2 |
| Self-joins | Project 3 |
| Subqueries (scalar) | Projects 1, 2, 4 |
| `DATEDIFF` / date logic | Projects 1, 2, 4 |
| Multi-table JOINs | All projects |

## Projects

| # | Project | Business Question | SQL Techniques | Key Finding |
|---|---|---|---|---|
| 1 | [Cohort Retention Analysis](./01_cohort_retention) | What % of new customers come back to buy again, and when? | CTEs, `DATEDIFF`, self-referencing joins | Retention drops to 8.2% by month 1, but rebounds to 10.7% at month 2 — win-back campaigns may be timed too early |
| 2 | [RFM Segmentation](./02_rfm_segmentation) | Which customers are most valuable, and which are at risk of churning? | `NTILE()`, `CASE`, window functions | Champions spend 5.6x more than Lost customers — but "About to Sleep" customers are nearly as valuable as Loyal ones, suggesting misprioritized win-back spend |
| 3 | [Market Basket Analysis](./03_market_basket_analysis) | Which products are commonly bought together? | Self-joins, aggregation | Electronics/home_appliances dominate top co-purchase pairs — signal lives at the category level, not individual SKUs |
| 4 | [Churn Risk Detection](./04_churn_detection) | Which active customers show early signs of going inactive? | `LAG`/`LEAD`, window functions | Flagged customers average 31.5x their normal ordering gap — the threshold catches already-lost customers, not early risks |
| 5 | [Pricing & Discount Analysis](./05_pricing_discount_analysis) | Are discounts actually driving incremental volume, or just margin loss? | Percentile functions, CTEs | No meaningful discount pattern found across categories — a null result showing the dataset can't support this question without real promotion-level data |

## Dataset
A synthetic e-commerce dataset (`/datasets`) modeled on the structure of the
[Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce),
with realistic seasonality, customer loyalty tiers, and cross-category
purchase patterns built in. See [`datasets/README.md`](./datasets/README.md)
for schema details and setup instructions.

## Tools
SQL Server / T-SQL, SSMS

## License
MIT — see [LICENSE](./LICENSE)
