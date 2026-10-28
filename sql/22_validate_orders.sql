-- 22_validate_orders.sql
-- Purpose: reconcile the orders table to sql/06 and check it joins to sessions.
-- Result (2026-10-28): orders 5,372 = distinct keys 5,372 | revenue $340,647 (= sql/06)
--   unverified 906 (= sql/06) | buyers 4,419 (= purchase users, sql/01)
--   orders matched to a session 5,372 (100%) -> attribution covers all revenue.
SELECT
  COUNT(*)                                     AS orders,
  COUNT(DISTINCT o.order_key)                  AS distinct_order_keys,
  ROUND(SUM(o.revenue_usd), 2)                 AS revenue_usd,
  COUNTIF(o.is_unverified_id)                  AS unverified_orders,
  COUNT(DISTINCT o.user_pseudo_id)             AS buyers,
  COUNTIF(s.session_key IS NOT NULL)           AS orders_matched_to_session
FROM `ga4-storefront-analytics.p3_storefront.orders` AS o
LEFT JOIN `ga4-storefront-analytics.p3_storefront.sessions` AS s
  USING (session_key);
