# Market Basket Analysis

## Business Question
Which products are commonly bought together, so we can improve cross-sell
recommendations and store/website merchandising?

## Approach
Built a co-purchase frequency analysis in SQL Server using a self-join:
1. Joined `order_items` to itself on `order_id`, matching every pair of
   distinct products that appeared in the same basket
2. Used `a.product_id < b.product_id` as the join condition — this single
   comparison does two jobs at once: it excludes a product from pairing
   with itself, and it ensures each real-world pair is counted only once
   (rather than once as A-B and again as B-A)
3. Grouped by the product pair and counted occurrences across all orders
4. Joined the `products` table in twice — once per side of the pair — to
   attach readable category names to each product ID
5. Ranked pairs by frequency to surface the strongest co-purchase signals

See [`query.sql`](./query.sql) for the full implementation.

## Finding
Electronics and home_appliances appear together in 9 of the top 20 product
pairs — nearly half — far more than any other category combination.
Individual product-pair counts are modest (the top pairs appear together
only 3-5 times each), but the clustering is consistent: 8 of those 9
electronics/home_appliances pairs occupy the top of the list, while fashion
pairs almost exclusively with beauty and furniture with garden. This
suggests the co-purchase signal lives at the category level rather than in
any single SKU combination — with 239 distinct products in the catalog,
random noise wouldn't reliably concentrate 8 of 9 top pairs into the same
two categories.

**So what:** This points toward category-level cross-sell rules rather
than individual SKU recommendations — surfacing "customers who buy
electronics often add home_appliances" at checkout or on product pages
likely generalizes better than trying to predict which specific items pair
together. Before rolling this into a recommendation engine, it's worth
confirming whether the pairing is driven by genuine complementary use
(e.g. a TV and a soundbar) or just co-occurring purchase timing (e.g. both
bought during a holiday sale) — the two would call for different
merchandising strategies.

## Sample Output
| product_a | category_a | product_b | category_b | how_often |
|---|---|---|---|---|
| PROD00013 | electronics | PROD00031 | home_appliances | 5 |
| PROD00017 | electronics | PROD00034 | home_appliances | 5 |
| PROD00039 | fashion | PROD00083 | beauty | 4 |
| PROD00115 | toys | PROD00166 | books | 4 |
| PROD00153 | furniture | PROD00231 | garden | 4 |

*(Full output in [`sample_output.csv`](./sample_output.csv))*
