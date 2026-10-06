# Market Basket Analysis

## 1. Business Question

Which products are commonly bought together, so we can identify practical cross-sell opportunities and improve store or website merchandising?

The analysis focuses on **co-purchase frequency**: how often two distinct products appear in the same order.

## 2. Dataset & Analytical Grain

The analysis uses the repository's SQL Server retail dataset.

- **Basket grain:** `order_id`
- **Product grain:** `product_id`
- **Pair grain:** one unique unordered product pair within an order
- **Source table:** `order_items`
- **Product attributes:** `products.product_category_name`
- **Scope:** all rows available in `order_items`; the current query does not add an `order_status` filter

The dataset contains 239 distinct products. Because the analysis counts product pairs within an order, a pair represents products that co-occurred in the same basket; it does not by itself establish that one product caused the purchase of another.

## 3. Methodology

The SQL workflow is:

1. **Self-join `order_items` on `order_id`** to compare products appearing in the same basket.
2. Use `a.product_id < b.product_id` to:
   - exclude self-pairs; and
   - count each unordered pair once rather than counting both A-B and B-A.
3. **Group by the two product IDs** and count co-purchases.
4. **Join `products` twice** to attach category names to both sides of the pair.
5. **Return the top 20 pairs** ordered by co-purchase frequency.

This is a frequency-based market basket analysis rather than a full association-rule model.

## 4. SQL Implementation

The project demonstrates practical T-SQL techniques including:

- Self-joins
- Join conditions for pair de-duplication
- `GROUP BY`
- `COUNT(*)`
- Multiple joins to the same dimension table
- `TOP`
- `ORDER BY`
- CTE-based query organization

See [`query.sql`](./query.sql) for the implementation.

## 5. Validation

The query design provides several important structural controls:

- `a.product_id < b.product_id` prevents a product from pairing with itself.
- The same condition ensures A-B and B-A are not counted as separate pairs.
- Grouping occurs at the product-pair grain.
- Product IDs are joined back to `products` to retrieve category labels.

The checked sample output also contains 20 rows, matching the query's `TOP 20` requirement.

A production implementation should additionally validate duplicate line-item behavior, order-status scope, and whether repeated quantities of the same product should influence pair frequency.

## 6. Observed Findings

In the current `sample_output.csv`, **10 of the top 20 product pairs (50%) are electronics + home_appliances pairs**.

The strongest pairs appear at frequencies of 5 or 4 co-purchases, while the lower-ranked pairs appear 3 times. Other visible category combinations include fashion + beauty, toys + books, furniture + garden, and sports + sports.

This concentration suggests that the strongest observed co-purchase signal in this sample is at the **category-combination level**, rather than being limited to one individual SKU pair.

The finding should be treated as a descriptive signal: frequency alone does not establish statistical significance, customer intent, complementarity, or causal impact.

## 7. Business Implication

The electronics + home_appliances concentration provides a useful hypothesis for cross-selling.

For example, a retailer could investigate whether customers purchasing electronics frequently have a complementary home-appliance purchase opportunity. However, the current analysis cannot determine whether these products are genuinely complementary, simply purchased during the same shopping occasion, or influenced by a common promotion or seasonal event.

This distinction matters because the appropriate business action would differ between a genuine product complement and a temporary co-purchase pattern.

## 8. Recommendations

### Immediate business tests

- Test **category-level cross-sell placements** for electronics and home_appliances.
- Review the individual SKU pairs behind the category signal before creating specific recommendations.
- Compare co-purchase patterns across stores, channels, and time periods if those dimensions become available.
- Check whether promotions or seasonal events explain the observed concentration.

### Analytical next step

Extend the analysis from raw frequency to association-rule metrics such as:

- **Support** — how common the pair is across all baskets.
- **Confidence** — how often B appears when A appears.
- **Lift** — whether A and B co-occur more often than expected from their individual frequencies.

These measures would provide stronger evidence for recommendation and merchandising decisions than frequency alone.

## 9. Limitations

- The current analysis ranks pairs by frequency only; it does not calculate support, confidence, or lift.
- Several top pairs have relatively low observed frequencies (3–5), so the signal should be validated on a larger or longer transaction history before operational use.
- The query does not explicitly filter `order_status`.
- The analysis does not control for promotions, seasonality, channel, store, or customer segment.
- Co-purchase frequency is descriptive and does not establish causality.
- The dataset is a practice/synthetic retail dataset, so findings should not be presented as real-world market behavior.
- The current query counts matching `order_items` rows, so duplicate line items or multiple quantities require explicit business-rule validation if the analysis is adapted for production.

## 10. Reproducibility

1. Complete the database setup described in [`datasets/README.md`](../datasets/README.md).
2. Select the `RetailAnalytics` database in SQL Server.
3. Run [`query.sql`](./query.sql).
4. Compare the result with [`sample_output.csv`](./sample_output.csv).

The query is written for **SQL Server / T-SQL**.

## 11. Portfolio Skills Demonstrated

- Retail basket and cross-sell analysis
- SQL Server / T-SQL
- Self-join design
- Product-level and category-level analysis
- Data-grain awareness
- Analytical validation
- Business interpretation
- Merchandising and recommendation thinking
- Translating descriptive SQL findings into testable business actions

## 12. Project Files

| File | Purpose |
|---|---|
| [`query.sql`](./query.sql) | Main market basket SQL analysis |
| [`sample_output.csv`](./sample_output.csv) | Sample result containing the top 20 product pairs |
