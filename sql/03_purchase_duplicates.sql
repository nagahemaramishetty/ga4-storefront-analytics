-- 03_purchase_duplicates.sql
-- Purpose: check purchase events for duplicate or missing transaction IDs.
-- Result (2026-10-28): ~61 MB scanned.
--   purchase_events 5,692 | distinct_txn_ids 4,452 | missing_txn_id 906 (15.9%)
--   missing_revenue 0 | raw_revenue_usd 362,165.00
-- Findings:
--   * 906 purchases have no usable txn ID -> cannot be deduped; caveat for revenue.
--   * ~335 events reuse an ID -> likely double-fired purchases.
--   * Revenue never null -> issue is identity, not value.
--   * Note: COUNT(DISTINCT) ignores NULL but counts '(not set)' as one value.
WITH purchases AS (
  SELECT
    ecommerce.transaction_id          AS txn_id,
    ecommerce.purchase_revenue_in_usd AS revenue_usd
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
)
SELECT
  COUNT(*)                                          AS purchase_events,
  COUNT(DISTINCT txn_id)                            AS distinct_txn_ids,
  COUNTIF(txn_id IS NULL OR txn_id = '(not set)')   AS missing_txn_id,
  COUNTIF(revenue_usd IS NULL)                      AS missing_revenue,
  ROUND(SUM(revenue_usd), 2)                        AS raw_revenue_usd
FROM purchases;
