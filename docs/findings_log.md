# Findings Log

Running record of answers, each traceable to a SQL file. Source for the final memo.

## Q0 — Can we trust the data?
- 92/92 daily tables present; weekday/weekend cycle (weekends ~35% lower); holiday peak late Nov/early Dec, dip late Dec. [sql/00]
- view_item_list under-tracked (71 events vs 1.35M page_views) -> excluded. [sql/01]
- Raw purchase events overstate revenue by 5.9% ($21,518) due to double-fired tracking (95% same user/amount, median 36 ms apart). Official revenue $340,647 on 5,372 orders; 9.3% on unverifiable '(not set)' IDs. [sql/03-06]
- 21.2% of channel values obfuscated -> kept as 'Unknown'; source field 33.5% obfuscated -> not used. Self-referral (shop.googlemerchandisestore.com) = 8.5% of events. [sql/07]
- Sessions table: 360,129 sessions; reconciles exactly to 354,970 session_start events. [sql/10-11]

## Q1 — Where do we lose shoppers?
- add_to_cart under-tracked: missing in 41% of purchasing sessions; >=77% of that is the tag not firing (665 were first-ever visits), only 13% cross-session. -> Funnel v2 excludes add_to_cart; recommend fixing the tag. [sql/12-14]
- Funnel v2 (captures 96.9% of purchases): view_item 21.4% -> checkout 14.1% -> payment 61.0% -> purchase 71.1%; conversion 1.30%. [sql/15]
- Device and country flat (conversion within ~0.2 pts) -> not the lever. [sql/16]
- Checkout->payment varies most across segments (35-82%): New 43.7% vs Returning 81.9%; New = 72.5% of sessions but 37% of purchases. [sql/16]
- 98.5% of new-visitor checkout abandoners never purchase later -> lost, not deferred. [sql/17]
- Opportunity: closing 25-50% of the new-visitor checkout->payment gap = +383 to +766 orders, +$24.3K to +$48.6K over 92 days (7-14% of revenue). Scenario, stated assumptions. [sql/18]

## Caveats so far
- Obfuscated dataset; users are cookies; 92-day window incl. holidays.
- Unusually flat device/country rates may reflect obfuscation.
- Referral conversion likely inflated by self-referral (to test in Q4).

## Q2 — Do customers come back?
- Weekly cohorts of truly new users (ga_session_number = 1; left- and right-censoring handled); 13 cohorts, 258,897 users (cf. 257,314 first_visit users). [sql/19]
- Retention very low: W1 2.4-5.7% | W4 0.5-1.8% | W8 0.2-0.4% | W12 0.08% -> acquisition-driven store. [sql/19]
- Holiday cohorts (Dec) W1 2.4-3.1% vs Nov 4.2-5.7%; retention bumps across Dec cohorts all land in week of Jan 4 -> partly a calendar effect. [sql/19]
- First-week buyers retain ~6x better than browsers (W1 21.2% vs 3.6%; W8 1.9% vs 0.3%). Correlation, not causation; W1 partly order tracking. Not added to opportunity sizing. [sql/20]
- Orders table built: 5,372 orders / $340,647 / 4,419 buyers; 100% joined to sessions. [sql/21-22]

## Q3 — What is a customer worth?
- Observed (not predicted) LTV for truly new users; per-user horizon eligibility. [sql/23]
- Clean read (Nov cohort, fully eligible): d0 $0.74 | d7 $1.01 | d30 $1.42 | d60 $1.50 -> 49% of 60-day value on day 0, 95% by day 30. [sql/23]
- Buyer worth ~$80 in 30 days (> $63 AOV); ~11% of new buyers reorder within 30 days. [sql/23]
- Day-0 value per new user fell Nov $0.74 -> Dec $0.60 -> Jan $0.30 (explain in Q5). [sql/23]
- Censoring trap caught: Jan d30 ($0.27) < Jan d7 ($0.50) because only Jan 1-2 users were eligible -> compare horizons within fully eligible cohorts only. [sql/23]
- By acquisition channel (n=173,023, all with full 30 days): d30 LTV $1.11 (Direct) to $1.48 (Paid Search). Paid highest via basket size; its value grows +135% after day 0 -> paid users return via other channels to buy; last-touch undervalues paid. ~156 paid buyers -> needs CIs. [sql/24]
- No cost data: LTV is the ceiling for acquisition spend, not ROI.
