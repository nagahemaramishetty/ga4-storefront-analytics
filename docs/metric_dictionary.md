# Metric Dictionary (v1)

Dataset: `bigquery-public-data.ga4_obfuscated_sample_ecommerce` (Nov 1, 2020 – Jan 31, 2021, 92 days).
Every metric states numerator, denominator, grain, and rules. Rules marked [Q0] come from data-quality profiling (sql/00–07).

## Core entities

| Entity | Definition | Notes |
|---|---|---|
| User | distinct `user_pseudo_id` | A browser/device cookie, not a person. One person on 2 devices = 2 users. |
| Session | distinct (`user_pseudo_id`, `ga_session_id`) | `ga_session_id` is not unique across users. Present on 100% of events [Q0, sql/02]. Reconcile to ~355K `session_start` events [sql/01]. |
| Order | distinct (`ecommerce.transaction_id`, `user_pseudo_id`), earliest event kept | Collapses double-fired purchases; keeps ID collisions across users as separate orders. `'(not set)'` IDs: each event = one order, flagged [Q0, sql/05–06]. |

## Metrics

| Metric | Numerator | Denominator | Grain | Why |
|---|---|---|---|---|
| Session conversion rate | sessions with ≥1 order | all sessions | session | Purchase intent lives within a visit; fair unit for UX/funnel. |
| User conversion rate | users with ≥1 order | all users | user | Used for LTV and cohorts. Always label which rate is shown. |
| Funnel step rate | sessions reaching step N (and N−1) | sessions reaching step N−1 | session | Closed funnel; shows where the drop happens. |
| Cart abandonment | sessions with add_to_cart and no purchase | sessions with add_to_cart | session | Clear owner (checkout). |
| Revenue | SUM(`ecommerce.purchase_revenue_in_usd`) over deduplicated orders | — | order | Raw events overstate revenue by 5.9% [sql/06]. |
| AOV | revenue | orders | order | Separates "fewer orders" from "smaller orders". |
| Week-N retention | cohort users active in week N | cohort size (users first seen in week 0) | weekly cohort | Fixed denominator. ~96% of users are new [sql/01], so expect low retention. |
| Observed LTV | cumulative revenue per cohort user to day X | cohort users | weekly cohort | "Observed", not predicted: only 92 days of data. |
| Channel attributed revenue | revenue credited to channel under model M | total revenue | order | Shown under first-touch and last-touch to expose model sensitivity. |
| WoW change | this week − last week | last week | ISO week | Weekly grain removes the weekday/weekend cycle (weekends ~35% lower) [sql/00]. |

## Funnel (v1, session level, closed)
`view_item → add_to_cart → begin_checkout → add_payment_info → purchase`
- Excluded `view_item_list`: under-tracked (71 events vs 1.35M page_views) [sql/01].
- Excluded `add_shipping_info`: users ≈ `begin_checkout` users (9,714 vs 9,715), redundant [sql/01].

## Segments
- **Device:** desktop / mobile / tablet (clean). Tablet = 2.2% of events → flag as noisy.
- **Country:** US / India / Canada / UK / Rest of world.
- **Channel (from medium):** Organic Search (organic), Direct ((none)), Referral, Paid Search (cpc), Unknown (`<Other>`, `(data deleted)` = 21.2%). Unknown is kept, never dropped.
- **Not used:** `traffic_source.source` (33.5% placeholders); `page_referrer` (mostly null).

## Data rules [Q0]
1. Always filter `_TABLE_SUFFIX` and select only needed columns.
2. Numeric `event_params`: `COALESCE(int_value, double_value, float_value)` (mixed types in `value`, `tax`, `session_engaged`).
3. Never `COUNT(*)` events after `UNNEST(event_params)` (rows multiply).
4. `traffic_source.*` = first-touch, user level. Session-level channel comes from `event_params` source/medium (~33% of events); coverage per session is measured during sessionization.

## Official baselines (deduplicated)
| | Value |
|---|---|
| Orders | 5,372 |
| Revenue | $340,647 |
| Revenue on verified IDs | $308,830 (90.7%) |
| Revenue on `'(not set)'` IDs | $31,817 (9.3%, unverifiable) |
| Removed as double-fires | 320 events / $21,518 (5.9% of raw) |

## Open items
- Session-level channel coverage (% of sessions with a known source/medium).
- Self-referral `shop.googlemerchandisestore.com` (8.5% of events): measure effect on channel shares.

## Data rules added after Q0
5. Revenue and AOV for Jan 26-31, 2021 are incomplete ($0 orders 60-100% vs ~4% normal); exclude from revenue trends; orders and conversion remain valid. Estimated ~$16K missing. [sql/29-30]
6. Check revenue for 0 as well as NULL when profiling.
7. Self-referral sessions (source ends with googlemerchandisestore.com) are not a channel; attribution carries forward to the prior real channel. [sql/26-27]
8. add_to_cart is under-tracked; excluded as a required funnel step (funnel v2). [sql/13-15]
