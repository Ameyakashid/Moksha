# Intellect companion: original Level1 slice

User intent: travelling cognitive sprite, useful sense-adapted guidance, restrained witty/tragic banter and enemies addressing the old operative (MOKSHA-source.md). This slice does not resolve reset/immortality/bomb lore, add sacrifice mechanics or invent crew allegiance.

Reference boundaries: Supergiant's SG_Gavin Hades AMA describes eligible state requirements, author priority and equal-priority selection (https://www.reddit.com/r/NintendoSwitch/comments/ixri6b/we_are_supergiant_games_creators_of_hades_pyre/). This is developer commentary, not recovered code. CDDA 0.H at 5d069f2eaccd125d22b53617ba73ce7fab157a9f separates authored conditional lines and consumed-topic sentinels (data/json/npcs/common_chat/TALK_FRIEND_CONVERSATION.json; src/npctalk.cpp lines6612–6645; doc/NPCs.md). Study only: no copied implementation, prose or assets. Its mutable effects are deliberately NOT adopted.

Ownership: companion_lines.gd owns original short prose and fixed event IDs. companion_director.gd owns detached eligibility, deterministic priority, session-local consumed IDs and bounded display/cooldown. companion_observer.gd reads existing host facts and adapts them; no game authority or arbitrary rule interpreter. companion_mote.gd owns a small original nonphysical cosmetic effect. Host owns lifecycle and passes a read-only display value into existing HUD notice rendering.

Presentation proposal: borrow the existing contextual notice region only when no normal notice, chapter card, interaction prompt, nearby active enemy, recent damage or modal UI. No stacked subtitle panel; no forced wait/input capture. A tiny cognitive mote follows behind the operator, suppressed during danger and hidden with traded sight. Text must not reveal enemies through blindness. Sight reaction happens only after an actual station choice, including later floors. No voiced audio is claimed.

Memory: session-local only; clear for New/Continue, retain consumed lines on district retry, retire active line when room changes. No save schema changes. Lifecycle merge points: ready creation, New/Continue reset, choose_sight observation and end-of-HUD snapshot decoration. No completion/save ownership.

Validation planned: pure selector and truthfulness controls; quiet/spam/retry/transition/pause/Continue boundaries; ordinary-input Level1 and later real trade; disabled presentation equivalence; native smallest-viewport review and actual input excerpt. Early blind-room cases are fixtures, not a normally reachable Level1 trade. No new gameplay/geometry.
