# Ladder and vine verification

**Passed at 120 Hz and 60 Hz:** 85 connected climb scenarios / 215 assertions per rate. The unchanged M1 movement (36), M2 combat (49) and M3 traversal (64) scenarios also pass on this same revision. All eight runs have zero failures and stable sources.

Controller SHA-256: `3595e1b919b0fd7fff7be6eebf6b44e487e11fddcb744fa04c197848f8b49231`. [Detailed evidence](climb_verification.json) records exact profiles, components, harness hashes and every scenario’s trace pointer.

## Verified behavior

- Deliberate vertical entry and analog dominance; priority/distance/path selection after endpoint filtering; bounded swept alignment; ladder/vine ascent, braking, idle and descent.
- One-way top entry/exit and reversal, bottom/intermediate floors, thin walls, ceilings, moving sensors, blocked transport during normal time and hitpause, excessive movement, and stale broadphase entry rejection.
- Disabled, removed, rotated, negatively scaled, resized, transformed, replaced or withdrawn sensors; valid positive scaling and world-space rung metadata; ability, host and main-capability gates.
- Jump, roll, melee, dive, damage and horizontal detachment; denied actions preserve grip. One connected run spends air jump, dive and roll through their actual actions before attachment. Grip jumping preserves those spent budgets; a second supported jump requires physical reattachment.
- Regrab requires real neutral and elapsed simulation time. Input masking cannot fake neutral, and hitpause freezes the delay. Reset clears the grip lifecycle.
- Parsed A/D on one physics tick followed by Space on the next uses the authored 0.06-second recent-grip grace. Both sides, no-repeat, expiry, pause, invalidated support, host/cleanup gates and every replacement-action clearing path pass.

## Corrections verified

- **Adjacent horizontal release then Jump lost supported grip authority.** A profile-authored 0.06-second single-use grace retains only nearby valid grip support after horizontal release. It preserves spent budgets, freezes in hitpause and is cleared by accepted actions, invalidation or reset. Evidence: Native QA and direct parsed-event repro; fix independently verified at both rates.
- **A moved sensor could authorize entry from stale broadphase overlap.** Candidate selection also validates overlap with the sensor’s current declared horizontal span before starting alignment. Evidence: Direct physics repro before fix; independent retained regression afterward.
- **Endpoint selection, mutated sensor shapes and inherited one-way transport restrictions.** Directionally ineligible candidates filter before ranking; actual shape/type/transform and script changes invalidate grip; upward carrier motion respects the carried one-way restriction even during pause. Evidence: Static review corrected before independent physical probes.
- **Reversing a one-way top entry could leave the target ignored.** Top reversal uses an additional swept clearance rise before restoring the platform and settling back onto it. Evidence: Review correction independently physically verified.

The independent final suite found no remaining production failure. Review-driven corrections are distinguished from direct pre-fix repros in the JSON. Two initial harness assumptions were corrected: a still-live jump buffer can legitimately launch on reattachment, and cleared drop cleanup is separate from enough room to stand. No collision tolerance was loosened.

## Rate comparison

| Measurement | 120 Hz | 60 Hz | Allowed difference |
|---|---:|---:|---:|
| ladder deliberate align ascend stop descend: steady_rise_distance | 22.999878 | 23.000061 | 0.010000 |
| vine deliberate align ascend stop descend: steady_rise_distance | 22.999878 | 23.000061 | 0.010000 |
| ladder upward one-way top exit and held loop: top_exit_seconds | 1.083333 | 1.083333 | 0.033333 |

All 23 paired bounds pass, including the unchanged 20 earlier-milestone bounds. The steady climb interval is exactly 0.20 seconds and independently matches profile speed × time within 0.01 px. Top-exit duration comes from recorded attachment/exit event ticks and allows two 60 Hz boundary steps.

## Scope and preservation

- All climbing algorithms, sensor dimensions, speeds, timings, selection policy and grace are original MOKSHA choices. No recovered Dead Cells numbers or executable parity are claimed.
- Sensors must remain upright, positive-scale and consistent with their actual rectangular SensorShape. Rotation, negative scale, shape/script withdrawal and geometry mutation release attachment.
- Deterministic selection filters directionally valid candidates then sorts priority, axis distance and node path. Physics discovery is capped at 64 returned hits; arbitrary scenes beyond that local set are not covered.
- Grip jump remains subject to host jump permission, standing clearance and outstanding top-entry drop cleanup. The short grace applies only after horizontal release and only near the same still-valid sensor.
- The inherited drop-cleanup and invalid-geometry safety limits remain in force. This pass does not establish escape from physically impossible geometry.
- Headless acceptance uses real Godot physics and parsed keyboard events. Native presentation and feel review is recorded separately; this suite does not count animation parity, NPCs, wall-running, parry or extra combat systems.

All 27 prior accepted evidence files and all three milestone archives retain their recorded hashes. Compatibility outputs use new M4 filenames; earlier acceptances remain intact. The [motor contract](MOTOR_CONTRACT.md) and [pinned reference audit](reference/DEAD_CELLS_MOVEMENT_AUDIT.md) define the authored behavior and source-evidence boundary.

## Reproduce

Run from the project directory with writable XDG locations:

```sh
mkdir -p /tmp/moksha-combat-test-data /tmp/moksha-combat-test-cache /tmp/moksha-combat-test-config
export XDG_DATA_HOME=/tmp/moksha-combat-test-data
export XDG_CACHE_HOME=/tmp/moksha-combat-test-cache
export XDG_CONFIG_HOME=/tmp/moksha-combat-test-config
godot --headless --fixed-fps 120 --path . --script combat_pc/tests/climb_regression.gd -- --hz=120
godot --headless --fixed-fps 60 --path . --script combat_pc/tests/climb_regression.gd -- --hz=60
```

The climb script inherits unchanged M3/M2 harness helpers and overrides its run/output entry. `--fixed-fps` speeds wall-clock execution while actual physics callbacks, sweeps and queries remain active.

For compatibility, copy movement/combat/traversal scripts to `/tmp` and redirect only their result filenames to `movement_compat_m4_results_%dhz%s.json`, `combat_compat_m4_results_%dhz.json`, and `traversal_compat_m4_results_%dhz.json`. Run each at both rates. `python3 combat_pc/tests/build_climb_report.py` rebuilds this report and rejects failed, stale or mismatched runs, changed historical artifacts, and exceeded paired bounds.

Traces: [climb 120 Hz](tests/climb_results_120hz.json), [climb 60 Hz](tests/climb_results_60hz.json), plus the six `*_compat_m4_results_*hz.json` files indexed in the detailed report.
