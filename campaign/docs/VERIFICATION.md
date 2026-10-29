# Five Ascents verification — 2026-10-29

This record separates implementation, controlled input evidence, focused fixtures and unverified human/native qualities. The requested15–20minutes per level is a design target, **not verified human duration**. No bot multiplier is used.

## Source and preservation

Working campaign: `moksha-campaign`; development freeze commit `e94a5c6f7fa8ffa711ba1c13578b638ab3c45f84`. Final evidence files carry their exact source hashes; later documentation/test-result commits do not imply a different gameplay build.

Original Oct23 Library project ZIP was recovered and preserved unchanged; SHA256 `1cef11710932d3a6079026d3b64ac82c50ee36308181606543bb4ddf601a835f`. Original `moksha/`, recovered baseline folder and project ZIP remain separate. A first local git commit preserves the recovered source. Independent comparison found1909 baseline files identical, none missing, before intentionally updating only the new project's entry/configuration and historical test reports. The approved player/controller and original simulation runtime files remain unchanged. One historical test inventory assertion was later corrected separately, as recorded below.

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

Post-fix isolated acceptance is complete:24/24 Level2–3 cases and28/28 Level4–5 cases at60Hz cover both sight states with live damage and ordinary production inputs. Reports and source manifests are under `campaign/route_tests/final/` and `campaign/route_tests_45/final/`. The complete-campaign matrix is still being completed. Do not infer a complete32-district run from isolated starts. Final reports will be added here only after actual normal title/start →district progression →four upgrade choices →real sight decision →final resolution succeeds with matching source hashes and no engine errors.

The route driver knows the map and AI. It sends raw production PC button frames and ordinary E/Q/choice/upgrade key events. It does not teleport during measured play, heal, force kills/goals, disable enemies or open gates. Isolated district/sight setup fixtures are explicitly labelled and separate from full-campaign evidence.

## Inherited historical-test mismatch

The unchanged `simulation/tests/sentry_regression.gd` contains a hardcoded assertion that there are13 authored sentries. The recovered Oct23 demo has20 mappings. Independent execution on an untouched staged baseline reproduces the same sole failure:35scenarios/210checks, one inventory-count failure, while all20 individual shared-scene/damage/HP mapping checks pass. The raw failure is retained and classified as pre-existing assertion drift, not hidden as a pass. The working-copy assertion was subsequently corrected from13/thirteen to20/twenty, with no other GDScript changes or weakened checks; untouched-baseline failures remain preserved. The broader corrected foundation aggregate is still being completed.

## Unverified qualities

- Native rendered-pixel/layout review, perceived animation/game feel and stable hardware frame rate: the execution sandbox prevents starting its installed local display server. No synthetic diagram is presented as a Godot screenshot.
- Audible mix quality on a real output device.
- First-time human exploration, learnability, challenge, accessibility and15–20minute duration per level. These require local play sessions. Bot active time is reported as bot time only.
- Native Windows execution (if a Windows export is supplied, export/package verification is separate from running it on Windows).

No unsupported hearing/smell/intellect trade, roguelite adaptation or resolution of the original contradictory time-loop/immortality story is claimed implemented.
