-- 02_event_params_keys.sql
-- Purpose: discover keys inside event_params and their value types.
-- Scope: first week (20201101-20201107) - schema discovery; ~103 MB scanned.
-- Result (2026-10-28): 29 keys.
-- Findings:
--   * ga_session_id + ga_session_number on 100% of events (int) -> session key is safe.
--   * source/medium/campaign present on ~33% of events -> session-level last-touch
--     possible; must measure % of sessions with a known source.
--   * Mixed types: session_engaged (string+int), value & tax (int+double)
--     -> always COALESCE value types.
--   * all_data, dclid, gclid empty; page_referrer mostly null -> obfuscated, unused.
SELECT
  ep.key,
  COUNT(*)                                          AS occurrences,
  COUNTIF(ep.value.string_value IS NOT NULL)        AS string_vals,
  COUNTIF(ep.value.int_value    IS NOT NULL)        AS int_vals,
  COUNTIF(ep.value.double_value IS NOT NULL)        AS double_vals,
  COUNTIF(ep.value.float_value  IS NOT NULL)        AS float_vals
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`,
     UNNEST(event_params) AS ep
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20201107'
GROUP BY ep.key
ORDER BY occurrences DESC;
