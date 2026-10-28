-- 15_funnel_v2_overall.sql
-- Purpose: closed session funnel WITHOUT add_to_cart as a required step
--          (add_to_cart under-tracked: sql/13-14).
-- Result (2026-10-28):
--   sessions 360,129 | view_item 77,020 (21.39%) | begin_checkout 10,825 (14.05% of view)
--   add_payment_info 6,606 (61.03%) | purchase 4,698 (71.12%) | conversion 1.30%
--   purchases captured 96.91% (v1: 59%); 150 uncaptured = buyers without view_item (sql/13)
-- Note: conversion = product of step rates -> size opportunity by segment headroom.
WITH counts AS (
  SELECT
    COUNT(*)                                                       AS sessions,
    COUNTIF(has_view_item = 1)                                     AS s1_view_item,
    COUNTIF(has_view_item = 1 AND has_begin_checkout = 1)          AS s2_begin_checkout,
    COUNTIF(has_view_item = 1 AND has_begin_checkout = 1
            AND has_add_payment_info = 1)                          AS s3_add_payment_info,
    COUNTIF(has_view_item = 1 AND has_begin_checkout = 1
            AND has_add_payment_info = 1 AND has_purchase = 1)     AS s4_purchase,
    SUM(has_purchase)                                              AS all_purchase_sessions,
    COUNTIF(has_add_to_cart = 1)                                   AS tracked_cart_sessions
  FROM `ga4-storefront-analytics.p3_storefront.sessions`
)
SELECT
  *,
  ROUND(100 * SAFE_DIVIDE(s1_view_item,        sessions),              2) AS pct_sessions_view_item,
  ROUND(100 * SAFE_DIVIDE(s2_begin_checkout,   s1_view_item),          2) AS pct_view_to_checkout,
  ROUND(100 * SAFE_DIVIDE(s3_add_payment_info, s2_begin_checkout),     2) AS pct_checkout_to_payment,
  ROUND(100 * SAFE_DIVIDE(s4_purchase,         s3_add_payment_info),   2) AS pct_payment_to_purchase,
  ROUND(100 * SAFE_DIVIDE(s4_purchase,         sessions),              2) AS pct_closed_conversion,
  ROUND(100 * SAFE_DIVIDE(s4_purchase,         all_purchase_sessions), 2) AS pct_purchases_captured
FROM counts;
