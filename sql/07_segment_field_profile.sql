-- 07_segment_field_profile.sql
-- Purpose: check placeholder/obfuscation share in funnel segment fields (one pass).
-- Result (2026-10-28): ~168 MB scanned; 4,295,584 events; every list sums to the total.
-- Findings:
--   * device.category: desktop 58.2% | mobile 39.7% | tablet 2.2% -> clean, no placeholders.
--   * geo.country: top 10 = 74.6%; US 44.5% -> group US/India/Canada/UK/Rest of world.
--   * traffic_source.medium: organic 33.5% | (none) 23.0% | referral 18.1% | cpc 4.1%
--       | <Other> 13.9% + (data deleted) 7.3% = 21.2% -> keep as 'Unknown'.
--   * traffic_source.source: 33.5% placeholders -> do not segment by source.
--   * Self-referral: shop.googlemerchandisestore.com = 8.5% of events.
--   * traffic_source = first-touch (user level), not session level.
SELECT
  COUNT(*)                                        AS events,
  APPROX_TOP_COUNT(device.category, 10)           AS top_device,
  APPROX_TOP_COUNT(geo.country, 10)               AS top_country,
  APPROX_TOP_COUNT(traffic_source.medium, 10)     AS top_medium,
  APPROX_TOP_COUNT(traffic_source.source, 10)     AS top_source
FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131';
