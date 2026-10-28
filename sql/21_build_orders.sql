-- 21_build_orders.sql
-- Purpose: one row per deduplicated order (rule from sql/06), with user, date, session key.
-- Rule: order = unique (transaction_id, user_pseudo_id), earliest event kept;
--       '(not set)' IDs cannot be deduped -> each event is its own order, flagged.
-- Cost: reads event_params for 92 days, one-time.
CREATE OR REPLACE TABLE `ga4-storefront-analytics.p3_storefront.orders`
CLUSTER BY order_date
AS
WITH purchases AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    PARSE_DATE('%Y%m%d', event_date)                                     AS order_date,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS ga_session_id,
    COALESCE(ecommerce.transaction_id, '(not set)')                      AS txn_id,
    ecommerce.purchase_revenue_in_usd                                    AS revenue_usd
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name = 'purchase'
),
ranked AS (
  SELECT
    *,
    CASE
      WHEN txn_id = '(not set)' THEN 1
      ELSE ROW_NUMBER() OVER (PARTITION BY txn_id, user_pseudo_id ORDER BY event_timestamp)
    END AS rn
  FROM purchases
)
SELECT
  CONCAT(txn_id, '|', user_pseudo_id, '|', CAST(event_timestamp AS STRING)) AS order_key,
  CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING))                AS session_key,
  user_pseudo_id,
  order_date,
  TIMESTAMP_MICROS(event_timestamp)                                         AS order_ts,
  txn_id,
  txn_id = '(not set)'                                                      AS is_unverified_id,
  revenue_usd
FROM ranked
WHERE rn = 1;
