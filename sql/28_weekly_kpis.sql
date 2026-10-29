-- 28_weekly_kpis.sql
-- Purpose: weekly KPI trend with WoW change, 13 full weeks (Mon 2020-11-02 to Sun 2021-01-31).
-- Revenue = sessions x conversion x AOV. Conversion = purchasing sessions / sessions.
-- Result (2026-10-29): totals 357,504 sessions | 5,358 orders | $339,874 (excl. Nov 1).
--   Ramp: Nov 2 $21.8K (conv 1.00%) -> Dec 7 peak $59.4K (sessions +55%, conv 1.99%)
--   Cliff: Dec 21 -69% (sessions -34%, conv -0.59 pts, AOV -17%) -> shipping cutoff
--   Jan 4: sessions +42% but conv 0.56% (low) -> traffic back, buyers not
--   Dec 7 vs Jan 4: sessions -25%, revenue -84% -> conversion drives revenue swings
--   New-session share 67% -> 81% over holidays (mix effect on conversion)
--   Jan 25 week revenue/AOV broken (AOV $16) -> tracking gap, see sql/29-30
WITH s AS (
  SELECT
    DATE_TRUNC(session_date, WEEK(MONDAY)) AS wk,
    COUNT(*)                               AS sessions,
    COUNTIF(visitor_type = 'New')          AS new_sessions,
    SUM(has_purchase)                      AS purchasing_sessions
  FROM `ga4-storefront-analytics.p3_storefront.sessions`
  WHERE session_date >= DATE '2020-11-02'
  GROUP BY wk
),
o AS (
  SELECT
    DATE_TRUNC(order_date, WEEK(MONDAY)) AS wk,
    COUNT(*)                             AS orders,
    SUM(revenue_usd)                     AS revenue
  FROM `ga4-storefront-analytics.p3_storefront.orders`
  WHERE order_date >= DATE '2020-11-02'
  GROUP BY wk
),
w AS (
  SELECT
    wk,
    sessions,
    new_sessions,
    orders,
    revenue,
    SAFE_DIVIDE(purchasing_sessions, sessions) AS conv,
    SAFE_DIVIDE(revenue, orders)               AS aov
  FROM s
  JOIN o USING (wk)
)
SELECT
  wk                                                                           AS week_start,
  sessions,
  ROUND(100 * new_sessions / sessions, 1)                                      AS pct_new_sessions,
  orders,
  ROUND(revenue)                                                               AS revenue_usd,
  ROUND(100 * conv, 2)                                                         AS conv_pct,
  ROUND(aov, 2)                                                                AS aov_usd,
  ROUND(100 * SAFE_DIVIDE(revenue  - LAG(revenue)  OVER by_week, LAG(revenue)  OVER by_week), 1) AS revenue_wow_pct,
  ROUND(100 * SAFE_DIVIDE(sessions - LAG(sessions) OVER by_week, LAG(sessions) OVER by_week), 1) AS sessions_wow_pct,
  ROUND(100 * (conv - LAG(conv) OVER by_week), 2)                              AS conv_wow_pts,
  ROUND(100 * SAFE_DIVIDE(aov - LAG(aov) OVER by_week, LAG(aov) OVER by_week), 1) AS aov_wow_pct
FROM w
WINDOW by_week AS (ORDER BY wk)
ORDER BY week_start;
