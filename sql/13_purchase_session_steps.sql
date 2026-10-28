-- 13_purchase_session_steps.sql
-- Purpose: for purchasing sessions, check which funnel steps are present,
--          to tell under-tracking apart from cross-session journeys.
-- Result (2026-10-28): ~16 MB scanned.
--   purchase_sessions 4,848 | with_view_item 4,698 (96.9%) | with_add_to_cart 2,848 (58.7%)
--   with_begin_checkout 4,845 (99.9%) | with_add_payment_info 4,845 (99.9%)
--   purchase_only 3 | returning_visitor 3,068 (63.3%)
-- Finding: add_to_cart is the only unreliable step; its 2,000 missing sessions are
--          exactly the gap in sql/12. Checkout/payment/purchase track reliably.
SELECT
  COUNT(*)                                     AS purchase_sessions,
  COUNTIF(has_view_item = 1)                   AS with_view_item,
  COUNTIF(has_add_to_cart = 1)                 AS with_add_to_cart,
  COUNTIF(has_begin_checkout = 1)              AS with_begin_checkout,
  COUNTIF(has_add_payment_info = 1)            AS with_add_payment_info,
  COUNTIF(has_view_item = 0 AND has_add_to_cart = 0
          AND has_begin_checkout = 0
          AND has_add_payment_info = 0)        AS purchase_only,
  COUNTIF(visitor_type = 'Returning')          AS returning_visitor
FROM `ga4-storefront-analytics.p3_storefront.sessions`
WHERE has_purchase = 1;
