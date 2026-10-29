> Historical v28 demo verification. The simulation-first changes and their current evidence are documented separately in `simulation/VERIFICATION.md` at the project root.

The later production shared-sentinel checkpoint is verified in `simulation/VERIFICATION.md` and `simulation/evidence/sentinel_acceptance.json`. Ordinary sentinel factory/contact/Health/sound/reset proof is separate from the legacy enemy checks recorded below. The current full mission routes include the generic ladder-planner correction documented in `simulation/SENTINEL_CONTRACT.md`; game geometry and route success criteria remain unchanged.

# Verification and known limits

Godot 4.6.3, Linux cloud workspace, 2026-10-19. This is a shorter complete playable demo. The roughly thirty-minute target is **not met or validated**. Human first-play duration is unknown; no novice multiplier is applied to automated timing.

The final expanded source was staged without an editor cache, imported in Godot 4.6.3 and booted through the default mission entry for 180 frames without script/import/runtime errors. ZIP integrity is checked in the delivery manifest. The immutable v27 rollback remains unchanged.

## Expanded final frozen input-driven routes

All four current routes reach seven authored areas and the explicit ending, with zero deaths, retries, errors or source changes. Thirty source hashes match the working build. Progress uses raw player input and proximity interactions: no route-play teleports, health writes, forced kills, disabled enemies or cargo impulses. Both full sacrificed routes choose the real Exchange offer. The bot knows geometry and AI, so these are optimized simulated times, not human perception/navigation or difficulty evidence.

| Physics rate | Sight | Simulated active time | Enemies defeated | Archives |
|---|---|---:|---:|---:|
| 60 Hz | Retained | 152.45 s | 40/46 | 2/5 |
| 60 Hz | Sacrificed | 145.07 s | 41/46 | 3/5 |
| 120 Hz | Retained | 149.79 s | 40/46 | 3/5 |
| 120 Hz | Sacrificed | 141.23 s | 41/46 | 3/5 |

The measured range is 2:21–2:32 of informed-bot active play. This does not meet or establish thirty human minutes. Optional bypassed enemies/archives are explicitly counted and not represented as played content. The final sacrificed 60 Hz run naturally missed the Lift branch landing, used the new recovery ladder and completed the mission. See `expanded_mission_route_matrix.json` and its four full reports.

## Expanded final components and native review

- Isolated Freight approach matrix: 8/8 direct/flank × retained/traded-sight × 60/120 Hz routes pass, each with a real J launch and intact supported cargo latch. Times 14.10–16.62 simulated seconds include the isolated ending. Isolated traded-sight runs use an explicitly labelled pre-clock sight fixture; full mission runs use the actual Exchange decision.
- Closed-shutter recovery: 24/24 actual-input cases pass across all three barriers, both sides, both sight states and 60/120 Hz, with shutters kept closed. Added Lift and Dispatch return ladders after the full route exposed unreachable floor pockets. Four actual-fall Lift routes also complete all circuits and ending. These explicit-position recovery fixtures are separate from full-route timing.
- Relay shutter: 68/68 checks at each rate. Physical collision and sonar retirement match the committed state; real PC passage and physics-callback opening are exercised.
- Freight receiver/cradle: 186/186 checks at each rate. Includes 48 original random-spin launches, 12 charged-strength launches, actual PC J delivery in both sight states, support/contact rejection, local replacement/recovery, pause/reload, one actual-origin latch event and running jump→ledge catch→pull-up onto its widened same-body backstop.
- Freight host: 12/12 checks at each rate: actual raw-J delivery, E-only rejection, no healing on replacement, invalidation, gate opening, disabled post-success replacement and retry reset.
- Independent expanded integration: 68/68 checks at each rate, refreshed against the final receiver; preserved core 11/11 files byte-identical. Separate schema 3 files keep v27 saves intact; fresh-host Continue, choice/archive/metrics persistence, local-objective reset and sonar/source lifecycle are exercised.
- Native Relay clarity: cross-braced amber shutters differ from thin cyan ladder rungs; SEALED captions and raised recovery signs clear HUD/player. Pause help lists W/S and objective reset.
- Native Freight: actual J delivery seats cargo and opens the shutter. Receiver/seated captions are above the basin, pause names cargo reset, and blind pulse contours remain black/white/cyan. Final widened-backstop screenshots were refreshed and reviewed. Expanded main title, Warden and ending captures also show correct area numbering and unclipped text; their direct-state statistics are not playthrough evidence.

Fresh CUA observations reached one of three Relay Works circuits at 1:23 game-clock seconds, followed by a death returning. Wall time (~9m 23s) includes pauses, decisions and unreliable input/tool delay. It cannot support human completion time or difficulty claims. This resulted in concrete clarity fixes rather than a novice-time estimate.

## Preserved foundation components and integration

- Lithe connected-body replacement: 268 / 508 checks at 60 / 120 Hz, 3,636 poses each; fixed limb geometry, planted support, transitions, real-controller equivalence and pause/reset. Native sampled run/turn/jump/roll review accepted. The v26 controller and original view are unchanged.
- Melee/listener enemy: 11 scenarios / 44 checks at each rate; real v26 strikes, fractional health, guard/parry, props, edges, reset and defeat.
- Ranged sentry/carrier: 16 scenarios / 74 checks at each rate; physical reflected projectile, guard, melee interruption, terrain sweep, evade and lifecycle cleanup.
- Warden: 15 scenarios / 76 checks at each rate; bracing, committed cut/sweep, interrupting counter/parry and actual input-driven duel.
- Translating lift: 5 actual-physics checks for player carry, alignment, pause and jump departure.
- Expanded mission composition: 145 direct-state checks, zero failures. These check host/API/health/state/sight choice/area composition/save boundaries/ending; they are not a playthrough.
- Independent integration: 32 checks at each rate for real health damage, canonical sound/audio event names, immutable origin, cache removal/save, marker alignment and pause.
- Sonar cache optimization: 183 exact differential checks against the preserved renderer, zero failures. Geometry/tracks/arrivals/attenuation/origins/fragment alpha and culling agree. Includes moving/rotated lifts, collider add/remove/disable/resize/replacement, destroyed props, cache-ignore, spacing and budget changes, pulse retention and sight modes. Reviewer found stale bounds after a sampling-budget change; keyed bounds by geometry fingerprint and reran successfully.
- Opening: 49 timing/contact checks, zero failures; view-only staged throw, release pauses, head dodge and hand at former head position. Native captures reviewed separately.
- Historical aggregate suite: 19/19 stages passed, including original actor 48/48, placed level, flow 73/73, sensory/graphics and preservation checks.
- Preserved target-health module: 43 scenarios / 145 assertions at each rate plus review-scene checks passed.

## Preserved v27 checkpoint routes (superseded content)

These v27 runs reached all six then-current areas and the explicit ending. No teleports, health writes, forced kills or disabled AI occur in route play. The bot knows the geometry, so sacrificed-sight runs do not establish human sonar-navigation difficulty. Every run had zero deaths, retries, failures or source-hash changes.

| Physics rate | Sight | Simulated active time | Enemies defeated | Archives |
|---|---|---:|---:|---:|
| 60 Hz | Retained | 135.90 s | 34/42 | 3/5 |
| 60 Hz | Sacrificed | 120.82 s | 33/42 | 3/5 |
| 120 Hz | Retained | 130.57 s | 34/42 | 3/5 |
| 120 Hz | Sacrificed | 120.66 s | 34/42 | 3/5 |

The two-minute optimized routes are reported as measured. They do not substantiate thirty human minutes. Optional unvisited archives/enemies are not silently counted as played content. Direct lifecycle fixtures separately pass34/34 at both rates, covering interruption, actual damage/defeat, retry, persistent trade/cache state, title/continue and replay.

The v27 checkpoint had a fresh staged source tree without `.godot` imported successfully and booted the default mission for 180 frames with no script/import/runtime errors. Baseline audit found 716 original files unchanged and none missing; only README, delivery notes, project main entry and regenerated historical reports differ. All approved controller/runtime files remain byte-identical.

## Native visual and manual checks

Actual Godot screenshots are in `demo/evidence/native_*.png`; these are direct-state review fixtures, not screenshots proving a full human playthrough. Native sampled animation showed connected run/turn/jump/roll poses. Manual input checked title/start/skip, movement, crate landing, compact roll, guard, defeat overlay, checkpoint retry and pause. Blind elevated view keeps a black background, white contours and cyan body cue without skyline leakage.

Precise continuous parry feel could not be judged through separated remote-control calls. The cloud audio device failed and Godot used dummy output: audio event mapping was tested, but audible mix quality is unassessed.

## Performance: useful optimization, unresolved smoothness

The native cloud renderer is software llvmpipe. A controlled comparison before geometry caching measured median FPS: empty scene154, live Cistern without sonar63, full sonar45. Contour refresh averaged14.38ms; pulse preparation2.36ms; contour drawing0.82ms.

After shape caching and conservative radius-bound rejection, contour refresh averaged3.58ms, with exact parity verified. However the comparison machine slowed markedly even for empty/world-only scenes: medians59 / 11 / 16 FPS; ranges12–110 / 9–27 / 2–20. Those measurements cannot establish a net FPS improvement or smooth60fps. They are retained rather than selecting a favorable sample. `native_profile_before_geometry_cache.json` and `native_profile_render.json` contain the full comparative samples. The earlier transition-heavy and sustained-pulse diagnostics are also retained and explicitly not used as gameplay-duration evidence.

Optimization preserves real collision contours and propagation; local shape samples are cached, live transforms still applied, changed shapes invalidate, and distant contours skip expensive pulse preparation only when an expanded world-space bound proves them out of range. World/physics behavior is not reduced to improve a number.

## Scope

Included: city entry, old-operative/former-mentor framing, skippable spear-catch opening, physical movement/combat/props, melee/listener/ranged encounters, optional sight trade, actual-origin overlapping sound traces, ladders/lifts, field archives, checkpoints/retries, Warden and local lift resolution.

Not included: the full proposed four-floor game, time-reset/nuclear-bomb story, full villain arc, boss friendship/adaptation, other sense trades, build economy, random levels or online features. The local ending is authored for this finite demo, not presented as the unresolved full-story ending.
