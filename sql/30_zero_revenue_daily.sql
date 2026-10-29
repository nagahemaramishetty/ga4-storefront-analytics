-- 30_zero_revenue_daily.sql
-- Purpose: find the exact start date of the zero-revenue gap.
-- Result (2026-10-29): Jan 18-25 $0 orders 4-13% (normal); Jan 26 60% -> Jan 27-30 78-93%
--   -> Jan 31 100%. Gap starts Jan 26 (gradual ramp).
--   Jan 26-31: 282 orders, $2,193 recorded; at Jan 18-25 AOV ($65.77) ~ $18.5K expected
--   -> ~ $16K missing (estimate, not added to official revenue).
-- Rule: revenue/AOV from Jan 26-31 excluded from revenue trends; orders/conversion valid.
SELECT
  order_date,
  COUNT(*)                                             AS orders,
  COUNTIF(revenue_usd = 0)                             AS zero_revenue_orders,
  ROUND(100 * COUNTIF(revenue_usd = 0) / COUNT(*), 1)  AS pct_zero,
  ROUND(SUM(revenue_usd))                              AS revenue_usd
FROM `ga4-storefront-analytics.p3_storefront.orders`
WHERE order_date BETWEEN DATE '2021-01-18' AND DATE '2021-01-31'
GROUP BY order_date
ORDER BY order_date;
