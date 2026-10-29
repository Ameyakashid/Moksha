# M18 ground presentation acceptance

The optional ground presentation passes the connected production motor/view checks at both 60 Hz and 120 Hz. No runtime file was edited by this verification task.

## Results

| Run | Scenarios | Behavior assertions | Real physics callbacks | Failures |
| --- | ---: | ---: | ---: | ---: |
| 60 Hz connected motor/view | 24 | 145 | 1,304 | 0 |
| 120 Hz connected motor/view | 24 | 145 | 2,470 | 0 |

Assertions summarize behaviors; they are not counted once per frame or bone. Every scenario verifies one production call per consecutive real engine callback, with the requested callback delta.

The original visual regression methods also pass: 10,107 inherited checks cover original geometry, timing, mirroring, foot plants, ledge grips, support motion, observer immutability, and headless drawing. That inherited count is not a count of new M18 behaviors. The wrapper writes only a new prefixed report and does not invoke the original output/sample exporter.

## What the connected runs establish

- From rest, an input opposite the actor's initial facing selects a fresh start on the first callback. No false turn overlays it.
- Start advances once to run. An uninterrupted reversal selects one monotonic turn phase through the velocity zero crossing, then run.
- Releasing during a live turn immediately selects brake, then idle. A fresh restart has no old turn or brake reappearance.
- Six interrupted same-direction taps and twenty left/right alternations with neutral interruptions remain responsive, match motor facing, and settle without residual velocity or stale pose.
- Real root travel advances run bones and the gait phase. The view never changes its local transform or the caller's telemetry dictionaries.
- A jump interrupts turn immediately. Real landing owns the contact pose; release and opposite restart during contact eventually return to run without resurrecting an old jump or turn.
- Real roll, attack, shield, hurt, defeat, and airborne ownership outrank the ground transients. Actual local hitpause freezes the full pose, facing, root, and gait, then accepts the new input on resumption.
- Resetting the actor during a turn clears the transient and allows a fresh opposite-facing rest start.

### Measured visible transient spans

These are counts of displayed callback samples, not claims of sub-frame timing precision. Both facings produce the same spans.

| Physics rate | Start | Turn | Brake |
| --- | ---: | ---: | ---: |
| Authored resource | 75 ms | 85 ms | 100 ms |
| 60 Hz observed | 83.33 ms | 100.00 ms | 100.00 ms |
| 120 Hz observed | 75.00 ms | 91.67 ms | 108.33 ms |

All are within one callback of the authored duration. The turn phase does not jump backward or disappear at the momentum crossing.

## Optional-null compatibility

The exact pre-M18 wireframe source is read from the retained v21 delivery ZIP, compiled in memory after removing only its global class declaration, and driven alongside the actual null-profile view with the same real motor events and snapshots. Full pose dictionaries are equal for all 66 observed callbacks at 60 Hz and all 126 at 120 Hz, covering rest, opposite-facing start, steady run, reversal, and neutral release. The archive is read-only and no copied runtime source is written.

The null profile deliberately retains the historical false rest-start turn and turn-before-brake priority. The opt-in candidate scenarios require the corrected behavior. Exact parity is established only for the stated real sequence; the inherited baseline suite covers the broader original geometry/lifecycle contract.

## Retained behavior and limits

A reversal during landing can switch land → land_run → land → land_run as its physical speed crosses the existing 35 px/s contact-family threshold. The contact phase remains monotonic through these switches and reaches run. This is a retained landing selection behavior, not a fresh ground-event phase reset.

These are headless motor-to-view observations and numerical pose checks. Native appearance and feel are reviewed separately by the parent task. No claim is made of animation or numerical parity with another game. The actual attack check uses the reusable player's default attack; this suite does not replace the existing optional combo/charge suites.

## Reproduce

From the directory containing `moksha`:

```sh
XDG_DATA_HOME=/tmp/m18-visual-data XDG_CONFIG_HOME=/tmp/m18-visual-config XDG_CACHE_HOME=/tmp/m18-visual-cache godot --headless --path moksha --script res://combat_pc/visuals/tests/ground_response_visual_regression.gd -- --hz=60
XDG_DATA_HOME=/tmp/m18-visual-data XDG_CONFIG_HOME=/tmp/m18-visual-config XDG_CACHE_HOME=/tmp/m18-visual-cache godot --headless --path moksha --script res://combat_pc/visuals/tests/ground_response_visual_regression.gd -- --hz=120
XDG_DATA_HOME=/tmp/m18-visual-data XDG_CONFIG_HOME=/tmp/m18-visual-config XDG_CACHE_HOME=/tmp/m18-visual-cache godot --headless --path moksha --script res://combat_pc/visuals/tests/ground_response_visual_baseline.gd
```

The connected acceptance harness requires the retained baseline ZIP at `../moksha-backups/M18-start-20261005/MOKSHA-Two-Level-Project.zip` relative to the Godot project. It fails explicitly if that exact reference cannot be opened; this is an evidence-harness prerequisite, not a runtime dependency. Godot 4.6.3 was used.

The per-rate JSON reports include each scenario's assertions, actual callback traces, event observations, measurements, and critical source hashes. Those source hashes were stable throughout both runs. The separate manifest pins all new deliverables and their current critical runtime inputs.
