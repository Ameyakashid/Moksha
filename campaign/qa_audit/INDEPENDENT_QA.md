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
