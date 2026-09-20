# Performance & Indexing Strategy

## Why this exists
Every query in this repo runs correctly on the practice dataset (a few
thousand rows), but "correct" and "fast at scale" aren't the same thing.
This document reasons through which indexes would actually speed up the
query patterns used across all six projects, based on their real `JOIN`
and `WHERE` clauses — not applied speculatively.

## How indexes were chosen
The rule followed here: look at every column that appears in a `WHERE`,
`JOIN ... ON`, `GROUP BY`, or `ORDER BY` clause across the actual queries
in this repo, and evaluate each one for:
1. **How often it's used** — a column touched by one query is a much
   lower priority than one used in five
2. **Selectivity** — whether the column has many unique values (a strong
   indexing candidate) or a small number of repeated values (often a poor
   one, unless paired with a filtered index — see index #3 below)
3. **What's already indexed automatically** — every `PRIMARY KEY`
   constraint already creates a clustered index for free; re-indexing
   that column elsewhere would be redundant overhead with no benefit

## Recommended indexes

### 1. `order_items (order_id, product_id)`
**Used by:** Project 3 (Market Basket Analysis) — the self-join that
matches every pair of products within the same basket. `order_id` is
listed first (an equality match, so SQL Server can jump straight to one
order's rows), `product_id` second (to efficiently support the `<`
comparison within that already-narrowed group).

### 2. `orders (customer_id)`
**Used by:** nearly every project (1, 2, 3, 4, 5, 6) — all of which join
`orders` to `customers`. The `customers` side of this join is already
fast, since `customer_id` is that table's primary key. The `orders` side
had no automatic index at all — meaning this exact join was
table-scanning `orders` in every project until this index exists.

### 3. `orders (order_id) WHERE order_status = 'delivered'` — filtered index
**Used by:** Projects 2, 3, 4, 6 — all of which filter
`WHERE order_status = 'delivered'`. `order_status` is a poor candidate
for a normal index: it only has 3 distinct values, and roughly 94% of
rows are `'delivered'`, so a plain index would still point to nearly the
whole table and likely be ignored by the query optimizer. A **filtered
index** solves this by only indexing the specific slice of rows the
queries actually ask for, making it small and genuinely selective instead
of redundant with the base table.

See [`indexes.sql`](./indexes.sql) for the runnable `CREATE INDEX`
statements with full inline reasoning.

## Trade-off worth naming
Indexes aren't free — every index SQL Server maintains adds overhead to
every `INSERT`/`UPDATE`/`DELETE` on that table, since the index has to be
kept in sync. These three were chosen because they're reused across
multiple projects' real query patterns, not applied to every column that
theoretically could be indexed. A column touched by a single one-off query
usually isn't worth the write-side cost.
