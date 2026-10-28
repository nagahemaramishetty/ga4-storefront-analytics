-- 27_attribution_cleaned.sql
-- Purpose: attribution with self-referrals removed. A session whose source is the store's
--          own domain (*googlemerchandisestore.com) is not a channel; credit carries forward
--          to the user's last real channel before it.
--   last_touch_clean = last session channel, skipping self-referrals
--   lnd_clean        = last session channel, skipping self-referrals, Direct, (not captured)
--   No prior real channel -> 'Self-referral (no prior channel)'.
-- Result (2026-10-28): clean column sums to $340,647.
--   Organic:  28.9% first | 32.0% raw last | 42.0% clean last | 44.8% clean LND -> #1 in every model
--   Referral: 23.1% | 53.5% | 26.5% | 28.1% -> halved; remainder mostly <Other> (unverifiable)
--   Direct 21.9 | 6.7 | 8.7 | 4.3;  Unknown 23.7 | 6.3 | 7.9 | 9.3;  Paid 2.5 | 0.9 | 1.4 | 1.5
--   Unattributable: self-referral only 9.1%; (not captured) 2.3-3.7%
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
    LAST_VALUE(IF(is_self_ref, NULL, channel_session) IGNORE NULLS) OVER w AS last_touch_clean,
    LAST_VALUE(IF(is_self_ref OR channel_session IN ('Direct', '(not captured)'),
                  NULL, channel_session) IGNORE NULLS)                OVER w AS lnd_clean
  FROM s
  WINDOW w AS (
    PARTITION BY user_pseudo_id
    ORDER BY session_start_ts
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  )
),
o AS (
  SELECT
    o.revenue_usd,
    s2.channel_first_touch                                                    AS first_touch,
    s2.channel_session                                                        AS last_touch_raw,
    COALESCE(s2.last_touch_clean, 'Self-referral (no prior channel)')         AS last_touch_clean,
    COALESCE(s2.lnd_clean, s2.last_touch_clean, 'Self-referral (no prior channel)') AS lnd_clean
  FROM `ga4-storefront-analytics.p3_storefront.orders` AS o
  JOIN s2 USING (session_key)
),
long AS (
  SELECT m.model, m.channel, o.revenue_usd
  FROM o,
  UNNEST([
    STRUCT('first_touch'      AS model, o.first_touch      AS channel),
    STRUCT('last_touch_raw'   AS model, o.last_touch_raw   AS channel),
    STRUCT('last_touch_clean' AS model, o.last_touch_clean AS channel),
    STRUCT('lnd_clean'        AS model, o.lnd_clean        AS channel)
  ]) AS m
),
shares AS (
  SELECT
    channel,
    SUM(IF(model = 'first_touch',      revenue_usd, 0)) AS rev_first,
    SUM(IF(model = 'last_touch_raw',   revenue_usd, 0)) AS rev_last_raw,
    SUM(IF(model = 'last_touch_clean', revenue_usd, 0)) AS rev_last_clean,
    SUM(IF(model = 'lnd_clean',        revenue_usd, 0)) AS rev_lnd_clean
  FROM long
  GROUP BY channel
)
SELECT
  channel,
  ROUND(rev_last_clean)                                          AS rev_last_touch_clean,
  ROUND(100 * rev_first      / SUM(rev_first)      OVER (), 1)   AS pct_first,
  ROUND(100 * rev_last_raw   / SUM(rev_last_raw)   OVER (), 1)   AS pct_last_raw,
  ROUND(100 * rev_last_clean / SUM(rev_last_clean) OVER (), 1)   AS pct_last_clean,
  ROUND(100 * rev_lnd_clean  / SUM(rev_lnd_clean)  OVER (), 1)   AS pct_lnd_clean
FROM shares
ORDER BY rev_first DESC;
