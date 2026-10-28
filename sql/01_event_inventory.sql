-- 01_event_inventory.sql
-- Purpose: list all event types with volume, to confirm funnel events exist.
-- Result (2026-10-27): 17 event types; ~138 MB scanned.
-- Findings:
--   * All funnel events present (view_item, add_to_cart, begin_checkout,
--     add_payment_info, purchase).
--   * view_item_list = 71 events vs 1.35M page_views -> under-tracked; excluded.
--   * add_shipping_info users (9,714) ~= begin_checkout users (9,715) -> redundant step.
--   * purchase: 5,692 events / 4,419 users -> check duplicates via transaction_id.
--   * first_visit ~= 1 per user (sanity check passes); ~96% of users are new.
SELECT
  event_name,
  COUNT(*)                         AS events,
  COUNT(DISTINCT user_pseudo_id)   AS users
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
GROUP BY event_name
ORDER BY events DESC;
