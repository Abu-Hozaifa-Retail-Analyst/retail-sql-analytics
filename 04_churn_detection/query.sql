/* ============================================================
   Project: Churn Risk Detection
   Business Question: Which customers show a purchase gap that is
   meaningfully longer than their own historical pattern, and at what
   overdue ratio is it still worth trying to save them?

   Dialect: SQL Server (T-SQL)
   Database: RetailAnalytics (synthetic Olist-style data)

   Design decisions (see README, "Method"):
   - overdue_ratio = days since last order / the customer's own average gap
     between orders. Only repeat customers (2+ delivered orders) have a gap.
   - Query 1 shows who is overdue NOW. It lists every repeat customer with an
     action band, not only those above 2x.
   - Query 2 BACKTESTS the rule at month-end snapshots: for each snapshot it asks
     whether the customer ordered again in the next 90 days. That is what
     turns "2x" from a guess into a calibrated threshold.
   - Snapshots end 91+ days before the last order in the data, so every
     90-day outcome window is fully observed.
   ============================================================ */
USE RetailAnalytics;
GO

/* ------------------------------------------------------------
   Query 1a: overdue status of every repeat customer (right now)
   ------------------------------------------------------------ */
WITH delivered_orders AS (
    SELECT
        customers.customer_unique_id,
        orders.order_purchase_timestamp AS order_date
    FROM orders
    JOIN customers
        ON orders.customer_id = customers.customer_id
    WHERE orders.order_status = 'delivered'
),

order_gaps AS (
    -- Days since the same customer's previous order (NULL for a first order).
    SELECT
        customer_unique_id,
        order_date,
        DATEDIFF(DAY,
                 LAG(order_date) OVER (PARTITION BY customer_unique_id ORDER BY order_date),
                 order_date) AS gap_days
    FROM delivered_orders
),

customer_rhythm AS (
    -- Each repeat customer's normal gap and most recent order.
    SELECT
        customer_unique_id,
        AVG(gap_days * 1.0) AS avg_gap_days,
        MAX(order_date)     AS last_order_date
    FROM order_gaps
    GROUP BY customer_unique_id
    HAVING COUNT(gap_days) >= 1
),

data_end AS (
    -- "Today": the latest order in the dataset (a historical snapshot).
    SELECT MAX(order_purchase_timestamp) AS latest_order_date
    FROM orders
),

overdue_status AS (
    SELECT
        customer_rhythm.customer_unique_id,
        customer_rhythm.last_order_date,
        customer_rhythm.avg_gap_days,
        DATEDIFF(DAY, customer_rhythm.last_order_date, data_end.latest_order_date) AS days_since_last_order,
        DATEDIFF(DAY, customer_rhythm.last_order_date, data_end.latest_order_date) * 1.0
            / NULLIF(customer_rhythm.avg_gap_days, 0) AS overdue_ratio
    FROM customer_rhythm
    CROSS JOIN data_end
)

SELECT
    customer_unique_id,
    CAST(last_order_date AS DATE)       AS last_order_date,
    ROUND(avg_gap_days, 1)              AS avg_gap_days,
    days_since_last_order,
    ROUND(overdue_ratio, 1)             AS overdue_ratio,
    CASE WHEN overdue_ratio < 1 THEN 'On schedule'
         WHEN overdue_ratio < 2 THEN 'Early warning'
         WHEN overdue_ratio < 5 THEN 'Slipping'
         ELSE 'Likely lost' END         AS action_band
FROM overdue_status
ORDER BY overdue_ratio DESC, customer_unique_id;


/* ------------------------------------------------------------
   Query 1b: how many repeat customers sit in each band right now
   (same CTEs as Query 1a, final SELECT replaced)
   ------------------------------------------------------------ */
WITH delivered_orders AS (
    SELECT customers.customer_unique_id, orders.order_purchase_timestamp AS order_date
    FROM orders
    JOIN customers
        ON orders.customer_id = customers.customer_id
    WHERE orders.order_status = 'delivered'
),
order_gaps AS (
    SELECT customer_unique_id, order_date,
           DATEDIFF(DAY, LAG(order_date) OVER (PARTITION BY customer_unique_id ORDER BY order_date), order_date) AS gap_days
    FROM delivered_orders
),
customer_rhythm AS (
    SELECT customer_unique_id, AVG(gap_days * 1.0) AS avg_gap_days, MAX(order_date) AS last_order_date
    FROM order_gaps
    GROUP BY customer_unique_id
    HAVING COUNT(gap_days) >= 1
),
data_end AS (
    SELECT MAX(order_purchase_timestamp) AS latest_order_date FROM orders
),
overdue_status AS (
    SELECT customer_rhythm.customer_unique_id,
           DATEDIFF(DAY, customer_rhythm.last_order_date, data_end.latest_order_date) * 1.0
               / NULLIF(customer_rhythm.avg_gap_days, 0) AS overdue_ratio
    FROM customer_rhythm
    CROSS JOIN data_end
),
banded AS (
    SELECT overdue_ratio,
           CASE WHEN overdue_ratio < 1 THEN 1 WHEN overdue_ratio < 2 THEN 2
                WHEN overdue_ratio < 5 THEN 3 ELSE 4 END AS band_order,
           CASE WHEN overdue_ratio < 1 THEN 'On schedule' WHEN overdue_ratio < 2 THEN 'Early warning'
                WHEN overdue_ratio < 5 THEN 'Slipping' ELSE 'Likely lost' END AS action_band
    FROM overdue_status
)
SELECT
    action_band,
    COUNT(*)                                                   AS customers,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)         AS pct_of_repeat_customers,
    ROUND(AVG(overdue_ratio), 1)                               AS avg_overdue_ratio
FROM banded
GROUP BY band_order, action_band
ORDER BY band_order;


/* ------------------------------------------------------------
   Query 2: backtest. At each month-end snapshot, did overdue customers
   come back within the next 90 days?
   Results are saved in a temp table, then summarized twice.
   ------------------------------------------------------------ */
IF OBJECT_ID('tempdb..#snapshot_outcomes') IS NOT NULL DROP TABLE #snapshot_outcomes;

WITH delivered_orders AS (
    SELECT customers.customer_unique_id, orders.order_purchase_timestamp AS order_date
    FROM orders
    JOIN customers
        ON orders.customer_id = customers.customer_id
    WHERE orders.order_status = 'delivered'
),
order_gaps AS (
    SELECT customer_unique_id, order_date,
           DATEDIFF(DAY, LAG(order_date) OVER (PARTITION BY customer_unique_id ORDER BY order_date), order_date) AS gap_days
    FROM delivered_orders
),
snapshot_dates AS (
    -- Month-ends from 2023-04-30 to 2024-08-31 (recursive date spine).
    SELECT CAST('2023-04-30' AS DATE) AS snapshot_date
    UNION ALL
    SELECT EOMONTH(DATEADD(MONTH, 1, snapshot_date))
    FROM snapshot_dates
    WHERE snapshot_date < '2024-08-31'
),
customer_snapshots AS (
    -- What was known on each snapshot date: only orders up to that day.
    SELECT
        snapshot_dates.snapshot_date,
        order_gaps.customer_unique_id,
        AVG(order_gaps.gap_days * 1.0) AS avg_gap_days,
        MAX(order_gaps.order_date)     AS last_order_date
    FROM snapshot_dates
    JOIN order_gaps
        ON order_gaps.order_date < DATEADD(DAY, 1, snapshot_dates.snapshot_date)
    GROUP BY snapshot_dates.snapshot_date, order_gaps.customer_unique_id
    HAVING COUNT(order_gaps.gap_days) >= 1
)
SELECT
    customer_snapshots.snapshot_date,
    customer_snapshots.customer_unique_id,
    DATEDIFF(DAY, customer_snapshots.last_order_date, customer_snapshots.snapshot_date) * 1.0
        / NULLIF(customer_snapshots.avg_gap_days, 0) AS overdue_ratio,
    CASE WHEN EXISTS (
            SELECT 1
            FROM delivered_orders
            WHERE delivered_orders.customer_unique_id = customer_snapshots.customer_unique_id
              AND delivered_orders.order_date >= DATEADD(DAY, 1, customer_snapshots.snapshot_date)
              AND delivered_orders.order_date <  DATEADD(DAY, 91, customer_snapshots.snapshot_date)
         ) THEN 1 ELSE 0 END AS returned_within_90_days
INTO #snapshot_outcomes
FROM customer_snapshots;


-- Query 2a: 90-day return rate by overdue band
SELECT
    CASE WHEN overdue_ratio < 1   THEN '1. 0 to 1x'
         WHEN overdue_ratio < 1.5 THEN '2. 1 to 1.5x'
         WHEN overdue_ratio < 2   THEN '3. 1.5 to 2x'
         WHEN overdue_ratio < 3   THEN '4. 2 to 3x'
         WHEN overdue_ratio < 5   THEN '5. 3 to 5x'
         ELSE '6. 5x and above' END                                   AS overdue_band,
    COUNT(*)                                                           AS customer_snapshots,
    SUM(returned_within_90_days)                                       AS returned,
    ROUND(100.0 * SUM(returned_within_90_days) / COUNT(*), 1)          AS return_rate_pct
FROM #snapshot_outcomes
GROUP BY
    CASE WHEN overdue_ratio < 1   THEN '1. 0 to 1x'
         WHEN overdue_ratio < 1.5 THEN '2. 1 to 1.5x'
         WHEN overdue_ratio < 2   THEN '3. 1.5 to 2x'
         WHEN overdue_ratio < 3   THEN '4. 2 to 3x'
         WHEN overdue_ratio < 5   THEN '5. 3 to 5x'
         ELSE '6. 5x and above' END
ORDER BY overdue_band;


-- Query 2b: what each threshold would catch
--   pct_not_returning : of flagged snapshots, the share that did NOT come back
--   pct_non_returners_caught : of all snapshots that did not come back, the share flagged
SELECT
    thresholds.threshold,
    COUNT(*)                                                                         AS flagged_snapshots,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM #snapshot_outcomes), 1)           AS pct_of_snapshots_flagged,
    ROUND(100.0 * SUM(1 - #snapshot_outcomes.returned_within_90_days) / COUNT(*), 1) AS pct_not_returning,
    ROUND(100.0 * SUM(1 - #snapshot_outcomes.returned_within_90_days)
        / (SELECT SUM(1 - returned_within_90_days) FROM #snapshot_outcomes), 1)      AS pct_non_returners_caught
FROM (SELECT 1.0 AS threshold UNION ALL SELECT 1.5 UNION ALL SELECT 2.0
      UNION ALL SELECT 3.0 UNION ALL SELECT 5.0) AS thresholds
JOIN #snapshot_outcomes
    ON #snapshot_outcomes.overdue_ratio >= thresholds.threshold
GROUP BY thresholds.threshold
ORDER BY thresholds.threshold;


/* ------------------------------------------------------------
   Validation checks
   ------------------------------------------------------------ */

-- V1. Query 1a must return one row per repeat customer (574), and the Query 1b
--     customers must add up to the same number. Customers above 2x must be 381,
--     the number the original single-threshold query returned.

-- V2. Division-by-zero guard: no customer has two orders on the same day
--     (a zero gap). Expected: 0.
SELECT COUNT(*) AS zero_day_gaps
FROM (
    SELECT DATEDIFF(DAY,
               LAG(orders.order_purchase_timestamp) OVER (PARTITION BY customers.customer_unique_id ORDER BY orders.order_purchase_timestamp),
               orders.order_purchase_timestamp) AS gap_days
    FROM orders
    JOIN customers ON orders.customer_id = customers.customer_id
    WHERE orders.order_status = 'delivered'
) AS gaps
WHERE gap_days = 0;

-- V3. Every 90-day outcome window must lie inside the data:
--     last snapshot + 91 days must not pass the last order date.
SELECT DATEADD(DAY, 91, CAST('2024-08-31' AS DATE)) AS last_window_end,
       CAST(MAX(order_purchase_timestamp) AS DATE)  AS last_order_in_data
FROM orders;

-- V4. Backtest sanity: return rate should FALL as the overdue ratio rises
--     (see Query 2a). If it does not, the ratio is not a useful signal.

-- V5. Spot check one customer by hand against Query 1a.
SELECT customers.customer_unique_id, orders.order_purchase_timestamp
FROM orders
JOIN customers ON orders.customer_id = customers.customer_id
WHERE orders.order_status = 'delivered' AND customers.customer_unique_id = 'CUST102997'
ORDER BY orders.order_purchase_timestamp;
