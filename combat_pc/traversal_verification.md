# Targeted one-way drop and dive verification

**Passed at 120 Hz and 60 Hz:** 64 connected traversal scenarios and 222 assertions per rate. All 36 M1 movement scenarios and 49 M2 combat scenarios also pass against the same controller. Every run has zero failures and stable source hashes.

Controller SHA-256: `6ed04e06c22d6f1354ea5add49f49e72463d6dadedf4c7d4940473227a1127f0`. [Detailed evidence](traversal_verification.json) contains exact profile, source, fixture and harness hashes plus scenario-to-trace mappings. The native project remains at 120 Hz; the second rate is overridden only within its test process.

## What passed

- Targeted upper-to-lower one-way dropping, dedicated coplanar multi-shape support, conservative mixed/stacked/rotated/nonrectangle/ambiguous refusal, independent thin solid walls through roll cancellation, and moving/disabled/removed targets.
- Ability, main-capability and host-permission gates; consumed fresh Down+Jump; frozen ground context that cannot become an airborne dive; native parsed keyboard input; fresh reset support classification.
- Full startup/descent/impact/recovery dive flow, the allowed/denied roll/jump/melee interruption matrix, forced damage and reset in every phase, ceiling collision, slope impact, missing-floor watchdog, support loss and actor hitpause.
- Independent exception cleanup after melee/damage/action expiry, explicit blocked cleanup and changed-geometry recovery, jump expansion guards, and a permitted small-body drop-expiry→dive path.
- One dive start per airborne trip, actual floor refill, semantic impact without fabricated melee damage, and no delayed impact after cancellation.

## Defects corrected

- **Removed one-way target left a stale PhysicsServer collision exception.** Actual 120 Hz removal during drop and blocked cleanup caused body_get_object_instance_id body=null errors; get_collision_exceptions retained the freed body entry. Controller retains target RID independently and uses a disconnectable tree_exiting callback to clear the exception before body destruction. Normal clearance and reset also disconnect it.
- **Fresh jump bypassed cleanup after the drop action ended or became melee.** Both actual 120 Hz probes accepted an air jump and expanded to standing while the ignored platform still overlapped the actor. Jump eligibility, effective permissions, can_stand and shape expansion now honor outstanding cleanup independently of the current action owner.

Both defects have retained [pre-fix physical traces](tests/traversal_defect_reproductions.json) and final passing repros. The earlier thin-wall diagnostic was corrected in the test query: Godot returns the query exclusion array by value, so the harness now constructs and assigns the complete list. This excludes only intentional one-way overlaps from the independent solid-overlap check; wall expectations and tolerances were not relaxed.

## Tight stacks and blocked conditions

At an upper top of 152 px, thickness of 6 px, and lower top of 192 px, the floor skin leaves no spare standing clearance: actor correctly stays crouched, clears old ignore, and accepts the first fresh second-drop chord. A lower top of 196 px (44 px separation) permits standing. Both ordinary and melee-interrupted variants pass.

Roll/melee/damage may replace the finite drop action while target cleanup remains. Plain jump remains blocked until cleanup clears. A fresh dive after drop owner expiry is permitted, retains the small collider and existing exception, then completes swept downward separation.

The .08-second drop action and .30-second cleanup deadline have different roles. An unresolved valid one-way overlap reports `drop_cleanup_blocked` once and keeps only that target exception; the actor can still move toward safe separation. Unsupported geometry replacing the overlapping target reports `drop_geometry_blocked` and stops motion until the host removes/separates it or resets the actor. These are explicit scene limits, not silent global collision disabling.

## Timing at both rates

| Measurement | 120 Hz | 60 Hz | Allowed difference |
|---|---:|---:|---:|
| startup_seconds | 0.083333 | 0.083333 | 0.016667 |
| impact_seconds | 0.066667 | 0.066667 | 0.016667 |
| recovery_seconds | 0.141667 | 0.150000 | 0.016667 |
| total_seconds | 0.775000 | 0.783333 | 0.066667 |
| max_fall_speed | 700.000000 | 700.000000 | 0.010000 |
| timeout_seconds | 2.083333 | 2.083333 | 0.033333 |

All 20 paired bounds pass, including the unchanged 14 M1/M2 bounds. Phase bounds are one 60 Hz sampled boundary; the complete connected dive allows its three authored boundaries plus actual floor contact. The missing-floor watchdog allows two phase boundaries.

## Provenance and limits

The [pinned movement audit](reference/DEAD_CELLS_MOVEMENT_AUDIT.md) supplies drop/dive declaration evidence and official interaction notes. Relevant implementation bodies are missing. This report tests the original MOKSHA [motor contract](MOTOR_CONTRACT.md), not exact Dead Cells behavior.

- All new algorithms, ability policy, durations, speeds and thresholds are original MOKSHA tuning. The pinned Dead Cells audit supports feature/interface intent, not recovered drop/dive bodies or exact-game parity.
- Only dedicated upright positive-scale rectangular one-way bodies with coplanar top surfaces are accepted. Mixed solid/one-way, stacked heights in one body, rotated/nonrectangle and ambiguous supports deliberately refuse.
- Drop action duration is finite. If valid one-way overlap prevents safe cleanup at the deadline, one scoped exception remains and a single blocked-cleanup event is reported until separation/removal/reset. This is explicit retained cleanup, not an unconditional finite collision-ignore promise.
- Changing an overlapping ignored body into unsupported solid/mixed/rotated geometry restores collision and freezes the actor in a reported drop_geometry_blocked state until separation/removal/reset. The suite verifies safe refusal and recovery, not escape from impossible geometry.
- Dive impact emits semantic/noise hooks only; no area damage, enemy AI, health/death, floor breakthrough or new combat system is claimed.
- Headless tests exercise real physics and parsed keyboard input. Native visual and feel review belongs to the lab owner.
- Selected adversarial geometry/profile cases are covered, not every arbitrary scene or value. The blocked-cleanup watchdog fixture deliberately sets gravity and current velocity to zero to prevent clearance without replacing collision queries.

All 14 accepted M1/M2 evidence artifacts remain byte-identical. Both milestone ZIP hashes were also checked. The new compatibility traces have separate filenames and do not replace those earlier acceptances.

## Reproduce

Run from the project directory with writable XDG data/cache/config directories:

```sh
mkdir -p /tmp/moksha-combat-test-data /tmp/moksha-combat-test-cache /tmp/moksha-combat-test-config
export XDG_DATA_HOME=/tmp/moksha-combat-test-data
export XDG_CACHE_HOME=/tmp/moksha-combat-test-cache
export XDG_CONFIG_HOME=/tmp/moksha-combat-test-config
godot --headless --fixed-fps 120 --path . --script combat_pc/tests/traversal_regression.gd -- --hz=120
godot --headless --fixed-fps 60 --path . --script combat_pc/tests/traversal_regression.gd -- --hz=60
```

The traversal script inherits unchanged M2 harness helpers and overrides its run entry and output path. It drives actual engine physics callbacks, the production scene, real collision sweeps and space queries. `--fixed-fps` accelerates wall-clock execution; it does not replace physics with field mocks.

For compatibility, copy the original movement/combat scripts to `/tmp` and change only their output filenames to `movement_compat_m3_results_%dhz%s.json` and `combat_compat_m3_results_%dhz.json`. Run each at both rates. Rebuild this report with `python3 combat_pc/tests/build_traversal_report.py`; it rejects failures, mismatched or stale source hashes, changed historical evidence, and exceeded paired bounds.

Traces: [traversal 120](tests/traversal_results_120hz.json), [traversal 60](tests/traversal_results_60hz.json), [movement compatibility 120](tests/movement_compat_m3_results_120hz.json), [movement compatibility 60](tests/movement_compat_m3_results_60hz.json), [combat compatibility 120](tests/combat_compat_m3_results_120hz.json), [combat compatibility 60](tests/combat_compat_m3_results_60hz.json).
