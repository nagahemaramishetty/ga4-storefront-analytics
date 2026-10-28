-- 10_build_sessions.sql  (v2: adds session_source)
-- Purpose: build one row per session (user_pseudo_id + ga_session_id) with segments
--          and funnel flags. Foundation for funnel, cohorts, LTV, attribution, trends.
-- Rules (see docs/metric_dictionary.md):
--   * Session key = user_pseudo_id + ga_session_id.
--   * Channel from medium; <Other>/(data deleted) -> 'Unknown'; NULL -> '(not captured)'.
--   * session_medium/session_source = taken TOGETHER from the first event in the session
--     that has a medium (last-touch basis). v2 added session_source (2026-10-28) to test
--     referral inflation (sql/25-26).
--   * channel_first_touch = traffic_source.medium (user's first acquisition).
-- Storage: CLUSTER BY, not PARTITION BY (sandbox partition expiry deleted 2020-21 partitions).
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
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'medium')            AS event_medium,
    (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'source')            AS event_source
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
    ARRAY_AGG(
      IF(event_medium IS NOT NULL, STRUCT(event_medium AS medium, event_source AS source), NULL)
      IGNORE NULLS ORDER BY event_timestamp LIMIT 1
    )[SAFE_OFFSET(0)]                                 AS ms,
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
  * EXCEPT (ms),
  ms.medium AS session_medium,
  ms.source AS session_source,
  CASE
    WHEN ms.medium IS NULL                          THEN '(not captured)'
    WHEN ms.medium = 'organic'                      THEN 'Organic Search'
    WHEN ms.medium = '(none)'                       THEN 'Direct'
    WHEN ms.medium = 'referral'                     THEN 'Referral'
    WHEN ms.medium = 'cpc'                          THEN 'Paid Search'
    WHEN ms.medium IN ('<Other>', '(data deleted)') THEN 'Unknown'
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