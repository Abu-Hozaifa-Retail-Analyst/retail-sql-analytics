# Pricing & Discount Analysis

## Business Question
Do lower-priced or more heavily discounted products actually sell in
higher volume? Where does typical (median) selling price sit relative to
list price, by category — and does discount depth vary meaningfully
across categories?

## Approach
Built a category-level pricing analysis in SQL Server using
`PERCENTILE_CONT()` in place of `AVG()`, since a handful of outlier sales
can distort a simple average in a way that misrepresents "typical"
pricing behavior:
1. Computed a per-line-item `discount_pct`, comparing each item's actual
   sold price against its list price (`base_price`) — a positive value
   means it sold below list, negative means it sold above list
2. Used `PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY discount_pct) OVER
   (PARTITION BY product_category_name)` to get the true **median**
   discount per category — this function interpolates between the two
   middle values when the 50th percentile falls between them, giving a
   smoother, more realistic figure than a simple bucket-based approach
3. Computed sales volume per category with a standard `GROUP BY`
4. Joined the two together to check whether categories with deeper
   discounts show higher volume

See [`query.sql`](./query.sql) for the full implementation.

## Finding
Across all 10 categories, median discount percentage clusters tightly
between **-2.1% and -3.0%**, with no category showing a meaningfully
different pricing pattern from any other. Every median is negative — items
are, on average, selling **slightly above list price** rather than being
discounted at all — and there's no visible relationship between discount
depth and sales volume (e.g. `books` has the smallest markup at -2.1% and
the *second-lowest* volume, while `home_appliances` has the largest markup
at -3.0% but middling volume).

**So what:** This dataset doesn't contain a real discount strategy to
analyze — pricing here reflects small, roughly-random variation around
list price, not a deliberate promotional or markdown pattern tied to
category or demand. Rather than force a "discounts drive volume" narrative
onto noise, the honest conclusion is that answering the original business
question properly would require transaction-level data that actually
records discounting — a `discount_amount`, `promotion_id`, or `campaign_id`
field distinguishing a genuine markdown from ordinary price variation.
Recognizing when a dataset can't support the question being asked is worth
noting explicitly, since forcing a story onto flat/noisy data is a common
analyst mistake.

## Sample Output
| product_category_name | median_discount_pct | items_sold |
|---|---|---|
| beauty | -2.6 | 875 |
| home_appliances | -3.0 | 818 |
| books | -2.1 | 794 |
| toys | -2.3 | 793 |
| electronics | -2.3 | 774 |

*(Full output in [`sample_output.csv`](./sample_output.csv))*
