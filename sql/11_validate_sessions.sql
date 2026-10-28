-- 11_validate_sessions.sql
-- Purpose: sanity-check the sessions table before using it.
-- Result (2026-10-28):
--   sessions 360,129 = distinct keys 360,129 -> key unique
--   session_start_events 354,970 -> reconciles exactly to sql/01
--   sessions_without_start 5,272 (1.5%) -> likely began before Nov 1; kept
--   sessions_multi_start 105 -> tracking noise
--   sessions_no_channel 94,554 (26.3%) -> last-touch covers 73.7% of sessions
--   purchasing_sessions 4,848 -> session conversion rate 1.35%
SELECT
  COUNT(*)                                    AS sessions,
  COUNT(DISTINCT session_key)                 AS distinct_session_keys,
  SUM(session_start_events)                   AS session_start_events,
  COUNTIF(session_start_events = 0)           AS sessions_without_start,
  COUNTIF(session_start_events > 1)           AS sessions_multi_start,
  COUNTIF(channel_session = '(not captured)') AS sessions_no_channel,
  SUM(has_purchase)                           AS purchasing_sessions
FROM `ga4-storefront-analytics.p3_storefront.sessions`;
