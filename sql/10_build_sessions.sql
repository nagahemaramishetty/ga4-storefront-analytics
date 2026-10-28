-- 10_build_sessions.sql
-- Purpose: build one row per session (user_pseudo_id + ga_session_id) with segments
--          and funnel flags. Foundation for funnel, cohorts, LTV, attribution, trends.
-- Rules (see docs/metric_dictionary.md):
--   * Session key = user_pseudo_id + ga_session_id.
--   * Channel from medium; <Other>/(data deleted) -> 'Unknown'; NULL -> '(not captured)'.
--   * channel_session = first non-null event-level medium in the session (last-touch basis).
--   * channel_first_touch = traffic_source.medium (user's first acquisition).
-- Storage: CLUSTER BY, not PARTITION BY. Sandbox partitions expire 60 days after the
--          partition DATE, so 2020-21 partitions were deleted on write (table was empty).
-- Cost: ~1.64 GB, one-time.
CREATE OR REPLACE TABLE `ga4-storefront-analytics.p3_storefront.sessions`
CLUSTER BY session_date
AS
WITH events AS (
  SELECT
    user_pseudo_id,
    event_timestamp,
    PARSE_DATE('%Y%m%d', event_date)  AS event_date,
    event_name,
    device.category                   AS device_category,
    geo.country                       AS country,
    traffic_source.medium             AS first_touch_medium,
    (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'ga_session_id')     AS ga_session_id,
    (SELECT value.int_value    FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS ga_session_number,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium')            AS event_medium
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
),
sessions AS (
  SELECT
    user_pseudo_id,
    ga_session_id,
    MIN(event_date)                   AS session_date,
    MIN(event_timestamp)              AS session_start_ts,
    MAX(ga_session_number)            AS ga_session_number,
    ANY_VALUE(device_category)        AS device_category,
    ANY_VALUE(country)                AS country,
    ANY_VALUE(first_touch_medium)     AS first_touch_medium,
    ARRAY_AGG(event_medium IGNORE NULLS ORDER BY event_timestamp LIMIT 1)[SAFE_OFFSET(0)] AS session_medium,
    COUNT(*)                                          AS events,
    COUNTIF(event_name = 'session_start')             AS session_start_events,
    MAX(IF(event_name = 'view_item',        1, 0))    AS has_view_item,
    MAX(IF(event_name = 'add_to_cart',      1, 0))    AS has_add_to_cart,
    MAX(IF(event_name = 'begin_checkout',   1, 0))    AS has_begin_checkout,
    MAX(IF(event_name = 'add_payment_info', 1, 0))    AS has_add_payment_info,
    MAX(IF(event_name = 'purchase',         1, 0))    AS has_purchase
  FROM events
  WHERE ga_session_id IS NOT NULL
  GROUP BY user_pseudo_id, ga_session_id
)
SELECT
  CONCAT(user_pseudo_id, '-', CAST(ga_session_id AS STRING)) AS session_key,
  *,
  CASE
    WHEN session_medium IS NULL                          THEN '(not captured)'
    WHEN session_medium = 'organic'                      THEN 'Organic Search'
    WHEN session_medium = '(none)'                       THEN 'Direct'
    WHEN session_medium = 'referral'                     THEN 'Referral'
    WHEN session_medium = 'cpc'                          THEN 'Paid Search'
    WHEN session_medium IN ('<Other>', '(data deleted)') THEN 'Unknown'
    ELSE 'Other'
  END AS channel_session,
  CASE
    WHEN first_touch_medium IS NULL                          THEN '(not captured)'
    WHEN first_touch_medium = 'organic'                      THEN 'Organic Search'
    WHEN first_touch_medium = '(none)'                       THEN 'Direct'
    WHEN first_touch_medium = 'referral'                     THEN 'Referral'
    WHEN first_touch_medium = 'cpc'                          THEN 'Paid Search'
    WHEN first_touch_medium IN ('<Other>', '(data deleted)') THEN 'Unknown'
    ELSE 'Other'
  END AS channel_first_touch,
  CASE
    WHEN country IN ('United States', 'India', 'Canada', 'United Kingdom') THEN country
    ELSE 'Rest of world'
  END AS country_group,
  IF(ga_session_number = 1, 'New', 'Returning') AS visitor_type
FROM sessions;
