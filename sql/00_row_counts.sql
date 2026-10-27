-- 00_row_counts.sql
-- Purpose: confirm all 92 daily tables exist and check daily volume for gaps/spikes.
-- Result (2026-10-27): 92/92 days present; ~85 MB scanned.
-- Findings: weekday/weekend cycle (weekends ~35% lower); peak late Nov/early Dec;
--           deep dip late Dec (holidays); partial recovery in Jan.
SELECT
  _TABLE_SUFFIX                      AS event_day,
  COUNT(*)                           AS events,
  COUNT(DISTINCT user_pseudo_id)     AS users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY event_day
ORDER BY event_day;
