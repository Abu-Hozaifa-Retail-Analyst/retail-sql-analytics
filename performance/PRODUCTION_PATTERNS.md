# Performance & Production Patterns

This folder holds SQL patterns that go beyond the core five/six project
analyses — the kind of production-oriented thinking (reusability,
performance, safety) that a working analyst applies once a query moves
from "one-off analysis" to "something that runs repeatedly."

## Contents

| File | What it demonstrates |
|---|---|
| [`indexes.sql`](./indexes.sql) | 4 reasoned indexes covering equality joins, composite joins with range comparisons, a filtered index for a low-selectivity column, and an index supporting a window function's `PARTITION BY`/`ORDER BY` |
| [`usp_RefreshRFMSnapshot.sql`](./usp_RefreshRFMSnapshot.sql) | Transactions + `TRY/CATCH` error handling — snapshotting a live view into a physical table safely |
| [`usp_DataQualityCheck.sql`](./usp_DataQualityCheck.sql) | A reusable data quality procedure, generalizing the manual NULL/duplicate checks from Project 2 into something re-runnable any time source data changes |

See [`README.md`](./README.md) *(this file's sibling section below)* for
the full indexing reasoning.

## Transactions & error handling: a verified test, not a hypothetical

`usp_RefreshRFMSnapshot` truncates and reloads a snapshot table inside a
transaction, wrapped in `TRY/CATCH`. Rather than just asserting this is
"safe," it was deliberately tested by injecting a forced runtime failure
(`SELECT 1/0;`) between the truncate and the reload:

- Row count before the forced failure: **2845**
- `EXEC usp_RefreshRFMSnapshot` → `Msg 50000: Divide by zero error
  encountered.` (the original SQL Server error, re-thrown by the `CATCH`
  block via `THROW`)
- Row count after the forced failure: **2845** — unchanged

This confirms the transaction genuinely protected the data: even though
`TRUNCATE` executed before the error was hit, `ROLLBACK` fully undid it,
so the table was never left empty or half-loaded.

A separate, earlier attempt to force a failure by referencing a
non-existent column was rejected by SQL Server *at `CREATE PROCEDURE`
time*, before the procedure could even be saved — a useful reminder that
SQL Server validates column references against existing tables/views at
compile time, not just at execution. Proving the transaction's rollback
behavior required a genuine *runtime-only* failure (divide-by-zero)
instead.

## Data quality checks

`usp_DataQualityCheck` runs three checks in one call:
1. NULLs in `vw_CustomerRFM`'s key scoring/segment columns
2. Duplicate customers in `vw_CustomerRFM` (should never happen, since
   it's grouped by `customer_unique_id` at every stage — a non-zero
   result here would indicate a real bug upstream)
3. Orphaned `order_items` rows — line items referencing an `order_id`
   that doesn't exist in `orders` at all, which would indicate a broken
   data load rather than normal business data

Run it any time source data changes:
```sql
EXEC dbo.usp_DataQualityCheck;
```
