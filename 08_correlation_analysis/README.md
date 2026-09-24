# Correlation Analysis (Order Frequency vs. Order Value)

## Business Question
Is there a relationship between how often a customer orders and how much
they spend per order? Are frequent buyers bargain-hunters making small,
repeated purchases — or big spenders who also happen to buy often? The
answer determines whether "drive more frequent purchases" and "increase
average order value" are the same marketing lever, or two that pull in
different directions.

## Approach
SQL Server has no built-in `CORR()` function (unlike some other
databases), so the **Pearson correlation coefficient** is computed
manually here from its underlying formula:

```
r = (n·Σxy − Σx·Σy) / √[(n·Σx² − (Σx)²)·(n·Σy² − (Σy)²)]
```

`r` ranges from -1 (perfectly inverse relationship) to +1 (perfectly
together), with 0 meaning no linear relationship at all.

1. Built per-customer metrics: `order_count` (delivered orders only) and
   `avg_order_value` (`total_spent / order_count`)
2. Computed the six building blocks the formula needs — `n`, and the sums
   of `x`, `y`, `x·y`, `x²`, `y²` — as a single aggregation step
3. Assembled the formula directly in SQL, with `NULLIF` guarding the
   denominator against a divide-by-zero in the (unlikely) case of zero
   variance in either variable
4. Ran a second, secondary correlation for contrast: line-item `price`
   vs. `freight_value`, testing whether higher-priced items cost more to
   ship — a reasonable real-world expectation

See [`query.sql`](./query.sql) for the full implementation.

## Finding
Both correlations came back **essentially zero**: order frequency vs.
average order value scored **r = 0.013** across 2,845 customers, and
price vs. freight cost scored **r = 0.003** across 7,624 line items.
Neither is a coding error — both are genuine, honest null results.
Frequent buyers in this dataset spend about the same per order as
infrequent ones; there's no bargain-hunter pattern and no
frequent-big-spender pattern, just no relationship at all. Likewise,
shipping cost here doesn't scale with item price.

**So what:** For the frequency/value question, this means the business
can pursue frequency-driving campaigns (loyalty programs, reorder
reminders) and order-value-driving campaigns (upsells, bundling)
independently — neither one is likely to cannibalize or reinforce the
other, since they don't move together in the current customer base. For
the price/freight result, it's a useful sanity check that flat or
distance-based shipping pricing (rather than value-based shipping) is
what's actually reflected in this data — worth confirming against real
shipping cost logic if this were production data rather than a practice
dataset, since a genuine price/freight relationship would usually be
expected in a live catalog.

## Sample Output
| customers_analyzed | correlation_order_count_vs_avg_order_value |
|---|---|
| 2845 | 0.013 |

| line_items_analyzed | correlation_price_vs_freight |
|---|---|
| 7624 | 0.003 |

*(Full output in [`sample_output.csv`](./sample_output.csv))*
