# RFM Customer Segmentation

## Business Question
Which customers are most valuable and worth protecting, and which are
showing early signs of churn risk? Rather than treating all customers the
same, can we prioritize retention spend toward the segments where it will
have the most impact?

## Approach
Built an RFM (Recency, Frequency, Monetary) segmentation model in SQL
Server:
1. Computed three metrics per customer via separate CTEs: days since last
   order (Recency), count of delivered orders (Frequency), and total spend
   (Monetary)
2. Scored each dimension 1-5 using `NTILE()`, handling the direction
   carefully — a *smaller* recency_days is a *better* score, the opposite
   direction from frequency/monetary where a bigger raw number is already
   better
3. Averaged Frequency and Monetary into a single "value" signal, then
   bucketed both Recency and the F&M average into High/Mid/Low using
   `CASE`
4. Mapped the resulting 3x3 grid to the industry-standard 9-segment RFM
   model (Champions, At Risk, Lost, etc.) via a second `CASE` statement
5. Aggregated to a segment-level summary with customer count, % share, and
   average spend — using `SUM(COUNT(*)) OVER ()` to compute each segment's
   share of the total without a second query

See [`query.sql`](./query.sql) for the full implementation.

## Finding
Champions — the top 16.7% of customers — spend an average of **$1,688.59**,
more than **5.6x** what the Lost segment (28.5% of the customer base)
spends ($301.42). Value doesn't decay smoothly with recency, though: the
**"About to Sleep"** segment, which the standard RFM grid flags as fading
and mid-value, actually averages **$1,256.99** — nearly matching Loyal
Customers ($1,629.11) and far exceeding Need Attention ($743.43). These are
high-value customers going quiet, not low-value ones drifting away.

**So what:** Retention budget is likely better spent re-engaging "About to
Sleep" customers before they lapse fully into "Lost" (where average spend
drops to $301.42) than on lower-value segments the standard grid might
otherwise prioritize equally. A targeted win-back campaign for this
specific segment — rather than a generic "inactive customers" blast — could
recover a disproportionate share of at-risk revenue.

## Sample Output
| rfm_segment | customer_count | pct_of_customers | avg_spent |
|---|---|---|---|
| Lost | 812 | 28.5 | 301.42 |
| Champions | 474 | 16.7 | 1688.59 |
| Potential Loyalists | 377 | 13.3 | 383.81 |
| New Customers | 287 | 10.1 | 106.29 |
| Promising | 235 | 8.3 | 161.36 |
| About to Sleep | 185 | 6.5 | 1256.99 |
| Need Attention | 174 | 6.1 | 743.43 |
| Loyal Customers | 160 | 5.6 | 1629.11 |
| At Risk | 141 | 5.0 | 1540.34 |

*(Full output in [`sample_output.csv`](./sample_output.csv))*
