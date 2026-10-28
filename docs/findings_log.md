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
