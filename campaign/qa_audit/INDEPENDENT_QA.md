# Independent campaign QA — 2026-10-29

## Frozen-production targeted matrix

`final_results/summary.json`: **14/14 suite/rate cases, 1,454 assertions, zero engine errors, zero production-source drift**, at 60 and 120 physics Hz. Exact tested source hashes are in that report. Production checkpoint: `e94a5c6f7fa8ffa711ba1c13578b638ab3c45f84` (the report hashes, not the commit alone, identify tested bytes).

These are controlled component/scene fixtures, **not a continuous campaign traversal, native pixel review, unfamiliar-human usability study, or duration measurement**. Repeated assertions across districts/rates are not independent game features.

Coverage:
- Unique district IDs, local dependency references, acyclic objective graphs and door dependencies.
- Prerequisite enforcement before the first physics tick; idempotent build modifiers; shared strike resource preservation; reward re-collection cannot farm upgrades.
- Physical moving-body collision against closed, opened, reclosed and reopened objective doors.
- Journal/pause/interaction/clock behavior, repeated dismissal, paused retry, transition input fencing, unrouted console initialization, intentionally latched installed results.
- All new objective contours sampled into sonar; ordinary objective/scenery paint hidden in traded-sight state; genuine hazard-warning events accepted by sonar. This is structural/state evidence, not native rendered pixels.
- Actual hazard overlap damage/cooldown, safe spawn staging, paused hazard clocks.
- Upgrade + next-district save, fresh-host Continue, build persistence, real fatal damage and retry, explicit final choice and saved result. Continue after completion intentionally **replays the final district**, not the completed ending. New run retains previous result file.
- Every campaign district load, retry and Continue retains current Health authority in all four incoming receivers.
- **Actual authenticated incoming damage on the production campaign player:** autonomous melee 60→48 HP; autonomous physical projectile 60→48; ordinary J-launched charged rigid cargo 60→57; real gravity boundary crossing 60→0 once. Verified at both rates, without direct receive_hit or damage calls in this incoming-channel suite. Initial placement/encounter geometry is explicitly controlled.

## Defects found and repaired by implementation owner

Missing-prerequisite pre-tick interaction bypass; wounded vitality upgrade's stale effective capacity; same-frame exit/upgrade duplication; missing objective sonar contours and hazard warning channel; misleading blocked-exit text/console numbering.

Captain integration independently discovered stale cached Health references after the campaign replaced its optional health store. Earlier route survival evidence predating the four receiver rebinds is **invalid as damage/difficulty evidence**. Direct receive_hit/hazard tests did not cover these authenticated channels. The dedicated incoming-channel suite above verifies the repair.

## Historical regression caveat

`historical_sentry_diagnosis.json` and `baseline_sentry_60.log` / `baseline_sentry_120.log` reproduce the inherited sentry suite's only failure on an untouched baseline COPY: **209/210 pass**, but its unchanged inventory assertion expects 13 sentries where the latest baseline has 20. All 20 individual shared-scene/damage/health mapping checks pass at both rates. Original production/test files remain unchanged. Preserve the raw aggregate failure; do not describe that historical suite as wholly passed.

## Preserved development evidence

Earlier `draft_*` logs include real defects subsequently fixed. `sensory_draft.log` used an invalid initial choice fixture; `sensory_fixed_fixture.log` corrects it by invoking the real station interaction from controlled placement. `incoming_health_60_draft.log` stopped on a QA logging access to a legitimately retired cargo after verifying its real damage; the final suite fixes that logging-only error and also reaches the boundary test. `final_attempt1_interrupted/` preserves the interrupted matrix. None replaces the final report.

## Remaining independent acceptance boundaries

Continuous title-to-ending input routes, final native visual/audio review, packaging verification and unfamiliar-human pacing are separate. Never concatenate isolated district times, count input-tool latency, or apply a bot-to-human multiplier. **15–20 minutes per level / 75–100 minutes total remains a design target unless independently supported by human play evidence.**

## Authorized historical test maintenance after the targeted matrix

Final source checkpoint `4ea2c1102466aabd9d8cf93a01be24139970363d` corrects only the two obsolete inventory literals/labels in inherited GDScript tests: sentry 13→20 and listener 13→21. The listener failure was likewise independently reproduced on the untouched baseline copy at both rates (188/189 pass, all 21 individual listener mappings correct). No other assertions were weakened. Original failing evidence is retained.

The foundation Python harness now ensures missing report directories exist and records wall-watchdog expiration as failure while continuing; its configurable default watchdog is 600 seconds. This does not change simulated gameplay time or pass criteria. The prior freight hang was independently reproduced as `store_string` on null after opening a report in a missing directory, not poor physics performance. See `baseline_freight_missing_directory.log`.

`test_only_maintenance_manifest.json` shows these are the only post-matrix GDScript changes. Production bytes tested by the 1,454-check matrix remain identical. Corrected full aggregate and clean continuous playthroughs are reported separately; this note does not preempt their outcomes.

## Corrected inherited aggregate — independently closed

The final `simulation/evidence/foundation_report.json` records **72/72 passed**, all exit codes zero, no engine diagnostics and **zero source drift**. The preserved v28 archive hash is also verified. `foundation_independent_review.json` pins that report's SHA-256 and records this independent review. The two narrow inventory assertion corrections and report-directory repair above are included; original failed/timeout evidence remains preserved.

This broad aggregate verifies inherited physics/combat/cargo/boundary/mission contracts and scene boots. It does not replace the new campaign's continuous title-to-ending input routes, native visual review or human pacing evidence.

## Exported-pack health verification

The unchanged incoming-channel harness also passed **157 assertions against the actual Windows PCK**, executed by Linux Godot from an empty directory (no source-tree resource fallback). All 32 districts/retry/Continue bind the current Health store; real melee/projectile/cargo/gravity contacts debit it correctly. The PCK extracted from the delivery ZIP is byte-identical to the tested PCK (`0a1f7950fa0e8a36a0e121d084175391e26156dd50a17ad7acb874384f46b40b`). See `packed_health_independent_review.json` for ZIP/log hashes. This closes the stale-export risk; it is **not** native Windows EXE execution, visual readability or audio-mix validation.

## Six continuous campaigns — production checkpoint 4ea2c11

`continuous_independent_review_4ea2c11.json` independently verifies **six complete title-to-ending runs**:

| Physics rate | Starting lens | Sight | Optimized active seconds |
|---|---|---|---:|
| 60 Hz | Neutral | Retained | 1346.8333 |
| 60 Hz | Neutral | Traded | 1200.6833 |
| 120 Hz | Neutral | Retained | 1268.5000 |
| 120 Hz | Neutral | Traded | 1128.2583 |
| 60 Hz | Strength | Retained | 1337.9833 |
| 60 Hz | Agility | Retained | 1302.0333 |

Each has 32 correctly ordered district metrics and open-gate receipts with every required objective complete, five level receipts, four genuine upgrade choices, actual incoming damage, correct sight choice, zero deaths, empty failures/source drift and no engine errors. Report hashes are pinned. Production hashes match checkpoint 4ea2c11.

Two failed observer attempts remain preserved: 120 Hz traded repeatedly released an admitted Works ledge, and Strength attempted an unsuitable graph jump. Dedicated observers use ordinary Up through that real ledge and the existing Stamping ladder respectively. They do not change production physics, position, health, goals or gates. Both corrected cases subsequently completed the entire campaign; isolated success was not substituted for full completion.

These roughly 18.8–22.4-minute **layout-aware automated** runs are not human-duration estimates. No bot multiplier is justified. This establishes finite five-level campaign completion, not the 75–100-minute human target. Any subsequent production/presentation revision needs separately scoped evidence; these reports must not be silently relabelled as tests of newer bytes.

## Native screenshot review — staged presentation, 2026-10-29

Actual native Godot frames now exist in `moksha-campaign-delivery/visual-qa/`; earlier unavailable-native statements describe the earlier headless-only phase, not the present evidence. Independently viewed the staged `after-journal`, `after-pause`, `after-blind-movement`, `after-l1-jump`, `after-fixture-l2/l3/l4/l5`, `after-fixture-ending`, and refreshed `final-fixture-l3`, `final-fixture-console`, `final-fixture-enemy`, `after-wrapped-l5` frames. Corrected journal/pause are readable; L5 prose wraps fully after correction; interior windows/services improve the former repeated vent wallpaper. Console UNROUTED/TARGET and E controls are readable. Blind movement frame conceals scenery; this particular frame is not proof for every hazard state. Enemy remains outline-led but now visibly filled. Locked breaker prompt still advertises J without the missing prerequisite; this display-only usability issue was forwarded to lead. Tram's old E sign was separately identified and staged for correction.

These are real rendered pixels, including parent-driven movement/pause/combat/retry and explicitly controlled district/object fixtures, not a manually completed campaign. They do not establish native Windows execution, audible mix, or 75–100 minute human duration. Staged screenshots do not retroactively change the exact source identity of the six accepted 4ea continuous runs. Any later merged build needs its own diff/version and scoped validation.

All 32 authored districts' signs, hints, introductory text, final objective kinds, optional flags, and captain/all-guard seals were statically reviewed. Fifteen exact text-only replacements were supplied to lead in delivery `ui-patch/layout_text_fixes.json`; no production files were changed by this audit. Key corrections: converted Thermal/Drainage breakers, UNROUTED press count, optional western refuge and other rescue branches, inherited Homes objective chain, and accurate Warden-only-district all-six-guards seal versus other captain-only seals.
