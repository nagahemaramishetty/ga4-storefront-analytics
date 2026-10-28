-- 16_funnel_by_segment.sql
-- Purpose: funnel v2 for every segment in one pass (unpivot via UNNEST of STRUCTs).
-- Result (2026-10-28): ~29 MB scanned; 22 rows.
-- Findings:
--   * Device flat: desktop 1.28% | mobile 1.35% | tablet 1.25% -> device is not the lever.
--   * Country flat: 1.28%-1.43%. (Unusually flat -> possible obfuscation effect; caveat.)
--   * Visitor type: New 0.67% vs Returning 2.97% (4.4x); checkout->payment 43.7% vs 81.9%.
--     New = 72.5% of sessions but 37% of purchases.
--   * Session channel conversion: Referral 2.86% | Organic 1.57% | Unknown 0.97% |
--     Direct 0.79% | Paid 0.59%; checkout->payment ranges 34.8% (Paid) to 76.3% (Referral).
--   * Payment->purchase stable (68-76%) everywhere; checkout->payment varies most (35-82%)
--     -> step with proven headroom.
--   * (not captured) channel: 94,554 sessions, 6.8% view, 1 purchase -> low-intent;
--     last-touch gap barely affects purchases.
--   * Referral likely inflated by self-referral (sql/07) -> test in Q4.
--   * Open: is new-visitor checkout drop-off lost or deferred? -> sql/17.
WITH long AS (
  SELECT
    seg.dimension,
    seg.value,
    s.has_view_item,
    s.has_begin_checkout,
    s.has_add_payment_info,
    s.has_purchase
  FROM `ga4-storefront-analytics.p3_storefront.sessions` AS s,
  UNNEST([
    STRUCT('1_device'              AS dimension, s.device_category     AS value),
    STRUCT('2_channel_session'     AS dimension, s.channel_session     AS value),
    STRUCT('3_channel_first_touch' AS dimension, s.channel_first_touch AS value),
    STRUCT('4_country'             AS dimension, s.country_group       AS value),
    STRUCT('5_visitor_type'        AS dimension, s.visitor_type        AS value)
  ]) AS seg
),
counts AS (
  SELECT
    dimension,
    value,
    COUNT(*)                                                    AS sessions,
    COUNTIF(has_view_item = 1)                                  AS s1_view_item,
    COUNTIF(has_view_item = 1 AND has_begin_checkout = 1)       AS s2_checkout,
    COUNTIF(has_view_item = 1 AND has_begin_checkout = 1
            AND has_add_payment_info = 1)                       AS s3_payment,
    COUNTIF(has_view_item = 1 AND has_begin_checkout = 1
            AND has_add_payment_info = 1 AND has_purchase = 1)  AS s4_purchase
  FROM long
  GROUP BY dimension, value
)
SELECT
  dimension,
  value,
  sessions,
  ROUND(100 * SAFE_DIVIDE(sessions, SUM(sessions) OVER (PARTITION BY dimension)), 1) AS pct_of_sessions,
  ROUND(100 * SAFE_DIVIDE(s1_view_item, sessions),     1) AS pct_view_item,
  ROUND(100 * SAFE_DIVIDE(s2_checkout,  s1_view_item), 1) AS pct_view_to_checkout,
  ROUND(100 * SAFE_DIVIDE(s3_payment,   s2_checkout),  1) AS pct_checkout_to_payment,
  ROUND(100 * SAFE_DIVIDE(s4_purchase,  s3_payment),   1) AS pct_payment_to_purchase,
  ROUND(100 * SAFE_DIVIDE(s4_purchase,  sessions),     2) AS pct_conversion,
  s4_purchase AS purchases
FROM counts
ORDER BY dimension, sessions DESC;
