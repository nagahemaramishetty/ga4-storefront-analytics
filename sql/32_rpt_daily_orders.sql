-- 32_rpt_daily_orders.sql
-- Purpose: dashboard source. Orders and revenue per day x device x channel x country x visitor type.
-- Segments come from the order's session. revenue_complete = FALSE for Jan 26-31 (tracking gap, sql/29-30).
-- Result (2026-10-29): ~29 MB scanned; 2,697 rows -> Google Sheet rpt_daily_orders.
-- Reconciled in Sheets: orders 5,372 | revenue $340,647 | unverified 906.
SELECT
  o.order_date,
  DATE_TRUNC(o.order_date, WEEK(MONDAY)) AS week_start,
  s.device_category,
  CASE
    WHEN s.channel_session = 'Referral'
     AND ENDS_WITH(IFNULL(s.session_source, ''), 'googlemerchandisestore.com') THEN 'Self-referral'
    ELSE s.channel_session
  END AS channel,
  s.country_group,
  s.visitor_type,
  o.order_date <= DATE '2021-01-25'  AS revenue_complete,
  COUNT(*)                           AS orders,
  ROUND(SUM(o.revenue_usd), 2)       AS revenue_usd,
  COUNTIF(o.is_unverified_id)        AS unverified_orders
FROM `ga4-storefront-analytics.p3_storefront.orders` AS o
JOIN `ga4-storefront-analytics.p3_storefront.sessions` AS s
  USING (session_key)
GROUP BY 1, 2, 3, 4, 5, 6, 7
ORDER BY 1;
