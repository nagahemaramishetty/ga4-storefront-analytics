-- 23_observed_ltv.sql
-- Purpose: observed LTV for truly new users (same population as sql/19-20),
--          by acquisition month, with per-user horizon eligibility (right-censoring).
-- Horizons: d0 = first-visit day; d7 = days 0-6; d30 = days 0-29; d60 = days 0-59.
-- Eligible if first_date + (horizon-1) <= 2021-01-31. Revenue = dedup orders; revenue, not margin.
-- Result (2026-10-28): ~16 MB scanned.
--   All: 258,897 users | d0 $0.54 | d7 $0.83 | d30 $1.23 (n=173,023) | d60 $1.51 (n=81,047)
--        rev/buyer d30 $79.53 | repeat buyers d30 10.6%
--   Nov (fully eligible, clean read): d0 $0.74 | d7 $1.01 | d30 $1.42 | d60 $1.50
--        -> 49% of 60-day value on day 0, 67% in week 1, 95% by day 30.
--        rev/buyer d30 $83.23 | repeat 11.0%
--   Dec: d0 $0.60 | d7 $0.94 | d30 $1.14 | d60 $1.59 (n=10,101, Dec 1-3 only -> not comparable)
--   Jan: d0 $0.30 | d7 $0.50 | d30 $0.27 (n=4,247, Jan 1-2 only -> not comparable)
-- Lessons: compare horizons only within fully eligible cohorts; always show eligible n.
--          Output alias renamed to `cohort` (same-name alias made ROLLUP total show NULL).
DECLARE data_end DATE DEFAULT DATE '2021-01-31';

WITH first_seen AS (
  SELECT
    user_pseudo_id,
    MIN(session_date) AS first_date,
    ARRAY_AGG(ga_session_number ORDER BY session_start_ts LIMIT 1)[SAFE_OFFSET(0)] AS first_session_number
  FROM `ga4-storefront-analytics.p3_storefront.sessions`
  GROUP BY user_pseudo_id
),
new_users AS (
  SELECT
    user_pseudo_id,
    first_date,
    FORMAT_DATE('%Y-%m', first_date) AS cohort_month
  FROM first_seen
  WHERE first_session_number = 1
    AND first_date >= DATE '2020-11-02'
),
user_rev AS (
  SELECT
    u.user_pseudo_id,
    u.first_date,
    u.cohort_month,
    SUM(IF(DATE_DIFF(o.order_date, u.first_date, DAY) = 0,   o.revenue_usd, 0)) AS rev_d0,
    SUM(IF(DATE_DIFF(o.order_date, u.first_date, DAY) <= 6,  o.revenue_usd, 0)) AS rev_d7,
    SUM(IF(DATE_DIFF(o.order_date, u.first_date, DAY) <= 29, o.revenue_usd, 0)) AS rev_d30,
    SUM(IF(DATE_DIFF(o.order_date, u.first_date, DAY) <= 59, o.revenue_usd, 0)) AS rev_d60,
    COUNTIF(DATE_DIFF(o.order_date, u.first_date, DAY) <= 29)                   AS orders_d30
  FROM new_users AS u
  LEFT JOIN `ga4-storefront-analytics.p3_storefront.orders` AS o
    USING (user_pseudo_id)
  GROUP BY u.user_pseudo_id, u.first_date, u.cohort_month
),
flagged AS (
  SELECT
    *,
    DATE_ADD(first_date, INTERVAL 6  DAY) <= data_end AS elig_d7,
    DATE_ADD(first_date, INTERVAL 29 DAY) <= data_end AS elig_d30,
    DATE_ADD(first_date, INTERVAL 59 DAY) <= data_end AS elig_d60
  FROM user_rev
)
SELECT
  IFNULL(cohort_month, 'All')                                                     AS cohort,
  COUNT(*)                                                                        AS users,
  ROUND(SAFE_DIVIDE(SUM(rev_d0), COUNT(*)), 2)                                    AS ltv_d0,
  ROUND(SAFE_DIVIDE(SUM(IF(elig_d7,  rev_d7,  0)), COUNTIF(elig_d7)),  2)         AS ltv_d7,
  ROUND(SAFE_DIVIDE(SUM(IF(elig_d30, rev_d30, 0)), COUNTIF(elig_d30)), 2)         AS ltv_d30,
  ROUND(SAFE_DIVIDE(SUM(IF(elig_d60, rev_d60, 0)), COUNTIF(elig_d60)), 2)         AS ltv_d60,
  COUNTIF(elig_d30)                                                               AS users_elig_d30,
  COUNTIF(elig_d60)                                                               AS users_elig_d60,
  ROUND(SAFE_DIVIDE(SUM(IF(elig_d30, rev_d30, 0)),
                    COUNTIF(elig_d30 AND orders_d30 >= 1)), 2)                    AS rev_per_buyer_d30,
  ROUND(100 * SAFE_DIVIDE(COUNTIF(elig_d30 AND orders_d30 >= 2),
                          COUNTIF(elig_d30 AND orders_d30 >= 1)), 1)              AS repeat_buyer_pct_d30
FROM flagged
GROUP BY ROLLUP(cohort_month)
ORDER BY cohort;
