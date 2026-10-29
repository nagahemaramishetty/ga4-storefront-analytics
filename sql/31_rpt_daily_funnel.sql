-- 31_rpt_daily_funnel.sql
-- Purpose: dashboard source. One row per day x device x channel x country x visitor type,
--          funnel v2 counts only (no rates), so the dashboard can compute ratio-of-sums.
-- Self-referral sessions get their own channel label so they don't inflate "Referral".
-- Result (2026-10-29): ~32 MB scanned; 15,112 rows -> Google Sheet rpt_daily_funnel.
-- Reconciled in Sheets: sessions 360,129 | funnel_purchase 4,698 | purchasing_sessions 4,848.
SELECT
  session_date,
  DATE_TRUNC(session_date, WEEK(MONDAY)) AS week_start,
  device_category,
  CASE
    WHEN channel_session = 'Referral'
     AND ENDS_WITH(IFNULL(session_source, ''), 'googlemerchandisestore.com') THEN 'Self-referral'
    ELSE channel_session
  END AS channel,
  country_group,
  visitor_type,
  COUNT(*)                                                   AS sessions,
  COUNTIF(has_view_item = 1)                                 AS view_item,
  COUNTIF(has_view_item = 1 AND has_begin_checkout = 1)      AS checkout,
  COUNTIF(has_view_item = 1 AND has_begin_checkout = 1
          AND has_add_payment_info = 1)                      AS payment,
  COUNTIF(has_view_item = 1 AND has_begin_checkout = 1
          AND has_add_payment_info = 1 AND has_purchase = 1) AS funnel_purchase,
  SUM(has_purchase)                                          AS purchasing_sessions
FROM `ga4-storefront-analytics.p3_storefront.sessions`
GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY 1;
