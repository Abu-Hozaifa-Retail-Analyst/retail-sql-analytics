# Retail Analytics Practice Dataset (Synthetic)

A synthetic e-commerce dataset generated to mirror the structure of the
real [Olist Brazilian E-Commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce),
with realistic retail patterns built in so the SQL analyses produce
non-trivial business signals.

## Dataset contents

| File | Rows | Description |
|---|---:|---|
| `customers.csv` | 4,421 | One row per **order-level** customer id, mapped to the real person via `customer_unique_id` |
| `orders.csv` | 4,421 | One row per order: timestamp, customer id, status |
| `order_items.csv` | 7,624 | Line items per order |
| `products.csv` | 239 | Product catalog across 10 categories |
| `payments.csv` | 4,421 | One payment record per order in this synthetic dataset |

### Customer identity model

This dataset intentionally preserves the important Olist-style identity distinction:

- `customer_id` = customer record associated with an order
- `customer_unique_id` = the actual person across multiple orders

A customer can therefore appear in multiple rows of `customers.csv` while
sharing the same `customer_unique_id`. Customer-level analysis should use
`customer_unique_id`, not `customer_id`.

## Data model

```text
customers
   │ customer_id
   ▼
orders
   ├──────────────► payments
   │
   │ order_id
   ▼
order_items
   │ product_id
   ▼
products
```

The SQL setup script creates primary keys on the entity tables and validates
the four loaded relationships with foreign keys:

- `orders.customer_id` → `customers.customer_id`
- `order_items.order_id` → `orders.order_id`
- `order_items.product_id` → `products.product_id`
- `payments.order_id` → `orders.order_id`

## Patterns built into the data

The dataset is synthetic, but it was deliberately designed to contain
business patterns for analytical practice:

- **Seasonality:** order volume rises roughly 50–60% in Nov/Dec and dips in Jan/Feb.
- **Business growth:** acquisition volume trends upward over the 24-month window.
- **Customer loyalty tiers:**
  - ~55% one-time buyers
  - ~30% occasional repeaters
  - ~15% loyal/frequent buyers
- **Market basket affinity:** category pairs such as electronics ↔ home_appliances
  and fashion ↔ beauty are intentionally more likely to co-occur.
- **Olist identity trap:** grouping by `customer_id` instead of
  `customer_unique_id` would incorrectly make every order-level customer
  look like a one-time buyer.

These are **dataset design characteristics**, not claims about the real Olist
dataset or real retail customers.

## Reproduce the database locally

### Prerequisites

- SQL Server **2017 or later**
- SQL Server Management Studio (SSMS) or another SQL Server-compatible client
- The repository cloned/downloaded locally
- Permission for the SQL Server Database Engine to read the CSV folder
- Permission to create the `RetailAnalytics` database and perform bulk import

SQL Server 2017+ is required because the setup script uses
`BULK INSERT ... FORMAT = 'CSV'`. Microsoft documents that CSV support for
`BULK INSERT` starts with SQL Server 2017. The bulk-import file path is
resolved from the **SQL Server machine**, not from the SSMS client. If SQL
Server is remote or containerized, the CSVs must be accessible from that
environment.

### Step 1 — Clone the repository

Clone the repository to a local folder.

The CSV files are already included under `datasets/`; no separate download is
required for this synthetic dataset.

### Step 2 — Open the setup script

Open:

```text
datasets/01_create_and_load.sql
```

in SSMS.

### Step 3 — Set the data folder

At the top of the load section, update **one line only**:

```sql
DECLARE @DataPath NVARCHAR(4000) =
    N'C:\path\to\retail-sql-analytics\datasets';
```

Replace the example path with the folder that contains the five CSV files.

Example on a local Windows installation:

```text
D:\GitHub\retail-sql-analytics\datasets
```

Do not commit your personal machine path if you make additional changes to
this script.

### Step 4 — Run the setup script

Execute the complete script.

It will:

1. Create the `RetailAnalytics` database if it does not exist.
2. Recreate the five tables.
3. Load all five CSV files.
4. Add foreign-key constraints to validate the relationships.
5. Return a row-count validation table.

Expected row counts:

| Table | Expected rows |
|---|---:|
| customers | 4,421 |
| products | 239 |
| orders | 4,421 |
| order_items | 7,624 |
| payments | 4,421 |

Every row-count check should return `PASS`.

### Step 5 — Select the correct database

The analytical project scripts operate against the current SQL Server database
context. After setup, select **RetailAnalytics** in SSMS before running the
project queries.

The reusable view/procedure scripts also assume that `RetailAnalytics` is
the active database.

SQL Server's `USE RetailAnalytics` statement changes the database context for
the following batch, which is why the setup script explicitly switches into
the project database.

### Step 6 — Run the analytical projects

Each numbered project contains:

- `query.sql` — analytical SQL
- `README.md` — business question, methodology, finding, and interpretation
- `sample_output.csv` — example result produced from the project dataset

The advanced reusable SQL objects are stored separately in:

```text
01_cohort_retention/usp_CohortRetention.sql
02_rfm_segmentation/vw_CustomerRFM.sql
performance/
```

Run those object-creation scripts only after the base tables have been loaded.

## Load troubleshooting

### "Cannot bulk load. The file could not be opened."

Check:

1. `@DataPath` points to the correct folder.
2. The five CSV files exist in that folder.
3. The SQL Server Database Engine can read that folder.
4. If SQL Server is remote, use a server-accessible local or UNC path.
5. Your SQL Server login has the required bulk-import permissions.

Microsoft notes that `BULK INSERT` reads the source file from the server
running SQL Server and that the Database Engine/security context must be able
to access the source location.

### "FORMAT = 'CSV' is not recognized."

Use SQL Server 2017+ or import the files through another supported SQL Server
loading method. CSV support for `BULK INSERT` was introduced in SQL Server
2017.

### Row-count check fails

Do not continue to the analytical projects.

First confirm:

- the repository CSV files were not modified,
- `@DataPath` points to the intended dataset folder,
- the load completed without errors,
- the CSV headers still match the setup script.

The expected counts are documented above so a fresh clone can be validated
before any analysis is run.

## Alternative import method

If `BULK INSERT` is not appropriate for your environment, SSMS's
**Import Flat File** wizard can be used instead. Review the inferred data types
before accepting the generated tables, then run the same relationship and
row-count checks.

## Dataset limitations

This is a **synthetic** portfolio dataset. It is useful for demonstrating SQL
analysis, data modeling, validation, and business reasoning, but its patterns
should not be interpreted as real customer behavior.

The schema also does not contain several real-world retail fields such as:

- promotion/campaign identifiers,
- store locations,
- inventory availability,
- customer demographics,
- product cost/margin structure,
- seller-level information,
- review data.

The limitation is intentional: the portfolio focuses on what can be answered
reliably from the available data.

## Want the real dataset instead?

The original Olist dataset is available from Kaggle:
https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

The real dataset is richer and includes additional entities such as reviews,
sellers, and geolocation. This repository uses the synthetic dataset as a
controlled, reproducible SQL practice environment.
