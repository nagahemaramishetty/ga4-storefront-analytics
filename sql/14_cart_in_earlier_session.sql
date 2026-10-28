-- 14_cart_in_earlier_session.sql
-- Purpose: for purchase sessions with no add_to_cart, check whether the same user
--          carted in an EARLIER session (cross-session) or not (under-tracking).
-- Result (2026-10-28): ~18 MB scanned. Buckets reconcile: 252 + 881 + 867 = 2,000.
--   carted_earlier 252 (12.6%) -> cross-session journey
--   earlier_visits_but_no_cart 881 (44.1%) -> under-tracking
--   no_earlier_session_in_data 867 (43.4%):
--     returning, prior visit before Nov 1: 202 (10.1%) -> unknowable
--     first-ever visit: 665 (33.3%) -> under-tracking
-- Finding: >= 77% of the gap is add_to_cart not firing. Funnel v2 drops add_to_cart
--          as a required step; "fix add_to_cart tracking" -> recommendation.
-- Limit: user_pseudo_id is a cookie; cross-device carts look like no cart.
WITH s AS (
  SELECT
    user_pseudo_id,
    session_start_ts,
    has_add_to_cart,
    has_purchase,
    visitor_type,
    MAX(has_add_to_cart) OVER (
      PARTITION BY user_pseudo_id
      ORDER BY session_start_ts
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ) AS carted_in_earlier_session,
    COUNT(*) OVER (
      PARTITION BY user_pseudo_id
      ORDER BY session_start_ts
      ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    ) AS earlier_sessions_in_data
  FROM `ga4-storefront-analytics.p3_storefront.sessions`
)
SELECT
  COUNT(*)                                                         AS purchase_sessions_no_cart,
  COUNTIF(carted_in_earlier_session = 1)                           AS carted_earlier,
  COUNTIF(earlier_sessions_in_data > 0
          AND COALESCE(carted_in_earlier_session, 0) = 0)          AS earlier_visits_but_no_cart,
  COUNTIF(earlier_sessions_in_data = 0)                            AS no_earlier_session_in_data,
  COUNTIF(earlier_sessions_in_data = 0
          AND visitor_type = 'Returning')                          AS returning_but_prior_visit_before_nov1
FROM s
WHERE has_purchase = 1
  AND has_add_to_cart = 0;
