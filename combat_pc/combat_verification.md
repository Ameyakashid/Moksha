# MOKSHA combat PC milestone 2 verification

**Passed at 120 Hz and 60 Hz:** 49 connected combat scenarios / 135 assertions per rate, plus all 36 original movement scenarios / 98 assertions per rate. Every run has zero failures and stable source hashes.

Both suites used actual Godot 4.6.3 physics callbacks, the production player scene, collision sweeps and space queries. The native-input case uses parsed keyboard events and the actor’s own `_physics_process`. The original project setting remains 120 Hz; 60 Hz is a process-local override.

Controller SHA-256: `3f0b054a88b1a4cd6dd61573ad85d83be416addea67b46b02cc6fcac83e0a588`. Exact profile, adapter, fixture, harness and legacy-prop hashes are in [combat_verification.json](combat_verification.json).

## Coverage

- **Roll phases, collision and clearance:** roll phases and held input -1; roll phases and held input 1; low ceiling roll expiry and clearance; high speed roll thin wall -1; high speed roll thin wall 1; landing during airborne roll keeps coherent action.
- **Roll air budget, cancellation and cooldown:** air roll preserves finite jump budget; ground roll leaves ledge then lands; roll jump buffer expires before cancel; roll jump buffer survives to cancel; roll attack cancel and simultaneous priority; roll cooldown buffer early expires; roll cooldown buffer late survives.
- **Melee phase permissions and cancellation:** melee permissions at phase boundaries; windup jump cancels pending strike; windup roll cancels pending strike; active roll buffer and recovery permission; external permissions intersect weapon phases; held melee and late recovery buffer.
- **Actual contact routing and identity:** close forward target overlaps actor origin -1; close forward target overlaps actor origin 1; actual contact dedup and facing -1; actual contact dedup and facing 1; wall occlusion blocks actual melee contact; narrow target swept between active samples; stale strike rejection after damage and reset; existing crate receives real melee launch.
- **Buffered input, local freeze and scene pause:** hitpause captures single roll edge; hitpause captures single attack edge; jump tap through hitpause released tap; jump tap through hitpause latest held repress; buffer expiration uses unfrozen actor time; disabled held input does not fabricate jump; disabled held input does not fabricate roll; disabled held input does not fabricate attack; pause freezes action and cooldown with moving support; native parsed combat input through local hitpause; hitpause cannot sweep stale carrier strike path; scene pause suspends active physics and resumes once.
- **Receiving hits, i-frame bounds and resets:** exclusive iframe end at nominal actor time; rollable hit iframe before_start; rollable hit iframe first_inside; rollable hit iframe last_inside; rollable hit iframe first_outside; unrollable damage clears active owners and intent; reset discards roll and pause; reset discards attack and pause; reset discards hurt and pause; hurt hitpause retains rising carrier clearance.

The compatibility rerun covers the prior connected run/reversal/jump/crouch/one-way/slope/ledge/reset flows. It uses the unchanged movement assertions and writes separate M2 traces; it is not counted as new combat coverage.

## Defects corrected and retested

- **Close forward contact rejected when hurtbox overlaps strike origin.** Actor x100, front target center104/width16 overlapped strike volume but received zero hits. Contact point uses target and sampled-strike intersection before forward-half-space and wall checks. Evidence: actual pre-fix 120 Hz failure.
- **Exclusive roll i-frame endpoint gained one sampled tick.** 24 advances at 120 Hz nominally reached .20 seconds; accumulated .19999999999999998 kept immunity and rejected damage. Combat comparisons absorb 1e-9-second arithmetic error; the exact .20 endpoint is outside immunity at both rates. Evidence: actual pre-fix 120 Hz failure.
- **Hurt freeze embedded the actor in a rising carrier.** Accepted damage discarded ground support before hitpause, allowing rising support to penetrate the frozen body. Temporary carrier transport survives hurt pause without granting floor budgets or changing recoil; detaches on resume. Evidence: actual pre-fix 120 Hz failure.
- **Disabled held input and earlier release latch could create incorrect resumed input.** Disabled intent preserves physical held history. A new jump press supersedes the older release latch. Evidence: code review corrected before physical repro.
- **Paused carrier travel could leave a damaging swept trail on resume.** Paused transport refreshes prior strike center without damage samples; delayed confirmations while paused are rejected. Evidence: code review corrected before physical repro.
- **Effective permission snapshot did not expose all existing arbitration denials.** Committed active and hurt snapshots expose denied roll/attack requests; final tests assert these host-facing fields. Evidence: motor self-review corrected before final acceptance.

Pre-fix physical failures and controller hashes are retained in [combat_defect_reproductions.json](tests/combat_defect_reproductions.json). Collision tolerances were retained. The crate test waits for two actual solver steps after the impulse before checking substantial forward speed and displacement.

## Rate comparison

| Measurement | 120 Hz | 60 Hz | Bound |
|---|---:|---:|---:|
| roll phases and held input -1: roll_seconds | 0.300000 | 0.300000 | 0.016667 |
| roll phases and held input -1: roll_distance | 88.564720 | 90.174236 | 6.416667 |
| roll phases and held input 1: roll_seconds | 0.300000 | 0.300000 | 0.016667 |
| roll phases and held input 1: roll_distance | 88.564667 | 90.174255 | 6.416667 |
| held melee and late recovery buffer: attack_seconds | 0.350000 | 0.350000 | 0.016667 |
| exclusive iframe end at nominal actor time: nominal_elapsed | 0.200000 | 0.200000 | 0.000000 |

Roll-distance tolerance is one 60 Hz step at the authored maximum roll speed. Duration tolerance is one 60 Hz sampled boundary. The .20-second exclusive immunity endpoint is checked using independently counted physics ticks. All eight prior movement cross-rate bounds also pass unchanged.

## Provenance and limits

The [combat audit](reference/DEAD_CELLS_COMBAT_AUDIT.md) uses Dead Cells repository pin `77c3ad263c4187ade6d048ba77bb61f79e6cec44`. It supports capability and weapon-phase architecture; the relevant motor and weapon-phase implementation bodies and tuning are absent. Tests use the authored [motor contract](MOTOR_CONTRACT.md) and MOKSHA profile resources.

- All roll, melee, damage-response and timing values are original MOKSHA tuning. No recovered Dead Cells motor values or executable parity are claimed.
- This is headless physical/input acceptance. Native animation and feel review are reported separately by the lab owner.
- No health/death system, enemy AI, combo expansion, parry or additional combat actions are claimed.
- Contact geometry is verified against axis-aligned passive rectangles, a real existing crate and solid-wall occlusion; arbitrary rotated or concave hurtbox contact-point fidelity is not established.
- The suite covers selected ordinary and adversarial geometry/input flows, not every arbitrary scene or profile value. Continued unavoidable crushing is outside this milestone.
- The legacy crate launch uses the real scene and PhysicsServer impulse integration. Its random spin and exact trajectory are not asserted.

All five original M1 harness/report/trace artifacts retain their recorded SHA-256 values. The preserved M1 ZIP SHA-256 is `6d5dc4bce621330273fd7607255b73344aa593256d4922d4e5a4c766f6b43411`.

## Reproduce

Run from the project directory with writable XDG locations:

```sh
mkdir -p /tmp/moksha-combat-test-data /tmp/moksha-combat-test-cache /tmp/moksha-combat-test-config
export XDG_DATA_HOME=/tmp/moksha-combat-test-data
export XDG_CACHE_HOME=/tmp/moksha-combat-test-cache
export XDG_CONFIG_HOME=/tmp/moksha-combat-test-config
godot --headless --fixed-fps 120 --path . --script combat_pc/tests/combat_regression.gd -- --hz=120
godot --headless --fixed-fps 60 --path . --script combat_pc/tests/combat_regression.gd -- --hz=60
```

For compatibility runs, copy `combat_pc/tests/movement_regression.gd` to `/tmp/moksha_m2_movement_compat.gd` and change only its output filename `results_%dhz%s.json` to `movement_compat_results_%dhz%s.json`. Run the same two commands with that temporary script. `--fixed-fps` accelerates wall-clock execution while real physics frames and solver calls remain active.

Rebuild the paired report with `python3 combat_pc/tests/build_combat_report.py`; it refuses failures, stale or differing source hashes, changed M1 artifacts, or exceeded cross-rate bounds.

Full traces: [combat 120 Hz](tests/combat_results_120hz.json), [combat 60 Hz](tests/combat_results_60hz.json), [movement compatibility 120 Hz](tests/movement_compat_results_120hz.json), [movement compatibility 60 Hz](tests/movement_compat_results_60hz.json).
