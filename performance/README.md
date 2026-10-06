# Performance & Indexing Strategy

## Why this exists

The analytical queries in this repo are written for correctness first. This folder documents index candidates derived from the actual query patterns used across the nine analytical projects.

The goal is to demonstrate practical SQL Server performance reasoning without claiming a performance improvement that has not been measured.

## How indexes were chosen

Each candidate was reviewed against the repository's actual:

- JOIN conditions
- WHERE filters
- ORDER BY requirements
- window-function access patterns
- existing primary-key indexes

The review considers:

1. Access pattern — how the query reaches and filters rows.
2. Column order — whether the index key follows the useful equality/range pattern.
3. Selectivity — whether an index is likely to narrow the search meaningfully.
4. Existing indexes — primary keys already provide indexes and should not be duplicated unnecessarily.
5. Write overhead — every additional index must be maintained during data changes.

## Recommended indexes

### 1. order_items (order_id, product_id)

Used by Project 3 — Market Basket Analysis.

The query self-joins order_items on order_id and compares product_id within the same order:

    ON a.order_id = b.order_id
    AND a.product_id < b.product_id

The index follows that access pattern: order_id first for equality, followed by product_id for the within-order comparison.

### 2. orders (customer_id)

Used by customer-based analytical queries that join:

    JOIN customers c
        ON o.customer_id = c.customer_id

customers.customer_id is already the primary key. The supporting index is therefore placed on the orders side of the relationship.

### 3. delivered orders: (customer_id, order_purchase_timestamp)

Filtered to order_status = 'delivered'.

Used by delivered-order analysis, including Project 4 — Churn Detection.

The churn query repeatedly:
- joins orders to customers using customer_id
- keeps only delivered orders
- works with order_purchase_timestamp

The filtered index keeps only delivered rows and uses (customer_id, order_purchase_timestamp) as its key.

## Important window-function clarification

Project 4 uses:

    LAG(o.order_purchase_timestamp) OVER (
        PARTITION BY c.customer_unique_id
        ORDER BY o.order_purchase_timestamp
    )

A previous version of this documentation implied that an index on orders(customer_id, order_purchase_timestamp) directly matched that window definition and would allow SQL Server to skip the sort.

That was too strong.

customer_unique_id is a column in customers, not orders. The index on orders therefore supports the join, delivered-row filtering, and purchase-date access pattern, but it does not guarantee that SQL Server can avoid sorting for the window function after the join.

Actual execution-plan behavior depends on the optimizer, statistics, data distribution, join strategy, and existing indexes.

## Performance claims: what this repository does and does not claim

These index definitions are recommendations based on query structure, not benchmark results.

This repository does not claim:
- a specific percentage reduction in query time
- guaranteed elimination of table scans
- guaranteed elimination of sort operators
- guaranteed index usage by the optimizer
- production-level performance gains from this practice dataset

For a production workload, validate an index with:
1. representative data volume
2. actual execution plans
3. logical reads
4. CPU time
5. elapsed time
6. before/after comparison
7. write workload impact

## Trade-off

Indexes are not free. SQL Server must maintain them during INSERT, UPDATE, and DELETE operations.

The recommended indexes are intentionally limited to recurring query patterns rather than indexing every column that appears in a query.

See [indexes.sql](./indexes.sql) for the runnable CREATE INDEX statements and inline reasoning.
