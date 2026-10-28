-- 06_revenue_dedup.sql
-- Purpose: apply the dedup rule and compare raw vs deduplicated orders and revenue.
-- Rule: one order = one (transaction_id, user_pseudo_id) pair, earliest event kept.
--       '(not set)' IDs cannot be deduped, so each event counts as its own order.
-- Result (2026-10-28): ~179 MB scanned.
--   raw: 5,692 events | $362,165    dedup: 5,372 orders | $340,647
--   removed: 320 double-fires | $21,518 (5.9% of raw)
--   missing-ID orders: 906 | $31,817 (9.3% of dedup revenue, unverifiable)
-- Reconciliation: 5,372 = 906 + 4,125 unique + 341 duplicated-ID pairs (326 ids + ~15 collisions).
WITH purchases AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    COALESCE(ecommerce.transaction_id, '(not set)') AS txn_id,
    ecommerce.purchase_revenue_in_usd               AS revenue_usd
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),
ranked AS (
  SELECT
    *,
    CASE
      WHEN txn_id = '(not set)' THEN 1
      ELSE ROW_NUMBER() OVER (
             PARTITION BY txn_id, user_pseudo_id
             ORDER BY event_timestamp)
    END AS rn
  FROM purchases
)
SELECT
  COUNT(*)                                                           AS raw_events,
  ROUND(SUM(revenue_usd), 2)                                         AS raw_revenue_usd,
  COUNTIF(rn = 1)                                                    AS dedup_orders,
  ROUND(SUM(IF(rn = 1, revenue_usd, 0)), 2)                          AS dedup_revenue_usd,
  COUNTIF(rn = 1 AND txn_id = '(not set)')                           AS orders_missing_id,
  ROUND(SUM(IF(rn = 1 AND txn_id = '(not set)', revenue_usd, 0)), 2) AS revenue_missing_id_usd
FROM ranked;
