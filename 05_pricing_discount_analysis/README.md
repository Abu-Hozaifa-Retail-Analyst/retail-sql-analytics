# Pricing & Discount Analysis

## 1. Business Question

Do lower-priced or more heavily discounted products sell in higher volume? Where does typical selling price sit relative to list price, by category, and does pricing variation appear meaningfully different across categories?

The analysis tests this question using transaction-level sold price versus product list price, summarized at category level.

## 2. Dataset & Analytical Grain

The analysis uses the repository's SQL Server retail dataset.

- **Line-item grain:** one row from `order_items`
- **Product attribute:** `products.base_price` as list/base price
- **Observed selling price:** `order_items.price`
- **Category:** `products.product_category_name`
- **Category summary:** median discount/markup percentage and item volume
- **Scope:** all available `order_items` joined to `products`; the query does not apply an order-status filter

The discount metric is calculated as `(base_price - sold_price) / base_price × 100`. A positive result means the item sold below list price; a negative result means it sold above list price.

## 3. Methodology

The SQL workflow is:

1. **Calculate line-item price variation** by comparing sold price with the product's base price.
2. **Calculate the median discount percentage by category** using `PERCENTILE_CONT(0.5)` rather than `AVG()`.
3. **Calculate item volume by category** using `COUNT(*)`.
4. **Join category-level pricing and volume statistics**.
5. **Order the result by items sold** to make the category comparison easy to review.

Using the median is appropriate for describing a typical transaction when outliers may distort the average. `PERCENTILE_CONT()` also provides a continuous percentile calculation rather than relying on a simple bucketed median.

## 4. SQL Implementation

The project demonstrates practical T-SQL techniques including:

- CTEs
- `PERCENTILE_CONT()`
- Window functions with `PARTITION BY`
- `COUNT(*)` aggregation
- `DISTINCT` for category-level percentile results
- Calculated business metrics
- Joining analytical result sets
- Category-level comparison

See [query.sql](./query.sql) for the implementation.

## 5. Validation

The analysis provides several useful validation points:

- The result contains **10 categories**, matching the categories represented in the sample output.
- Category item volumes sum to **7,624**, matching the repository's documented `order_items` row count.
- The same `discount_pct` definition is used for both the median calculation and the business interpretation.
- Median values are reported to one decimal place in the final output.
- The sample output preserves the category ranking produced by `ORDER BY items_sold DESC`.

### Metric interpretation check

Because the metric is calculated as `base_price - sold_price`, a negative percentage is not a discount. It indicates that the observed selling price was above the recorded base price. This distinction is important when presenting the result to business stakeholders.

Before production use, the analysis should also validate that `base_price` is non-zero and that `base_price` is genuinely a list/reference price rather than another pricing measure.

## 6. Observed Findings

Across all 10 categories, median price variation is tightly clustered between **-2.1% and -3.0%**.

Every category has a negative median value, meaning the typical observed selling price is slightly above the recorded base price rather than below it. The highest observed median markup is **home_appliances at -3.0%**, while **books is -2.1%**.

The category volumes also do not show a clear relationship with the small price differences in this dataset. For example, `beauty` has the highest item volume at **875**, while `home_appliances` has the largest median markup but **818** items sold; `books` has the smallest median markup and **794** items sold.

These results do **not** support a conclusion that discount depth is driving sales volume.

## 7. Business Implication

The main business insight is actually a **data-readiness finding**: this dataset does not appear to contain a meaningful promotional discount signal.

The observed price variation is small and generally above the recorded base price. Therefore, using this dataset to claim that discounts increase volume would create a misleading business narrative.

For a retailer, a genuine promotion analysis would need fields that distinguish normal price variation from an intentional markdown or campaign, such as discount amount, promotion ID, campaign ID, original price, promotional price, or promotion dates.

This is an important analyst skill: recognizing when the available data cannot reliably answer the business question is more valuable than forcing a conclusion from weak evidence.

## 8. Recommendations

### Business recommendations

- Do not use the current result as evidence that discounts drive category sales.
- Validate how `base_price` is defined with the business/pricing owner before interpreting the metric operationally.
- If promotional decisions are required, capture explicit promotion and discount attributes at transaction level.
- Once those fields are available, compare promoted versus non-promoted sales volume and revenue by category.

### Analytical next steps

- Add `discount_amount` or an equivalent explicit promotion field.
- Add `promotion_id` or `campaign_id` to connect transactions to specific campaigns.
- Analyze sales volume, revenue, margin, and units before/during/after promotions.
- Compare promotional performance using appropriate controls and time windows.
- Test price elasticity only after reliable price and demand history are available.

## 9. Limitations

- The current metric uses `base_price` as the reference price; its business meaning should be confirmed.
- Negative discount percentages represent observed selling prices above the recorded base price, so the metric should not automatically be described as a promotional discount.
- The analysis is category-level and does not estimate causal impact of pricing on volume.
- It does not calculate promotion lift, price elasticity, margin impact, or incremental sales.
- The query does not filter by `order_status`.
- No promotion, campaign, seasonality, channel, store, or customer-segment controls are included.
- Item volume is a count of `order_items` rows, so it represents line-item volume rather than necessarily unique units sold if quantities are modeled separately.
- The dataset is a practice/synthetic retail dataset, so the observed pricing behavior should not be presented as real-world market behavior.

## 10. Reproducibility

1. Complete the database setup described in [datasets/README.md](../datasets/README.md).
2. Select the `RetailAnalytics` database in SQL Server.
3. Run [query.sql](./query.sql).
4. Compare the result with [sample_output.csv](./sample_output.csv).

The query is written for **SQL Server / T-SQL**.

## 11. Portfolio Skills Demonstrated

- Retail pricing analysis
- Discount and markup interpretation
- SQL Server / T-SQL
- Percentile-based analysis
- Window functions
- Category-level aggregation
- Metric validation
- Data-readiness assessment
- Avoiding unsupported business conclusions
- Translating analytical limitations into data requirements

## 12. Project Files

| File | Purpose |
|---|---|
| [query.sql](./query.sql) | Main pricing and discount SQL analysis |
| [sample_output.csv](./sample_output.csv) | Category-level median price variation and item volume |