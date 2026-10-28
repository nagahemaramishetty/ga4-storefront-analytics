-- 18_opportunity_sizing.sql
-- Purpose: size extra orders/revenue if NEW visitors closed part of the checkout->payment
--          gap to RETURNING visitors. Labeled scenarios, stated assumptions.
-- Assumptions:
--   1. Extra payment-stage sessions convert at new visitors' current payment->purchase rate.
--   2. Extra orders have the store's deduplicated AOV.
--   3. Session-level effects; 92-day window (Nov 2020 - Jan 2021, includes holiday peak).
-- Result (2026-10-28):
--   A: close 25% of gap: 43.7% -> 53.3% | +564 payment sessions | +383 orders | +$24,300 (7.1%)
--   B: close 50% of gap: 43.7% -> 62.8% | +1,129 payment sessions | +766 orders | +$48,599 (14.3%)
-- Do not annualize x4: window includes holiday peak.
DECLARE aov_usd FLOAT64 DEFAULT 63.41;  -- sql/06: $340,647 / 5,372 dedup orders

WITH f AS (
  SELECT
    visitor_type,
    COUNTIF(has_view_item = 1 AND has_begin_checkout = 1)                      AS checkout,
    COUNTIF(has_view_item = 1 AND has_begin_checkout = 1
            AND has_add_payment_info = 1)                                      AS payment,
    COUNTIF(has_view_item = 1 AND has_begin_checkout = 1
            AND has_add_payment_info = 1 AND has_purchase = 1)                 AS purchase
  FROM `ga4-storefront-analytics.p3_storefront.sessions`
  GROUP BY visitor_type
),
rates AS (
  SELECT
    MAX(IF(visitor_type = 'New', checkout, NULL))                              AS new_checkout,
    MAX(IF(visitor_type = 'New', SAFE_DIVIDE(payment, checkout), NULL))        AS new_rate,
    MAX(IF(visitor_type = 'New', SAFE_DIVIDE(purchase, payment), NULL))        AS new_pay_to_purchase,
    MAX(IF(visitor_type = 'Returning', SAFE_DIVIDE(payment, checkout), NULL))  AS returning_rate
  FROM f
)
SELECT
  sc.scenario,
  ROUND(100 * r.new_rate, 1)                                                   AS current_new_rate_pct,
  ROUND(100 * r.returning_rate, 1)                                             AS returning_rate_pct,
  ROUND(100 * (r.new_rate + sc.gap_share * (r.returning_rate - r.new_rate)), 1) AS target_new_rate_pct,
  ROUND(r.new_checkout * sc.gap_share * (r.returning_rate - r.new_rate))        AS extra_payment_sessions,
  ROUND(r.new_checkout * sc.gap_share * (r.returning_rate - r.new_rate)
        * r.new_pay_to_purchase)                                               AS extra_orders,
  ROUND(r.new_checkout * sc.gap_share * (r.returning_rate - r.new_rate)
        * r.new_pay_to_purchase * aov_usd)                                     AS extra_revenue_usd
FROM rates AS r,
UNNEST([
  STRUCT('A: close 25% of gap' AS scenario, 0.25 AS gap_share),
  STRUCT('B: close 50% of gap' AS scenario, 0.50 AS gap_share)
]) AS sc
ORDER BY sc.scenario;
