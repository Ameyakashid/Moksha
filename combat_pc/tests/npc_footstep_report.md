# M17 NPC footstep source: independent focused QA

## Result

Godot 4.6.3-stable (official): **211/211 checks at 60 Hz and 211/211 checks at 120 Hz**, with 29 scenarios per rate. 18/18 paired consistency/source checks pass. No runtime sources were edited by this QA work.

48 protected PC, original movement/NPC, old enemy/guard, contact source, SurfacePulse and NoiseBus files match the retained v20 ZIP byte for byte. Both rates ran the same final seven component/resource/fixture/passive-view source files, and their bytes stayed stable throughout each run. See `npc_footstep_baseline_hashes.json` and `npc_footstep_final_hashes.json`.

## Physical results

| Case | 60 Hz | 120 Hz |
| --- | --- | --- |
| ground distance cadence axis 0.45 | 156.91px / 5 steps | 156.63px / 5 steps |
| ground distance cadence axis 1.0 | 345.56px / 12 steps | 344.83px / 12 steps |
| real slope downhill | 258.84px / 9 steps | 258.71px / 9 steps |
| real slope uphill | 257.79px / 9 steps | 257.06px / 9 steps |
| translating support idle and relative walk | silent idle carry; 6 walking steps | silent idle carry; 6 walking steps |
| wall-clipped translating support idle and relative walk | silent carry; 4 escape steps | silent carry; 4 escape steps |
| static conveyor idle and relative walk | silent idle carry; 6 walking steps | silent idle carry; 6 walking steps |
| actual ledge break depth 4.0 | 0 landing; 3 airborne frames | 0 landing; 6 airborne frames |
| actual ledge break depth 100.0 | 1 landing; 22 airborne frames | 1 landing; 44 airborne frames |
| qualified late-air landing survives scene tree | 1 landing after resume | 1 landing after resume |
| qualified late-air landing survives motor hit pause | 1 landing after resume | 1 landing after resume |

- Slow and full-speed movement use the same authored 28px stride spacing. Stopping is silent after actual braking; restarting/reversing cannot emit on its first sub-stride tick. Wall pushing, idle, airborne motion, skipped/disabled motor ticks, dash displacement and stunned impulse displacement stay quiet.
- Real jump and drop trajectories each produce one distinct `enemy_land`, with landing strength exactly matching the unchanged motor's same-frame signal. No landing catch-up step burst occurs. Both an actual step and landing feed a local NoiseBus and unchanged SurfacePulse exactly once at the original surface point; the project autoload receives none.
- Independent current-floor ray intersections verify every receipt's origin, unit normal and named support. Independent motor samples verify step distance/speed against same-frame actual ground travel and fresh support velocity where applicable; landing speed is separately observed from the motor signal.
- Uphill/downhill 20° motion follows actual two-dimensional ground travel and produces no false landings. Across a 12px break, the brief 4px descent produces no hard-landing event; the real 100px descent produces exactly one. These results bound these actual geometries and authored thresholds, not every possible gap.
- Translating AnimatableBody2D floors and StaticBody2D conveyors carry an idle NPC silently; walking counts own support-relative travel. A translating floor pushing an idle NPC into a wall stays silent after its carry is clipped. Walking away resumes ordinary cadence after ambiguous prior-wall support is discarded; no receipt uses a prior wall sample.
- A translating support changing +80→−80→0→+80px/s preserves own-distance cadence without false landings. The driver independently reads physics-server point velocity before each actual motor step, then checks every moving-support step against actual world travel minus that fresh carry velocity. Requested transform displacement is not used as a reversal oracle.
- Actual composed inherited fixture runs the original motor, fences reset/hit-pause, and tolerates enable/simulation pause, unbind/rebind and removal. Teleport/reset and missed motion do not produce catch-up noise.
- Already-qualified late airborne falls are paused one or two physics ticks before touchdown, through both SceneTree pause and motor hit-pause. Actual body motion stays frozen and silent, then the same flight produces exactly one real landing on resume. Earlier failure evidence is retained in `npc_footstep_late_air_before_60hz.json` / `.log`; the corrected cases are part of both final runs.
- Real bus callbacks resetting history or diagnostics, muting, simulation-pausing, tree-pausing, unbinding, rebinding, detaching, queue-freeing the source or queue-freeing the bus suppress invalidated post-bus receipts. Receipts are immutable; diagnostic copies are independent. A second observer cannot register for the same body.
- Identical input sequences through original and composed motors have **zero position/velocity error and identical state/facing on every compared tick**, including jump/release, reversal, hit-pause, and source removal. The run includes real step and landing emissions.

## Method and limits

The driver calls the unchanged CharacterBody2D motor in real Godot physics frames. NPC Intent is disabled to supply repeatable test inputs; this does not claim complete AI integration. The composed fixture is tested independently of the review scene/UI. Synthetic begin/capture/finish calls appear only in the explicitly labelled stale-token contract-failure case, never as physical cadence or landing evidence.

Headless acceptance does not substitute for native visual review. Animation footplants, audio playback, broad old-game regressions, rotating/skewed/scaled supports and CharacterBody2D carriers are not certified. All thresholds and spacing are authored tuning. The support correction is tested on translating nonrotating floors, carrier reversals/stops, wall escape, and static conveyor velocity. Mixed prior floor/wall ownership is deliberately discarded until a fresh floor-only sample is available.

## Reproduce

From the project root, with writable XDG directories under `/tmp/moksha-m17-test-runtime`: run `python combat_pc/tests/npc_footstep_verify_baseline.py`, then `godot --headless --path . --script res://combat_pc/tests/npc_footstep_regression.gd -- --hz=60` and repeat with `--hz=120`; finally run `python combat_pc/tests/npc_footstep_summarize.py`. Each Godot run writes its JSON result. Retained logs are `npc_footstep_regression_60hz.log` and `npc_footstep_regression_120hz.log`.

## Final passive-view revision

The final passive NPC wire view advances gait directly from motor velocity, so muting/removing the sound source cannot freeze its legs. Its source hash is included in the refreshed seven-file paired manifest, and the inherited fixture loads this view in both final runs. This establishes loading and physical independence; gait appearance remains a separate native visual check.

A separate final review-scene headless boot completed 20 requested ticks with exit 0 and no errors or warnings. Its log, final view/review hashes and scope are recorded in `npc_footstep_final_scene_boot.log` / `.json` and the final hash manifest. Native source-disconnect gait appearance remains the separate visual check.
