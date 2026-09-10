# Retail Analytics Practice Dataset (Synthetic)

A synthetic e-commerce dataset generated to mirror the structure of the
real [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce),
built with realistic retail patterns baked in so the queries you write
produce genuine, non-trivial insights.

## Files
| File | Rows | Description |
|---|---|---|
| `customers.csv` | 4,421 | One row per **order-level** customer id, mapped to the real person (`customer_unique_id`) |
| `orders.csv` | 4,421 | One row per order: timestamp, status |
| `order_items.csv` | 7,624 | Line items per order (1–4 items each) |
| `products.csv` | 239 | Product catalog across 10 categories |
| `payments.csv` | 4,421 | Payment method/value per order |

## Patterns built into the data (so your analysis finds something real)
- **Seasonality**: order volume rises ~50-60% in Nov/Dec (holiday effect), dips in Jan/Feb.
- **Business growth**: acquisition volume trends up slightly over the 24-month window.
- **Customer loyalty tiers** (hidden — this is what you're solving for):
  - ~55% one-time buyers (never return)
  - ~30% occasional repeaters (return within ~1-4 months, may return multiple times)
  - ~15% loyal/frequent buyers (short repeat gaps, high order count)
- **Market basket affinity**: certain category pairs co-occur more often than chance
  (electronics↔home_appliances, fashion↔beauty, sports↔beauty, furniture↔garden, toys↔books)
  — a real signal for your basket-analysis query to surface.
- **The Olist "gotcha"**: `customer_id` is unique **per order**; `customer_unique_id`
  identifies the actual person. If you group by `customer_id` instead of
  `customer_unique_id`, every customer will incorrectly look like a one-time buyer.
  This is intentional — real Olist data has the same trap.

## Loading into SQL Server
See `01_create_and_load.sql` in this folder. It creates the database/tables
and loads via `BULK INSERT`. Update the file paths to match where you place
the CSVs relative to your SQL Server instance (see notes in the script for
Docker/remote setups).

## Want the real dataset instead?
Download the actual Olist data from Kaggle:
https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
The schema is slightly richer (includes reviews, sellers, geolocation) —
worth swapping in once you've validated your queries here, since "I used
a real public dataset" carries more weight in a portfolio than synthetic data.
