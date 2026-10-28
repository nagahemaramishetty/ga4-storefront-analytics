-- 26_referral_sources.sql
-- Purpose: test whether last-touch Referral revenue (sql/25: 53.5%) is inflated by self-referrals.
-- Result (2026-10-28): 15 rows sum to $182,401 = all last-touch Referral revenue.
--   Own domains (shop./bare/admin. googlemerchandisestore.com): $109,819 (60.2%)
--     -> ~32% of ALL revenue credited to the store referring to itself.
--   <Other> (obfuscated): $68,404 (37.5%)
--   Real external referrals: $4,178 (2.3%); incl. Google intranet/perks -> employee buyers.
-- Finding: Referral last-touch share is a self-referral artifact.
-- Recommendation: add own domains to GA4 "unwanted referrals"; re-attribute (sql/27).
SELECT
  s.session_source,
  COUNT(*)                                                             AS orders,
  ROUND(SUM(o.revenue_usd))                                            AS revenue_usd,
  ROUND(100 * SUM(o.revenue_usd) / SUM(SUM(o.revenue_usd)) OVER (), 1) AS pct_of_referral_revenue
FROM `ga4-storefront-analytics.p3_storefront.orders` AS o
JOIN `ga4-storefront-analytics.p3_storefront.sessions` AS s
  USING (session_key)
WHERE s.channel_session = 'Referral'
GROUP BY s.session_source
ORDER BY revenue_usd DESC
LIMIT 15;
