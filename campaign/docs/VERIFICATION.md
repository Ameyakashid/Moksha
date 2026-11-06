# Five Ascents verification — 2026-10-29

This is a historical October 29 report. See [the November 6 improvement record](NOV6_CHANGES.md) for the current changes and their separately identified evidence. Historical hashes and failed runs below have not been relabelled as current passes.

This record separates implementation, controlled input evidence, focused fixtures and unverified human/native qualities. The requested15–20minutes per level is a design target, **not verified human duration**. No bot multiplier is used.

## Source and preservation

Working campaign: `moksha-campaign`; final rendered-review gameplay freeze commit `9e22722ebc5835bec0aed003ea71de47463fc324` (replacing pre-polish `4ea2c11`). Final evidence files carry their exact source hashes; later documentation/test-result commits do not imply a different gameplay build.

Original Oct23 Library project ZIP was recovered and preserved unchanged; SHA256 `1cef11710932d3a6079026d3b64ac82c50ee36308181606543bb4ddf601a835f`. Original `moksha/`, recovered baseline folder and project ZIP remain separate. A first local git commit preserves the recovered source. Independent comparison found1909 baseline files identical, none missing, before intentionally updating only the new project's entry/configuration and historical test reports. The approved player/controller and original simulation runtime files remain unchanged. Two historical test inventory assertions were later corrected separately, as recorded below.

## Implemented inventory (not duration)

Five levels have6 /6 /6 /7 /7districts:32 total. Current layout support audit counts123 authored objectives and250 enemy placements including four new captains; summed horizontal extent153,600units. These are inventory measures, not proof of playtime or quality. Many ordinary guards and auxiliary goals are bypassable. There are no elapsed-time gates or repeated waves.

## Focused final checks

- Independent `campaign/qa_audit/final_results/summary.json`:14/14 suites,1454checks at60/120Hz, zero engine errors and production-source drift. Includes goal dependency/order, physical door blocking/opening/reclosing, UI pause/repeated input, upgrade/idempotence, save/Continue/retry/death/ending, real sonar geometry and machinery warning routing.
- Actual incoming damage regression: melee12HP, projectile12HP, J-launched cargo3HP and gravity-lethal60HP, both physics rates. All32 district loads plus retry/Continue bind four incoming-contact adapters to the current health component.
- Captain isolated checks:25scenarios/99checks at each rate. Integrated four placements ×both sight states:8encounters/198checks at each rate. Genuine guarded captain hit60→57HP and authored sentry projectile60→48HP; real player strikes defeat the captain and open its seal while other guards can survive. Focused arena placements are explicitly fixtures, not complete routes.
- Breaker: controlled initial arena fixture followed by real J inputs yields2 authenticated ContactAdapter/StrikeHealth receipts and completion; E cannot complete it.
- Art:743 pose/data/lifecycle checks; actual choice immediately hides full-color paint, blind retry keeps it hidden and new run restores it. This is state/draw-callback evidence, not native-pixel approval.
- Original `tests/run_all.sh`:19/19 stages passed during development; source hashes recorded in its report.

## Important discovered-and-fixed defect

The optional campaign health adapter initially replaced the Health node without rebinding four components that cached the old health authority. Consequently ordinary physical attacks could retire without damage. Independent captain integration found it; the campaign now explicitly rebinds IncomingStrikeReceiver, ProjectileReceiver, PhysicalImpactReceiver and BoundaryReceiver after replacement. New physical-channel regressions prove the correction.

**All route survival evidence captured before this fix is invalid for final combat acceptance.** It remains labelled historical navigation/development evidence and is not used as a final pass. All final routes must run the corrected source with genuine incoming damage.

## Continuous and isolated route acceptance

Post-health-fix, pre-visual-polish isolated acceptance passed24/24 Level2–3 cases and28/28 Level4–5 cases at60Hz with both sight states, live damage and ordinary inputs. These retain their older source snapshots; they are historical route evidence, not hash-matching tests of the final9e presentation/UI build. Final continuous campaigns rerun all32 districts on the final build. Reports and source manifests are under `campaign/route_tests/final/` and `campaign/route_tests_45/final/`. Six continuous title-to-ending cases pass on gameplay freeze `4ea2c11`, independently reviewed in `campaign/qa_audit/continuous_independent_review_4ea2c11.json`. Each completes32 ordered districts,32 required-goal gate receipts,four actual upgrades,five level receipts and a real ending, with genuine incoming damage,zero deaths/errors/source drift. These are pre-native-polish receipts preserved under `campaign/tests/history/pre_visual_freeze_4ea2c11/`; a later UI/art revision must receive its own validation rather than inheriting these hashes.

| Physics / lens / sight | Level1 /2 /3 /4 /5 active seconds | Total seconds |
|---|---|---|
| 60 neutral retained | 344.1 / 213.0 / 203.8 / 302.2 / 283.7 | 1346.83 |
| 60 neutral traded | 344.1 / 164.6 / 185.8 / 258.4 / 247.8 | 1200.68 |
| 120 neutral retained | 267.1 / 208.2 / 204.7 / 306.4 / 282.1 | 1268.50 |
| 120 neutral traded | 265.5 / 162.2 / 186.4 / 268.4 / 245.7 | 1128.26 |
| 60 strength retained | 306.7 / 211.4 / 209.1 / 313.4 / 297.3 | 1337.98 |
| 60 agility retained | 370.8 / 169.3 / 198.6 / 299.5 / 263.8 | 1302.03 |

These are layout-aware scripted bot times (including occasional navigation hesitation), not optimized minimums or human estimates. They do **not** verify15–20minutes per level or75–100minutes total.

The route driver knows the map and AI. It sends raw production PC button frames and ordinary E/Q/choice/upgrade key events. It does not teleport during measured play, heal, force kills/goals, disable enemies or open gates. Isolated district/sight setup fixtures are explicitly labelled and separate from full-campaign evidence.

## Inherited historical-test mismatch

The recovered baseline `simulation/tests/sentry_regression.gd` contained a hardcoded assertion that there were13 authored sentries. The recovered Oct23 demo has20 mappings. Independent execution on an untouched staged baseline reproduces the same sole failure:35scenarios/210checks, one inventory-count failure, while all20 individual shared-scene/damage/HP mapping checks pass. The raw failure is retained and classified as pre-existing assertion drift, not hidden as a pass. The working-copy assertion was subsequently corrected from13/thirteen to20/twenty, with no other GDScript changes or weakened checks; untouched-baseline failures remain preserved. The corrected foundation aggregate now passes72/72 stages with zero source drift; its independent review is `campaign/qa_audit/foundation_independent_review.json`. A second analogous listener assertion13→21 was independently reproduced on the untouched baseline and narrowly corrected. The test runner also creates omitted report directories so a report write cannot terminate a test before quit.

## Observer correction, not a gameplay change

The first continuous120Hz traded-sight attempt repeatedly released an admitted west-facing ledge at Works because its navigator reversed steering during the catch. The preserved attempt is not accepted as a pass. A separate driver subclass finishes that exact catch with ordinary Up input; it changes no production state, controller, collision or health. An isolated120Hz traded district probe verified the correction; the corrected complete run subsequently passed independently. Previously accepted runs retain their original driver and source hashes.

The first Strength run likewise timed out when its navigator repeatedly attempted an elevated jump designed for the ordinary speed. A separate Strength driver instead takes the already-authored fixed ladder at1340 in Stamping. Its isolated real-input check succeeded with genuine incoming damage; the complete Strength rerun subsequently passed as separate evidence. Neither correction changes movement, layout, health, enemies or objectives.

## Native rendered review and final polish

A supported cloud desktop exposed native Godot4.6.3 with the shared project filesystem. This resolved the earlier shell-display limitation without retrying denied display-server operations or publishing a Site. Real screenshots—not mockups—are preserved in `campaign/evidence/native_visual/` with a review report and hashes.

Bounded manual play and explicitly labelled direct-state fixtures cover representative starts in all five levels, movement/jump, guard/telegraph overlap, death/retry, sight choice/sonar fade, machinery/hazard concealment, journal paging, upgrades and ending panels. The review found and corrected empty legacy-objective journals, clipped prose, misleading controls/prerequisites, blueprint prop/ladder/station appearance, weak enemy fills, objective occlusion and edge-clipped labels. Every reported blocking visual defect in this sample was re-rendered after correction, including actual arrow-key paging. Thirty inspected runtime files match merged production exactly. This does not claim every room/frame, Windows execution, human pacing or audio has been reviewed.

Final UI/paint checks:211 player-guidance assertions;19 object-paint contracts;149 objective-caption/zoom/offscreen contracts; plus743 actor pose checks. Independent final main matrix passes2966 assertions (14 prior suites and two756-check object-paint integrations), with real damage, save lifecycle, visibility and collision invariance. The final six continuous full campaigns and inherited72-stage suite all pass against the final freeze, with no engine errors or source drift; pre-polish receipts above remain preserved rather than relabelled. Legacy19/19 stages also pass. The alternate K local-custody ending passes35 controlled-input checks at each physics rate (not a second full traversal).

## Final continuous acceptance — 9e22722

All six ordinary-input campaigns complete32 ordered districts,32 required-objective gate receipts,five level receipts,four upgrades and the public-record ending. No deaths, engine errors, source drift or current hash mismatches. Both sight choices are real in-game decisions; Strength and Agility use actual title selections. Input-only navigation corrections are disclosed above; no game state/health/goal writes occur during full runs.

| Physics / lens / sight | Level1 /2 /3 /4 /5 active seconds | Total seconds | Real damage receipts |
|---|---|---|---|
| 60 neutral retained | 344.1 / 210.8 / 204.6 / 302.1 / 284.8 | 1346.53 | 52 |
| 60 neutral traded | 344.1 / 164.6 / 183.9 / 257.4 / 246.7 | 1196.70 | 39 |
| 120 neutral retained | 265.5 / 208.3 / 203.6 / 307.7 / 282.5 | 1267.56 | 49 |
| 120 neutral traded | 266.9 / 162.3 / 185.7 / 271.4 / 247.6 | 1133.88 | 49 |
| 60 strength retained | 306.7 / 211.3 / 210.6 / 312.3 / 298.1 | 1339.02 | 54 |
| 60 agility retained | 372.5 / 177.2 / 198.5 / 308.1 / 265.0 | 1321.32 | 36 |

These roughly18.9–22.4minute **whole-campaign bot runs are not human timing** and do not establish the requested75–100minute human target. `full_route_matrix.json` and `build_lens_matrix.json` pin each final report and source hashes. Final foundation72/72 and legacy19/19 pass; the preserved v28 archive hash is verified independently. Native source review, exported-pack smoke/damage audits and full input routes are separate evidence categories.

## Unverified qualities

- Exhaustive rendered review of every room, a full native manual campaign playthrough, and stable performance on user hardware. The bounded native review above does not establish these.
- Audible mix quality on a real output device.
- First-time human exploration, learnability, challenge, accessibility and15–20minute duration per level. These require local play sessions. Bot active time is reported as bot time only.
- Native Windows execution (if a Windows export is supplied, export/package verification is separate from running it on Windows).

No unsupported hearing/smell/intellect trade, roguelite adaptation or resolution of the original contradictory time-loop/immortality story is claimed implemented.
