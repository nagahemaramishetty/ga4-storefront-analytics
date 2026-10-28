-- 12_funnel_overall.sql
-- Purpose: closed session-level funnel, overall.
-- Result (2026-10-28):
--   sessions 360,129 | view_item 77,020 (21.39%) | add_to_cart 15,173 (19.70% of view)
--   begin_checkout 5,959 (39.27% of cart) | add_payment_info 3,858 (64.74%)
--   purchase 2,848 (73.82%) | closed conversion 0.79%
--   all purchase sessions 4,848 -> 2,000 (41%) skip at least one step
-- Finding: closed funnel misses 41% of purchasing sessions; diagnose (sql/13)
--          before naming the biggest drop-off.
WITH counts AS (
  SELECT
    COUNT(*)                                                      AS sessions,
    COUNTIF(has_view_item = 1)                                    AS s1_view_item,
    COUNTIF(has_view_item = 1 AND has_add_to_cart = 1)            AS s2_add_to_cart,
    COUNTIF(has_view_item = 1 AND has_add_to_cart = 1
            AND has_begin_checkout = 1)                           AS s3_begin_checkout,
    COUNTIF(has_view_item = 1 AND has_add_to_cart = 1
            AND has_begin_checkout = 1 AND has_add_payment_info = 1) AS s4_add_payment_info,
    COUNTIF(has_view_item = 1 AND has_add_to_cart = 1
            AND has_begin_checkout = 1 AND has_add_payment_info = 1
            AND has_purchase = 1)                                 AS s5_purchase,
    SUM(has_purchase)                                             AS all_purchase_sessions
  FROM `ga4-storefront-analytics.p3_storefront.sessions`
)
SELECT
  *,
  ROUND(100 * SAFE_DIVIDE(s1_view_item,        sessions),            2) AS pct_sessions_view_item,
  ROUND(100 * SAFE_DIVIDE(s2_add_to_cart,      s1_view_item),        2) AS pct_view_to_cart,
  ROUND(100 * SAFE_DIVIDE(s3_begin_checkout,   s2_add_to_cart),      2) AS pct_cart_to_checkout,
  ROUND(100 * SAFE_DIVIDE(s4_add_payment_info, s3_begin_checkout),   2) AS pct_checkout_to_payment,
  ROUND(100 * SAFE_DIVIDE(s5_purchase,         s4_add_payment_info), 2) AS pct_payment_to_purchase,
  ROUND(100 * SAFE_DIVIDE(s5_purchase,         sessions),            2) AS pct_closed_conversion,
  all_purchase_sessions - s5_purchase                                   AS purchases_skipping_steps
FROM counts;
