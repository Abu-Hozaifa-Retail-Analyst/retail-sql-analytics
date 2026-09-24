# Purchase Timing Patterns (Day-of-Week & Hour-of-Day)

## Business Question
When do customers actually shop? Are there real peak days or hours that
should drive staffing, flash-sale timing, or promotional scheduling — or
does purchase volume stay roughly constant regardless of when you look?

## Approach
Built day-of-week and hour-of-day breakdowns using `DATENAME` and
`DATEPART`, two date functions not used elsewhere in this repo:
1. `DATENAME(WEEKDAY, ...)` gives a readable label ("Monday"), but
   sorting on that label alphabetically would put "Friday" before
   "Monday" — a real gotcha. `DATEPART(WEEKDAY, ...)` supplies a numeric,
   chronologically-correct sort key instead, used in `GROUP BY`/`ORDER BY`
   without being displayed
2. `SET DATEFIRST 7` makes that numbering deterministic (1 = Sunday)
   regardless of the SQL Server instance's regional settings — without
   it, `DATEPART(WEEKDAY, ...)` can silently return different numbers on
   a different server, breaking the sort order in a way that wouldn't
   throw an error, just quietly produce a wrong-looking chart
3. A third query combines weekday + hour to surface the top 5 specific
   peak windows (e.g. "Friday at 5pm"), not just peaks along one
   dimension at a time

See [`query.sql`](./query.sql) for the full implementation.

## Finding
Purchase volume is close to flat across both dimensions. Day-of-week
order counts range from 574 (Tuesday) to 612 (Wednesday) — a spread of
just **6.4%** — and hourly volume is similarly even throughout the day,
with no hour standing out as a clear peak. The top 5 day+hour windows
(topped by Friday at 5pm, 58 orders) aren't meaningfully larger than
dozens of other combinations — consistent with noise rather than a real
recurring pattern.

This is the **third** project in this repo to return an essentially null
result, after Project 5 (pricing/discounts) and Project 8 (correlation
analysis). That's worth naming directly rather than treating as a
coincidence: this synthetic dataset generates order timestamps, prices,
and freight costs with independent random jitter, rather than modeling
the behavioral rhythms a real business would actually have (evening and
weekend shopping spikes, lunch-hour browsing peaks, price-dependent
shipping costs). A synthetic practice dataset built for SQL technique
practice doesn't automatically encode the human behavior patterns real
transaction data would contain.

**So what:** The SQL techniques here — correct weekday sorting,
`DATEFIRST` awareness, day+hour peak-window detection — are exactly what
you'd run against real transaction data, where these patterns are
genuinely expected to exist and matter operationally. On this dataset,
the honest conclusion is "no meaningful timing pattern found," and a
repeated pattern of null results across pricing, correlation, and timing
is itself a useful signal: verify what a dataset actually encodes before
trusting an analysis built on top of it, whether that means checking the
ETL process, the data generation logic, or simply re-running the same
query against real production data once available.

## Sample Output

**Day-of-week:**
| weekday_name | order_count | revenue |
|---|---|---|
| Monday | 585 | 322894.15 |
| Wednesday | 612 | 309448.05 |
| Sunday | 606 | 302831.69 |

**Top peak windows:**
| weekday_name | order_hour | order_count |
|---|---|---|
| Friday | 17 | 58 |
| Friday | 14 | 57 |
| Wednesday | 14 | 57 |

*(Full output in [`sample_output.csv`](./sample_output.csv))*
