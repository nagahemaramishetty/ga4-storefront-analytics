-- 20_retention_buyers_vs_browsers.sql
-- Purpose: pooled weekly retention, split by whether the user purchased in their cohort week.
-- Pooled = sum over cohorts where week N is observable (right-censoring respected).
-- Result (2026-10-28): ~18 MB scanned. 2,700 + 256,197 = 258,897 (reconciles to sql/19).
--   Bought in week 0:  W1 21.15% | W2 8.51% | W4 3.49% | W8 1.92%
--   Did not buy:       W1  3.60% | W2 1.47% | W4 0.88% | W8 0.28%
--   Ratio ~6x (W8 6.9x). Correlation, not causation; W1 partly order-tracking visits.
--   Not added to opportunity sizing (would double count on a correlation).
DECLARE last_week DATE DEFAULT DATE '2021-01-25';

WITH first_seen AS (
  SELECT
    user_pseudo_id,
    MIN(session_date) AS first_date,
    ARRAY_AGG(ga_session_number ORDER BY session_start_ts LIMIT 1)[SAFE_OFFSET(0)] AS first_session_number
  FROM `ga4-storefront-analytics.p3_storefront.sessions`
  GROUP BY user_pseudo_id
),
cohorts AS (
  SELECT user_pseudo_id, DATE_TRUNC(first_date, WEEK(MONDAY)) AS cohort_week
  FROM first_seen
  WHERE first_session_number = 1
    AND first_date >= DATE '2020-11-02'
),
activity AS (
  SELECT
    user_pseudo_id,
    DATE_TRUNC(session_date, WEEK(MONDAY)) AS active_week,
    MAX(has_purchase)                      AS purchased
  FROM `ga4-storefront-analytics.p3_storefront.sessions`
  GROUP BY user_pseudo_id, active_week
),
joined AS (
  SELECT
    c.cohort_week,
    c.user_pseudo_id,
    DIV(DATE_DIFF(a.active_week, c.cohort_week, DAY), 7) AS week_n,
    a.purchased
  FROM cohorts AS c
  JOIN activity AS a USING (user_pseudo_id)
  WHERE a.active_week >= c.cohort_week
),
users AS (
  SELECT
    cohort_week,
    user_pseudo_id,
    MAX(IF(week_n = 0, purchased, 0)) AS bought_week0,
    MAX(IF(week_n = 1, 1, 0))         AS a1,
    MAX(IF(week_n = 2, 1, 0))         AS a2,
    MAX(IF(week_n = 4, 1, 0))         AS a4,
    MAX(IF(week_n = 8, 1, 0))         AS a8
  FROM joined
  GROUP BY cohort_week, user_pseudo_id
)
SELECT
  IF(bought_week0 = 1, 'Bought in week 0', 'Did not buy in week 0') AS segment,
  COUNT(*) AS users,
  ROUND(100 * SAFE_DIVIDE(SUM(IF(DATE_ADD(cohort_week, INTERVAL 1 WEEK) <= last_week, a1, 0)),
                          COUNTIF(DATE_ADD(cohort_week, INTERVAL 1 WEEK) <= last_week)), 2) AS w1_pct,
  ROUND(100 * SAFE_DIVIDE(SUM(IF(DATE_ADD(cohort_week, INTERVAL 2 WEEK) <= last_week, a2, 0)),
                          COUNTIF(DATE_ADD(cohort_week, INTERVAL 2 WEEK) <= last_week)), 2) AS w2_pct,
  ROUND(100 * SAFE_DIVIDE(SUM(IF(DATE_ADD(cohort_week, INTERVAL 4 WEEK) <= last_week, a4, 0)),
                          COUNTIF(DATE_ADD(cohort_week, INTERVAL 4 WEEK) <= last_week)), 2) AS w4_pct,
  ROUND(100 * SAFE_DIVIDE(SUM(IF(DATE_ADD(cohort_week, INTERVAL 8 WEEK) <= last_week, a8, 0)),
                          COUNTIF(DATE_ADD(cohort_week, INTERVAL 8 WEEK) <= last_week)), 2) AS w8_pct
FROM users
GROUP BY segment
ORDER BY segment;
