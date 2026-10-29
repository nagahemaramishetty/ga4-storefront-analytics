-- 29_zero_revenue_check.sql
-- Purpose: test whether the Jan 25 week revenue drop is a data issue ($0 orders), by week.
-- Result (2026-10-29): $0 orders 0-11% in weeks Nov 2 - Jan 18 (210 of 5,015, ~4% background);
--   week of Jan 25: 240 of 343 (70%), median order $0 -> tracking/export gap.
-- Lesson: sql/03 checked revenue IS NULL only; missing values can be stored as 0.
-- Background ~4% $0 orders may be real (promo/free items, employee perks) - hypothesis only.
SELECT
  DATE_TRUNC(order_date, WEEK(MONDAY))                           AS week_start,
  COUNT(*)                                                       AS orders,
  COUNTIF(revenue_usd = 0)                                       AS zero_revenue_orders,
  COUNTIF(revenue_usd IS NULL)                                   AS null_revenue_orders,
  ROUND(100 * COUNTIF(revenue_usd = 0) / COUNT(*), 1)            AS pct_zero,
  ROUND(SUM(revenue_usd))                                        AS revenue_usd,
  ROUND(APPROX_QUANTILES(revenue_usd, 2)[OFFSET(1)], 2)          AS median_order_usd
FROM `ga4-storefront-analytics.p3_storefront.orders`
WHERE order_date >= DATE '2020-11-02'
GROUP BY week_start
ORDER BY week_start;
