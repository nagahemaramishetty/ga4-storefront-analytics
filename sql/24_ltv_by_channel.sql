-- 24_ltv_by_channel.sql
-- Purpose: 30-day observed LTV per new user, by acquisition (first-touch) channel.
-- Population: truly new users first seen 2020-11-02 to 2021-01-02 -> all have a full
--             30-day window. Revenue = dedup orders; revenue, not margin.
-- Result (2026-10-28): ~19 MB scanned. Users sum to 173,023 (= sql/23 users_elig_d30).
--   Paid Search  9,482 (5.5%)  | buyers 1.65% | d0 $0.63 | d30 $1.48 | $/buyer 89.93 | idx 1.20
--   Organic     66,033 (38.2%) | buyers 1.60% | d0 $0.66 | d30 $1.31 | $/buyer 81.60 | idx 1.06
--   Unknown     31,458 (18.2%) | buyers 1.57% | d0 $0.69 | d30 $1.21 | $/buyer 76.85 | idx 0.98
--   Referral    24,968 (14.4%) | buyers 1.47% | d0 $0.65 | d30 $1.18 | $/buyer 80.61 | idx 0.96
--   Direct      41,082 (23.7%) | buyers 1.48% | d0 $0.60 | d30 $1.11 | $/buyer 74.80 | idx 0.90
-- Findings:
--   * Narrow spread ($1.11-$1.48). Paid highest via basket size, not buyer rate.
--   * Paid value grows +135% after d0 (vs +98% organic, +85% direct) -> paid users
--     return via other channels to buy; contradicts session view (sql/16: paid 0.59%).
--     -> last-touch undervalues paid; test in Q4.
--   * Unknown ~average (0.98) -> obfuscation looks roughly random across channels.
--   * Caveat: Paid ~156 buyers -> needs confidence intervals before budget decisions.
WITH first_seen AS (
  SELECT
    user_pseudo_id,
    MIN(session_date) AS first_date,
    ARRAY_AGG(STRUCT(ga_session_number, channel_first_touch AS channel)
              ORDER BY session_start_ts LIMIT 1)[SAFE_OFFSET(0)] AS fs
  FROM `ga4-storefront-analytics.p3_storefront.sessions`
  GROUP BY user_pseudo_id
),
new_users AS (
  SELECT
    user_pseudo_id,
    first_date,
    fs.channel AS acq_channel
  FROM first_seen
  WHERE fs.ga_session_number = 1
    AND first_date BETWEEN DATE '2020-11-02' AND DATE '2021-01-02'
),
user_rev AS (
  SELECT
    u.user_pseudo_id,
    u.acq_channel,
    SUM(IF(DATE_DIFF(o.order_date, u.first_date, DAY) = 0,   o.revenue_usd, 0)) AS rev_d0,
    SUM(IF(DATE_DIFF(o.order_date, u.first_date, DAY) <= 29, o.revenue_usd, 0)) AS rev_d30,
    COUNTIF(DATE_DIFF(o.order_date, u.first_date, DAY) <= 29)                   AS orders_d30
  FROM new_users AS u
  LEFT JOIN `ga4-storefront-analytics.p3_storefront.orders` AS o
    USING (user_pseudo_id)
  GROUP BY u.user_pseudo_id, u.acq_channel
),
agg AS (
  SELECT
    acq_channel,
    COUNT(*)                  AS users,
    COUNTIF(orders_d30 >= 1)  AS buyers_d30,
    SUM(rev_d0)               AS rev_d0,
    SUM(rev_d30)              AS rev_d30
  FROM user_rev
  GROUP BY acq_channel
)
SELECT
  acq_channel,
  users,
  ROUND(100 * users / SUM(users) OVER (), 1)                                  AS pct_of_users,
  ROUND(100 * SAFE_DIVIDE(buyers_d30, users), 2)                              AS buyer_rate_d30_pct,
  ROUND(SAFE_DIVIDE(rev_d0, users), 2)                                        AS ltv_d0,
  ROUND(SAFE_DIVIDE(rev_d30, users), 2)                                       AS ltv_d30,
  ROUND(SAFE_DIVIDE(rev_d30, buyers_d30), 2)                                  AS rev_per_buyer_d30,
  ROUND(SAFE_DIVIDE(rev_d30 / users,
                    SUM(rev_d30) OVER () / SUM(users) OVER ()), 2)            AS ltv_index,
  ROUND(100 * rev_d30 / SUM(rev_d30) OVER (), 1)                              AS pct_of_revenue_d30
FROM agg
ORDER BY ltv_d30 DESC;
