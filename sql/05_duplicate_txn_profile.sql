-- 05_duplicate_txn_profile.sql
-- Purpose: check whether duplicated txn IDs are identical copies before deduplicating.
-- Result (2026-10-28): ~179 MB scanned.
--   duplicated_ids 326 | same_revenue 311 (95%) | same_user 311 (95%) | max_copies 4
--   seconds_apart quantiles: min 0.0009 | Q1 0.025 | median 0.036 | Q3 0.077 | max ~4.8M (~56 days)
-- Findings:
--   * 95% are double-fires (same user, same amount, ms apart) -> safe to collapse.
--   * ~15 IDs span different users/amounts (up to 56 days apart) -> ID collisions,
--     likely real separate orders -> do NOT collapse.
--   * Rule: order = unique (transaction_id, user_pseudo_id), earliest event kept.
WITH purchases AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    ecommerce.transaction_id          AS txn_id,
    ecommerce.purchase_revenue_in_usd AS revenue_usd
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
    AND ecommerce.transaction_id IS NOT NULL
    AND ecommerce.transaction_id != '(not set)'
),
per_id AS (
  SELECT
    txn_id,
    COUNT(*)                                            AS copies,
    COUNT(DISTINCT revenue_usd)                         AS distinct_revenues,
    COUNT(DISTINCT user_pseudo_id)                      AS distinct_users,
    (MAX(event_timestamp) - MIN(event_timestamp)) / 1e6 AS seconds_apart
  FROM purchases
  GROUP BY txn_id
  HAVING COUNT(*) > 1
)
SELECT
  COUNT(*)                              AS duplicated_ids,
  COUNTIF(distinct_revenues = 1)        AS same_revenue,
  COUNTIF(distinct_users = 1)           AS same_user,
  MAX(copies)                           AS max_copies,
  APPROX_QUANTILES(seconds_apart, 4)    AS seconds_apart_quantiles
FROM per_id;
