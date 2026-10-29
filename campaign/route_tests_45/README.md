# Level 4/5 route diagnostics

`input_probe.gd` extends the established production-input navigator. It reads layout and AI state to choose inputs but does not write actor positions, enemy health, objective completion, collision state, or AI state during the measured route.

The only initial fixtures are `start_new(true)`, loading one named district, disabling saves, and optionally selecting sacrificed sight before active navigation. E/Q keys are queued through an ordinary idle-process dispatcher; movement/combat is `input_override`. Freight completion requires actual intact cargo launches, settling and the real receiver latch. Breaker objectives require actual J attacks. The Three Crews machine branch uses known supported fixed-route waypoints.

Examples:

```sh
XDG_DATA_HOME=/tmp/moksha-qa/data XDG_CONFIG_HOME=/tmp/moksha-qa/config XDG_CACHE_HOME=/tmp/moksha-qa/cache \
  godot --headless --fixed-fps 60 --path . --script campaign/route_tests_45/input_probe.gd -- \
  --area=works_receiving --hz=60 --blind --final
```

Use matching `--fixed-fps 120 --hz=120` for120Hz. `--final` writes a separate report with start/end hashes and fails on drift. Development logs in this directory are historical diagnostics, **not final acceptance**. Partial `final/` runs before the Captain Keeper addition are also superseded; compare hashes, do not merely count passing files.

Isolated district success is not full-campaign continuity, new-game, upgrade, save/Continue, or final-choice resolution proof. The final district success means entering `final_choice`, not choosing an ending. Times are optimized layout-aware simulation, not human playtime. They do not establish the15–20minute target.

Observed recoverable bot issues: a loose crate blocked ladder alignment (solved with actual J to clear it); generic path search looped through the Three Crews shortcut (use fixed machine waypoints); one-shot freight policy repeatedly reset stationary cargo (escort and relaunch it physically). These observer fixes do not teleport or change the game.
