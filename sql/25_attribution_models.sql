-- 25_attribution_models.sql
-- Purpose: credit deduplicated revenue to channels under three models and compare shares.
--   first_touch     = user's acquisition channel (channel_first_touch)
--   last_touch      = channel of the purchase session (channel_session)
--   last_non_direct = most recent session channel up to the purchase, skipping
--                     Direct and (not captured); falls back to last_touch if none.
-- Result (2026-10-28): each model sums to $340,647 (reconciles to sql/06, sql/22).
--   Referral:  23.1% first -> 53.5% last -> 55.2% LND (+30.4 pts) -> suspected artifact (sql/26)
--   Organic:   28.9% -> 32.0% -> 33.3% (robust across models)
--   Unknown:   23.7% -> 6.3%; Direct: 21.9% -> 6.7% -> 2.5%
--   Paid:      2.5% ($8,487) -> 0.9% ($3,114): last-touch undervalues paid 2.7x (cf. sql/24)
-- Fix: shift rounded after subtraction (float artifact 3.1000000000000014).
WITH s AS (
  SELECT
    session_key,
    user_pseudo_id,
    session_start_ts,
    channel_session,
    channel_first_touch,
    LAST_VALUE(
      IF(channel_session NOT IN ('Direct', '(not captured)'), channel_session, NULL) IGNORE NULLS
    ) OVER (
      PARTITION BY user_pseudo_id
      ORDER BY session_start_ts
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS last_non_direct
  FROM `ga4-storefront-analytics.p3_storefront.sessions`
),
o AS (
  SELECT
    o.order_key,
    o.revenue_usd,
    s.channel_first_touch                          AS first_touch,
    s.channel_session                              AS last_touch,
    COALESCE(s.last_non_direct, s.channel_session) AS last_non_direct
  FROM `ga4-storefront-analytics.p3_storefront.orders` AS o
  JOIN s USING (session_key)
),
long AS (
  SELECT m.model, m.channel, o.revenue_usd
  FROM o,
  UNNEST([
    STRUCT('first_touch'     AS model, o.first_touch     AS channel),
    STRUCT('last_touch'      AS model, o.last_touch      AS channel),
    STRUCT('last_non_direct' AS model, o.last_non_direct AS channel)
  ]) AS m
),
shares AS (
  SELECT
    channel,
    SUM(IF(model = 'first_touch',     revenue_usd, 0)) AS rev_first,
    SUM(IF(model = 'last_touch',      revenue_usd, 0)) AS rev_last,
    SUM(IF(model = 'last_non_direct', revenue_usd, 0)) AS rev_lnd
  FROM long
  GROUP BY channel
)
SELECT
  channel,
  ROUND(rev_first) AS rev_first_touch,
  ROUND(rev_last)  AS rev_last_touch,
  ROUND(rev_lnd)   AS rev_last_non_direct,
  ROUND(100 * rev_first / SUM(rev_first) OVER (), 1)                                     AS pct_first,
  ROUND(100 * rev_last  / SUM(rev_last)  OVER (), 1)                                     AS pct_last,
  ROUND(100 * rev_lnd   / SUM(rev_lnd)   OVER (), 1)                                     AS pct_last_non_direct,
  ROUND(100 * rev_last / SUM(rev_last) OVER () - 100 * rev_first / SUM(rev_first) OVER (), 1) AS shift_last_vs_first_pts
FROM shares
ORDER BY rev_first DESC;
