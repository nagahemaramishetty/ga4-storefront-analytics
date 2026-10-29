-- 33_rpt_attribution.sql
-- Purpose: dashboard source. Revenue by channel under first-touch, raw last-touch,
--          and cleaned last-touch (self-referrals skipped; logic from sql/27).
-- Result (2026-10-29): ~33 MB scanned; 20 rows -> Google Sheet p3_rpt_attribution.
-- Reconciled in Sheets: total $1,021,941 = 3 models x $340,647.
WITH s AS (
  SELECT
    session_key,
    user_pseudo_id,
    session_start_ts,
    channel_first_touch,
    channel_session,
    channel_session = 'Referral'
      AND ENDS_WITH(IFNULL(session_source, ''), 'googlemerchandisestore.com') AS is_self_ref
  FROM `ga4-storefront-analytics.p3_storefront.sessions`
),
s2 AS (
  SELECT
    *,
    LAST_VALUE(IF(is_self_ref, NULL, channel_session) IGNORE NULLS) OVER (
      PARTITION BY user_pseudo_id
      ORDER BY session_start_ts
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS last_touch_clean
  FROM s
),
o AS (
  SELECT
    o.revenue_usd,
    s2.channel_first_touch                                            AS first_touch,
    s2.channel_session                                                AS last_touch_raw,
    COALESCE(s2.last_touch_clean, 'Self-referral (no prior channel)') AS last_touch_clean
  FROM `ga4-storefront-analytics.p3_storefront.orders` AS o
  JOIN s2 USING (session_key)
)
SELECT
  m.model_order,
  m.model,
  m.channel,
  ROUND(SUM(o.revenue_usd), 2) AS revenue_usd
FROM o,
UNNEST([
  STRUCT(1 AS model_order, 'First-touch'          AS model, o.first_touch      AS channel),
  STRUCT(2 AS model_order, 'Last-touch (raw)'     AS model, o.last_touch_raw   AS channel),
  STRUCT(3 AS model_order, 'Last-touch (cleaned)' AS model, o.last_touch_clean AS channel)
]) AS m
GROUP BY 1, 2, 3
ORDER BY 1, revenue_usd DESC;
