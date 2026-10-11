# Market Basket Analysis

SQL Server project: which products are commonly bought together, so cross-sell recommendations and store or website merchandising can improve?

> The dataset is **synthetic** with category affinities built in (see `datasets/README.md`). The test is whether the method finds them, not what a real market does.

## 1. Business problem

Which products are commonly bought together, so cross-sell recommendations and store/website merchandising can improve? The catch: a pair that appears often is not always a pair that belongs together, because popular items pair up by chance.

## 2. Data

| Item | Value |
|---|---|
| Tables | `order_items`, `orders`, `products` |
| Order lines | 7,624 |
| Orders | 4,421 (4,160 delivered) |
| Products | 239 in 10 categories (17 to 27 products each) |
| Baskets analyzed | 1,847 delivered orders with 2 or more different products |
| Distinct product pairs | 3,822 |

## 3. Methodology

- **Basket:** one delivered order. Canceled and shipped orders are not purchases.
- **Product pairs:** a self-join of `order_items` on `order_id`; `product_id < product_id` excludes a product pairing with itself and counts each pair once. Pairs are counted per *order* (`DISTINCT`), not per line.
- **Category pairs:** support, confidence and **lift**.
  - Support = share of baskets containing both categories
  - Confidence = of baskets with A, the share that also contain B
  - Expected baskets = baskets with A x baskets with B / all baskets
  - Lift = baskets with both / expected baskets (above 1 means bought together more than chance)

## 4. SQL

[`query.sql`](./query.sql) contains:

- **Query 1a:** product pairs bought together most often (`TOP 20 WITH TIES`)
- **Query 1b:** pairs seen 3+ times, rolled up to category pairs
- **Query 2:** category pairs with support, confidence and lift
- **Validation checks V1 to V5**

## 5. Validation

| Check | Result |
|---|---|
| Query 2 returns one row per category pair (10 choose 2) | 45 of 45, pass |
| Independent re-calculation of baskets and lift | 45 of 45 match, pass |
| Same product on 2+ lines of one order (V2) | 22 orders, handled with `DISTINCT` |
| Ties at the top-20 cut-off (V3) | 8 pairs at 4 co-purchases, 62 pairs tied at 3 |

**Bug found in the first version:** it ranked pairs with `TOP 20` and counted lines. Only 8 pairs reach 4 co-purchases, so ranks 9 to 20 came from 62 tied pairs and depended on how ties were broken. The first run showed 10 electronics + home appliances pairs in the top 20; sorting ties by `product_id` shows 17 of 20, only because electronics have the lowest product IDs. The query now uses `TOP 20 WITH TIES`, which returns all 70 pairs tied with the 20th.

## 6. Finding

**Product level.** Among the 70 pairs seen at least 3 times, electronics + home appliances looks dominant:

| category pair | recurring pairs | possible SKU pairs | co-purchases per possible pair |
|---|---|---|---|
| electronics + home_appliances | 27 | 357 | 0.72 |
| books + toys | 15 | 675 | 0.39 |
| furniture + garden | 8 | 621 | 0.36 |
| beauty + sports | 7 | 702 | 0.32 |
| beauty + fashion | 6 | 494 | 0.38 |

Electronics and home appliances have the smallest catalogs (21 and 17 products), so the same co-purchases land on fewer SKU pairs. Of 3,822 product pairs, 3,345 appear once and the best appear 4 times.

**Category level.** Lift separates five pairs from the rest:

| category_a | category_b | baskets_with_both | expected_baskets | confidence_a_to_b | lift |
|---|---|---|---|---|---|
| furniture | garden | 224 | 92.3 | 55.3 | 2.43 |
| books | toys | 260 | 115.6 | 56.3 | 2.25 |
| electronics | home_appliances | 257 | 114.5 | 56.7 | 2.24 |
| beauty | sports | 222 | 120.2 | 43.6 | 1.85 |
| beauty | fashion | 189 | 108.6 | 37.1 | 1.74 |

The other 40 category pairs all have lift of 0.83 or below. The five pairs match the five affinities built into the synthetic dataset, which validates the method.

## 7. Business meaning

- The co-purchase signal lives at **category level**: for example, 55% of baskets with furniture also contain garden, against about 23% of all baskets.
- Product-pair counts are too thin for SKU-level recommendations.
- Catalog size can make a category look stronger than it is; lift corrects for it. Electronics + home appliances is one of five equally strong pairs, not the winner.

## 8. Recommendation

1. **Start with category-level cross-sell:** furniture to garden, books to toys, electronics to home appliances, beauty to sports and fashion.
2. **A/B test before scaling.** Association is not causation: measure whether a widget lifts the attach rate above the baseline.
3. **Wait for volume before SKU-level rules.**
4. **Find out why they pair:** complementary use, or the same promotion? Session and promotion data would tell.

## Limitations

- Synthetic data with category affinities built in.
- Baskets have 2 to 4 items.
- The category view skips same-category pairs.
- No session or promotion data, so no causal conclusions.

## Sample output

- [`sample_output.csv`](./sample_output.csv): all 45 category pairs with support, confidence and lift
- [`sample_output_sku_pairs.csv`](./sample_output_sku_pairs.csv): the 70 product pairs returned by Query 1a

## Author

**Abu Hozaifa** | [LinkedIn](https://www.linkedin.com/in/abu-hozaifa-retail-analyst)
