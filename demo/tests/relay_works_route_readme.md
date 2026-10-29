# Relay Works isolated input-route validation

## Final result

All four fresh routes passed on the same frozen source set. Each activated all three relays through actual proximity interactions, opened all three physical shutters, collected the single archive, and reached the isolated ending. All runs had **zero deaths, retries, test failures, source changes, runtime errors or warnings**.

| Physics Hz | Sight choice | Total simulated active seconds | Relay Works only | Defeated | Bypassed | HP at module exit |
|---|---|---:|---:|---:|---:|---:|
| 60 | retained | 41.083 | 38.800 | 10 / 13 | 3 | 48 / 60 |
| 60 | sacrificed | 44.150 | 42.333 | 11 / 13 | 2 | 36 / 60 |
| 120 | retained | 40.875 | 38.592 | 10 / 13 | 3 | 48 / 60 |
| 120 | sacrificed | 37.417 | 35.608 | 11 / 13 | 2 | 36 / 60 |

These are simulated active times from a layout/AI-aware bot. They do not validate human duration, difficulty, first-time discovery or navigation using only sonar. Paused sight selection, archive reading and the deliberate pause test are excluded from the host's active timer. The isolated area and its ending are tested here; an expanded integrated main mission is not implied.

## Evidence and source identity

- `demo/evidence/relay_works_route_matrix.json`: aggregate, exact report/log hashes and the shared 25-source manifest
- `demo/evidence/relay_works_route_60hz_retained.json`
- `demo/evidence/relay_works_route_60hz_sacrificed.json`
- `demo/evidence/relay_works_route_120hz_retained.json`
- `demo/evidence/relay_works_route_120hz_sacrificed.json`

Every report records the scene, captured sources, relay/shutter transitions, area metrics, incoming damage, input counts and recent position/velocity/AI/navigation traces. Captured hashes were identical across all four runs and matched current source bytes when the aggregate was generated.

- Area: `2eaebbcc4c64eeaf8c73467a0aec5614c43529d33048cb71d0899b6116f0c8ee`
- Shutter: `a9d03e1a4c71b888b63e4f6db4a0f937a692ccaa4be9ddacfdede94cae943261`
- Host: `3698b523d261f019598636f0a1f05cd77ad049f95c842d9973dc01bed227eb5f`
- Sonar: `44cc08ad19b7716de1d58ca1aba6604b64f46519df9594c1c2198e48ee1b3642`

The original v27 `mission_route_*` reports and bot are preserved unchanged. These new module reports have a separate filename prefix and must not be substituted for, or merged into, that checkpoint's timing evidence.

## Method and coverage

`relay_works_route_bot.gd` instantiates `res://demo/tests/relay_works_review.tscn`. It makes the real sight choice at the module's station, then drives the existing PC with raw left/right/up/jump/attack/shield/roll input dictionaries, normal weapon taps and proximity-limited interactions. It closes the archive through an ordinary E key event. It exercises pause/resume and checks the player position and active timer remain frozen. Spawn acceptance records a physically grounded player at the safe authored spawn.

The bot reads the actual live shutter collider rectangles, splits navigation surfaces at closed barriers, includes physical shutter tops, and rebuilds the graph only when shutter state changes. It does not ignore closed shutters or assume the floor is one uninterrupted surface. It crosses the Service barrier on real ledges, takes the Lift circuit, and traverses the Dispatch platforms. The final Dispatch layout has a recovery ladder starting at y=135 rather than the superseded floor-to-top shortcut.

There are no measured-gameplay teleports, position resets, health writes, forced kills, gate writes, AI disabling, collision disabling or manual world ticks. Regular host sector transitions perform their normal spawn/reset behavior. The routes need no direct starting-state fixture and do not use `--probe-sector`.

Choice and key handlers are dispatched by a test-only `PROCESS_ALWAYS` node during an ordinary `_process` callback. This preserves production handlers while avoiding an engine error from resuming the tree directly inside a physics-frame signal callback.

## Reproduce

From the project root:

```sh
mkdir -p /tmp/moksha-relayroute/{home,config,data,cache}
export HOME=/tmp/moksha-relayroute/home
export XDG_CONFIG_HOME=/tmp/moksha-relayroute/config
export XDG_DATA_HOME=/tmp/moksha-relayroute/data
export XDG_CACHE_HOME=/tmp/moksha-relayroute/cache
for hz in 60 120; do
  for sight in retained sacrificed; do
    arg=
    [ "$sight" = sacrificed ] && arg=--sacrifice
    godot --headless --path . --fixed-fps "$hz" \
      --script res://demo/tests/relay_works_route_bot.gd -- \
      --hz="$hz" --scene=res://demo/tests/relay_works_review.tscn $arg \
      > "/tmp/relay_works_route_clean_${hz}_${sight}.log" 2>&1
  done
done
python demo/tests/relay_works_route_summary.py
```

The summary validates completion, both actual sight states in the host metrics, three relay/open-shutter exits, archive interaction, pause, spawn acceptance, unchanged sources and clean logs before writing the aggregate.

## Superseded diagnostics and engine-log isolation

`relay_works_route_pre_dispatch_diagnostic_60hz_retained.json` preserves the first input-driven completion. It used the old floor-to-Dispatch ladder and a test-harness resume directly from a physics-frame signal. It is explicitly classified as a superseded diagnostic, not clean acceptance.

`relay_works_route_pause_probe.gd` independently isolates the timing issue. Normal idle, pause/resume, station choice and spawn-query probes are clean. Running it with `--physics-resume` intentionally resumes from a physics-frame signal and reproduces exactly two Godot `self_list.h:46` errors with the two active lifts. The ordinary-callback route harness avoids this path; no production physics change was required.

Initial bot diagnostics also exposed two navigation assumptions: an 18-pixel residual support beside a closed shutter must remain in the graph, and dropping onto an overlapping floor must choose the exit toward the current objective rather than that floor's midpoint. Both fixes are test-only. The initially embedded authored spawn was reported separately and corrected by the area owner before these final routes.
