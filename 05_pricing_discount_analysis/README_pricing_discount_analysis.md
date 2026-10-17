# Pricing & Discount Analysis

SQL Server project: do lower-priced or more-discounted items sell in higher volume, and where does the typical selling price sit relative to list price?

> The dataset is **synthetic** and has no promotion or campaign fields. This is a null-result project: the goal is to test the question properly and say what the data can and cannot answer.

## 1. Business problem

Do lower-priced or more-discounted items sell in higher volume? Where does the typical selling price sit relative to list price, by category? The decision is whether to use discounts to lift volume. The catch: a null result is only credible if it is tested with enough data points and a confidence interval.

## 2. Data

| Item | Value |
|---|---|
| Tables | `order_items`, `products`, `orders` |
| Sales analyzed | 7,148 delivered order lines (of 7,624) |
| Products | 239 in 10 categories |
| Price measure | sold price vs list price (`base_price`) |
| Test levels | 239 products and 24 months |

## 3. Methodology

- **`price_vs_list_pct`** = (sold price - list price) / list price x 100. **Positive means sold above list, negative means a discount.** (The first version used the opposite sign and called it `discount_pct`, so every median looked like a "negative discount".)
- **Median and quartiles** by category with `PERCENTILE_CONT`, which interpolates between the two middle values.
- **Does a lower price sell more?** Ten category medians cannot answer that, so it is tested at product level (239 points: average price vs list against items sold) and month level (24 points), with a Pearson correlation and a 95% confidence interval (Fisher z).
- **Peak test:** Nov-Dec is the volume peak. If discounts drove volume, prices there would be lower.
- Only **delivered** orders count as sales.

## 4. SQL

[`query.sql`](./query.sql) contains:

- **Query 1:** price vs list by category (p25, median, p75, share sold below list, items sold)
- **Query 2:** manual Pearson correlation with a 95% confidence interval, at product and month level
- **Query 3:** peak months vs other months
- **Validation checks V1 to V5**

## 5. Validation

| Check | Result |
|---|---|
| Category medians and item counts vs the first version (all orders, sign flipped) | 10 of 10 match, pass |
| Independent re-calculation of percentiles, correlations and intervals | all match, pass |
| Sold price is bounded around list | 0.90x to 1.15x of list, pass |
| Delivered lines | 7,148 of 7,624 |
| Missing or zero list prices | 0, pass |

**Corrections to the first write-up:**

- It said books had the *second-lowest* volume and home_appliances *middling* volume. The first version's own output shows books third highest (794 items) and home_appliances second highest (818).
- It chose the median because outliers could distort an average. Prices here are bounded (0.90x to 1.15x of list), so the mean (+2.5%) and the median (+2.4%) agree.
- Comparing ten category medians with volume was too few points to test anything.

## 6. Finding

**Price vs list price by category (delivered orders):**

| product_category_name | items_sold | p25 | median | p75 | pct_sold_below_list |
|---|---|---|---|---|---|
| beauty | 812 | -3.8 | 2.6 | 9.1 | 38.2 |
| home_appliances | 763 | -3.7 | 3.0 | 9.4 | 39.3 |
| toys | 753 | -3.5 | 2.4 | 8.2 | 39.3 |
| books | 749 | -4.3 | 2.0 | 8.6 | 42.5 |
| electronics | 724 | -3.8 | 2.3 | 8.3 | 40.2 |
| sports | 702 | -3.8 | 2.6 | 8.5 | 40.5 |
| garden | 695 | -3.4 | 2.4 | 8.6 | 39.1 |
| furniture | 692 | -3.4 | 2.4 | 8.9 | 40.9 |
| fashion | 654 | -3.4 | 2.4 | 9.3 | 40.4 |
| groceries | 604 | -4.4 | 2.3 | 8.8 | 41.1 |

All 10 medians sit within 1.0 point of each other (2.0% to 3.0% above list). Inside a category the middle half of prices spans about 12.5 points. About 60% of items sold above list and 40% below.

**Price vs volume:**

| level | n | pearson_r | 95% interval |
|---|---|---|---|
| product | 239 | +0.054 | -0.07 to +0.18 |
| month | 24 | -0.188 | -0.55 to +0.23 |

**Peak test:**

| period | items_per_month | avg_price_vs_list_pct |
|---|---|---|
| Nov-Dec (peak) | 438 | +2.49 |
| Other months | 270 | +2.50 |

## 7. Business meaning

- **There is no discount strategy to analyze:** prices vary randomly from about 10% below to 15% above list, and 60% of items sold above list.
- **Volume is seasonal, not price-driven:** the Nov-Dec peak (62% more items per month) happens at the same average price as every other month.
- **This does not prove discounts fail.** The data has no real promotions, so it cannot say whether discounts work. At product level it rules out effects larger than about r = 0.18; the month-level interval is wide.

## 8. Recommendation

1. **Do not change pricing from this data.** There is no discount signal to act on.
2. **Capture promotion data:** promotion ID and period, list price, selling price, units, margin, and comparable non-promoted periods.
3. **Run a controlled price test:** randomize prices or promotions across stores or weeks and compare volume.
4. **Report the null honestly:** show the interval, not just "no effect", because it says how large an effect could still hide.

## Limitations

- Synthetic data: prices look uniformly random around list.
- Each line is one item, so volume is a count of items sold.
- The month test has only 24 points, so its interval is wide.
- Correlation is not causation, and there is no promotion data.

## Sample output

- [`sample_output.csv`](./sample_output.csv): Query 1, by category
- [`sample_output_correlation.csv`](./sample_output_correlation.csv): Query 2
- [`sample_output_peak_months.csv`](./sample_output_peak_months.csv): Query 3

## Author

**Abu Hozaifa** | [LinkedIn](https://www.linkedin.com/in/abu-hozaifa-retail-analyst)
