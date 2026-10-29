# MOKSHA regression checks

Run from the project directory with Godot 4.6.3 and Python 3:

```sh
bash tests/run_all.sh
```

`GODOT_BIN` can name another Godot executable. The runner gives Godot writable
temporary XDG directories and tests the project's 120 Hz physics setting. It
runs independently of inherited desktop XDG settings; `MOKSHA_TEST_DATA_HOME`,
`MOKSHA_TEST_CONFIG_HOME`, and `MOKSHA_TEST_CACHE_HOME` can override these paths. It
runs every stage even when an earlier stage fails, returns nonzero for failing
tests, timeouts, or Godot error diagnostics, and writes per-stage logs plus
`flow_all_report.json`. That aggregate includes hashes of tested scripts, scenes,
resources and project settings so later edits can be distinguished from tested
content.

## Movement-only foundation

The default boot stage now runs the wireframe movement lab. archive_boot also
boots the preserved main.tscn. The aggregate includes movement/tests:

- motor_regression.gd: 143 independent motor and parsed-input checks
- npc_regression.gd: 10 world-aware patrol/chase checks
- lab_contracts.gd: 63 composition, editing, pause and reset checks

## Coverage

- `actors_compile.gd`: reusable player, guard and prop scenes load independently
- `actors_regression.gd`: actor input buffers, interrupted attacks, collision
  occlusion, high-speed movement, prop contact damage, chain momentum and noise
- `sonar_regression.gd`: propagation over real contours, independent origins,
  dynamic geometry, draw callbacks, silence, pause, bounds and source lifetime
- `levels_validate.gd`: two level layouts, physical dimensions, barrier and
  focused real-physics jump routes
- `levels_props_settle.gd`: all 27 placed props remain on their intended support
  surfaces after 240 normal physics frames with active patrols
- `flow_scene_contracts.gd`: exactly two playable scenes, reusable instances,
  exported geometry/tuning, and editor-style save/reload of local overrides
- `flow_regression.gd`: main scene, E-gated level/station/terminal interactions,
  exact sight-trade speed, Q-held taps, enemy feet origins, camera bounds,
  Escape pause/resume, death/R retry, N new run from both entry scenes, and
  reload source cleanup
- `flow_preservation.py`: every original file captured in
  `preserved-projects.json` is checked by SHA-256 without opening those projects
- `polish_route_regression.gd`: continuous natural arcology spawn to station,
  nine connected jumps and terminal victory using parsed input, live enemies
  and props; also verifies the first-landing instruction and R/retrade reset
- `polish_sensory_regression.gd`: actual guard-warning origin and captured facing,
  short expiry, distinct draw/strike cues, spatial audio routing and room scoping
- `graphics_regression.gd`: foot-origin invariance, mirrored grips, attack timing,
  pause/interruption and actual landing detection in reusable actor presentation
- `attack_pose_regression.gd`: drawn frame/contact alignment for every combo and
  facing, source foot pivots, measured hand grips, hitpause, interruption and
  removing the optional art resource without changing the controller
- `blind_feedback_regression.gd`: actual melee and rigid-prop contact versus
  misses/blocked swings, free-source defeat marks, crowding, pause/reset, fade,
  player damage and resting-prop silence; bounded contact/label CPU instrumentation

`native_feedback_run.tscn` is an optional passive visual test entry into the same
arcology. It saves the first real damage/defeat/break frame after the engine draws
it. It never drives actors or inputs, and is not part of normal game progression.

The runner also imports the project and boots the actual main scene. Successful
Godot process exit alone is insufficient: script and runtime error lines fail
the corresponding stage.

## Setup and limits

The integration suite sends actual parsed keyboard input. For isolated
interaction checks it teleports the player to the station and exits; it directly
induces lethal damage to verify the death/retry flow. The level route tests start
at each relevant platform and disable enemies to test jump feasibility. These
are focused regressions, not a claim of an uninterrupted human playthrough.
The saved-scene test uses editor instantiation flags and resource serialization;
native editor usability and visual game presentation require separate review.

Preservation expects `emberwake/` and `moksha-assets/` beside `moksha/`. If those
originals are absent in a portable copy, the aggregate explicitly reports that
stage as not run. Use `bash tests/run_all.sh --require-preservation` to require
the originals and fail if any baseline file is missing or changed. New cache or
untracked files are not baseline originals and are not included in that claim.

Detailed machine evidence is in `flow_report.json`, `flow_scene_report.json`,
`flow_preservation_report.json`, `sonar_report.json`, and `flow_all_*.log`.
See `sonar_test_report.md` for the sensory subsystem's additional limits.
