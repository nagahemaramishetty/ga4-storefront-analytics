-- 17_checkout_abandon_return.sql
-- Purpose: for sessions that began checkout but did not reach payment, check whether
--          the user purchased in a LATER session (deferred) or never (lost).
-- Result (2026-10-28): ~23 MB scanned. 3,330 + 889 = 4,219 = funnel v2 checkout->payment loss.
--   New:       3,330 abandon | 50 bought later  (1.5% recovered)
--   Returning:   889 abandon | 102 bought later (11.5% recovered)
-- Finding: new-visitor checkout abandonment is lost demand (98.5%), not deferred.
WITH s AS (
  SELECT
    user_pseudo_id,
    session_start_ts,
    visitor_type,
    has_view_item,
    has_begin_checkout,
    has_add_payment_info,
    MAX(has_purchase) OVER (
      PARTITION BY user_pseudo_id
      ORDER BY session_start_ts
      ROWS BETWEEN 1 FOLLOWING AND UNBOUNDED FOLLOWING
    ) AS purchased_later
  FROM `ga4-storefront-analytics.p3_storefront.sessions`
)
SELECT
  visitor_type,
  COUNT(*)                                          AS checkout_abandon_sessions,
  COUNTIF(purchased_later = 1)                      AS purchased_in_later_session,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(purchased_later = 1), COUNT(*)), 1) AS pct_recovered_later
FROM s
WHERE has_view_item = 1
  AND has_begin_checkout = 1
  AND has_add_payment_info = 0
GROUP BY visitor_type
ORDER BY visitor_type;
