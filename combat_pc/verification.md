# MOKSHA movement milestone 1 verification

**Connected movement passes at the project’s120 Hz physics rate and at60 Hz.** The accepted revision safely connects running, reversal, variable jump, finite air jump, ledge catch/hang/pull-up, release and landing. Moving-support timing and locked-facing catch defects found during this pass were corrected and retested.

These are original MOKSHA algorithms and profile values informed by the Dead Cells audit. This is not a recovered Dead Cells motor, exact-feel comparison or original-game parity claim.

## What was exercised

- Immediate permitted facing while opposite residual velocity brakes; authored acceleration, short stop and reversal in both directions
- Tap/held jump, one finite air jump, no held-repeat consumption, landing budget reset, authored coyote grace, valid and expired landing buffers
- Crouch through a22 px tunnel, safe blocked standing/jump, removal of overhead obstruction,4 px walls and an8× run-speed sweep stress
- Upward one-way crossing then landing; sustained uphill ground jump, reverse/downhill support and slope crouch/stand
- Actual running jump into left/right ledge catches, stable neutral hang, higher-arrival preservation, timed swept pull/step and supported finish
- Blocked top, down/away release, interruption during pull, removed/disabled/rotated/teleported support, newly inserted overhead obstacle and blocked moving transport
- A real second jump reaching a higher ledge with the air budget spent; hang/release does not create another air jump
- Moving hang and pull-up, followed by standing transport, without the earlier one-step collision-space overlap
- Independent move/turn permissions, locked-facing catch rejection, action-driver cancellation on jump, rapid input and reset after blocked traversal
- Parsed keyboard input through InputMap and the production automatic physics callback

## Problems corrected during verification

- **Moving-platform transform timing:** Anchors/validation/phase sweeps use committed physics transforms, then pending Node displacement is swept as support transport. Strict overlap and obstacle-reason checks now pass at both rates.
- **Facing permission during ledge catch:** Opposite-facing catches are rejected when can_turn is false; facing lock now remains authoritative.
- **Uphill grounding:** Ground-contact classification survives slope tangent motion. Both rates preserve ground jump budget, support and crouch clearance.
- **Independent turn permission and interrupted motion driver:** Independent can_turn is exercised with can_move=false; jump cancels prior driver. Both actual-physics scenarios pass.
- **Reset state and arrival continuity:** Reset-after-blocked-mantle clears immediate action/input/contact fields, and both-direction catch tests preserve the higher arrival root.

The most substantial issue was moving-platform timing: AnimatableBody2D’s node target could be ahead of its committed physics transform. Rays then sampled old geometry while the character followed a new anchor. At60 Hz this could lose a still-valid left-moving ledge; rising platforms also left a small body overlap. The corrected implementation separates committed-geometry solving from swept pending transport. The verifier retained its original strict overlap checks.

## Timing across physics rates

Both runs use the same controller/profile hashes. Input durations are expressed in seconds, including a1/30 s short jump press. Tolerances reflect discrete integration and phase boundaries rather than treating equal frame counts as equal time.

| Measurement |120 Hz |60 Hz | Allowed difference |
| --- | ---: | ---: | ---: |
| Stop time, seconds | 0.1250 | 0.1333 | 0.0167 |
| Stop distance, pixels | 11.9438 | 11.0444 | 3.6333 |
| Held jump apex, pixels | 59.0417 | 57.5278 | 3.0417 |
| Tap jump apex, pixels | 18.4611 | 17.6667 | 1.3750 |
| Held airborne duration, seconds | 0.5833 | 0.5833 | 0.0333 |
| Tap airborne duration, seconds | 0.2500 | 0.2500 | 0.0333 |
| Pull-up duration side-1, seconds | 0.3250 | 0.3500 | 0.0500 |
| Pull-up duration side1, seconds | 0.3250 | 0.3500 | 0.0500 |

All comparisons pass. Pull-up duration includes the start-input boundary plus separately quantized pull/step phases; each run also checks its duration against the profile and its own physics timestep.

## Reproducible evidence

- Controller SHA-256: `183a3ad30c9f278fabab1e7db5a71b5c2c861ec6d4a11d4a061e4dd3eadd330c`
- Harness: `combat_pc/tests/movement_regression.gd`
- Summary and exact file hashes: `combat_pc/verification.json`
- Input/telemetry/event/assertion traces: `combat_pc/tests/results_120hz.json` and `results_60hz.json`
- Godot 4.6.3-stable (official): 36 scenarios at each rate,98 assertions per run, zero failures; production source hashes remained stable throughout both runs

From the project root:

```sh
mkdir -p /tmp/moksha-combat-test-data /tmp/moksha-combat-test-cache /tmp/moksha-combat-test-config
env XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 120 --path . --script combat_pc/tests/movement_regression.gd -- --hz=120
env XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 60 --path . --script combat_pc/tests/movement_regression.gd -- --hz=60
```

`--fixed-fps` disables real-time synchronization for fast repeatable execution; actual Godot physics callbacks and collision-space queries still run. The120 Hz setting is the native project rate; the60 Hz override exists only within its test process. The project settings remain unchanged.

## Limits

- This verifies original MOKSHA behavior and profile values, not recovered Dead Cells code, numerical tuning, animation timing or executable parity.
- This is headless real-physics verification. Native visual/play-feel review is performed separately in the native app; no screenshot/UI review is claimed here.
- No roll, attack, parry, dive, damage or NPC behavior is implemented or counted. Extension hooks are tested only as movement permission/driver boundaries.
- There is no combat-hitpause API in milestone 1, so no hitpause integration is claimed.
- The moving-transport obstruction test stops its pushing fixture at safe release. Continued inescapable platform crushing and damage response remain outside this milestone.
- The suite covers the tested rectangular/one-way/ramp geometry, dynamic support changes and input sequences. It is not an exhaustive test of every arbitrary scene or customized profile.
- Fixture dimensions/input durations and numerical comparison tolerances are test setup; all motor speed/acceleration/jump/buffer expectations use the authored MOKSHA profile.

## Scenario inventory

- run brake reverse -1
- run brake reverse 1
- tap jump
- held jump
- finite double jump and air steering
- coyote window true
- coyote window false
- landing jump buffer once
- crouch tunnel release and safe standing
- thin wall sweep -1
- thin wall sweep 1
- one-way upward crossing then landing
- slope ascent support and ground jump
- slope reversal descent and crouch
- connected jump catch hang pull -1
- connected jump catch hang pull 1
- blocked headroom remains releasable
- ledge adversity moving
- ledge adversity removed
- ledge adversity away
- ledge adversity interrupted
- expired airborne jump buffer
- crouch jump under roof stays collision-safe
- high-speed thin wall -1
- reset from blocked ledge -1
- high-speed thin wall 1
- reset from blocked ledge 1
- dynamic ledge invalidation disabled
- dynamic ledge invalidation rotated
- dynamic ledge invalidation teleported
- dynamic ledge invalidation new_roof
- dynamic ledge invalidation transport_wall
- spent air jump is not refreshed by ledge
- locked facing cannot flip through ledge catch
- future action permissions and interrupt driver
- native parsed input drives physics
