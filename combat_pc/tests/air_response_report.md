# M19 ordinary air steering: physical acceptance

The focused candidate passes at 60 and 120 Hz in Godot 4.6.3. This is authored MOKSHA tuning. It does not establish numerical or executable parity with another game's controller.

The actual candidate resource is `combat_pc/resources/air_response_agile.tres`. Its baseline is the approved v22 `ground_response_agile.tres`, not the older original-ground profile. Every original MovementProfile scalar and the ground response resource remain equivalent. The sole opt-in tuning is ordinary airborne horizontal acceleration, 1450 → 2300 px/s². Run cap (218), neutral air drag (120), ground jump (365), air jump (350), gravity, release policy and action budgets remain unchanged.

## Measured response

All measurements below come from production calls in actual consecutive engine physics callbacks. Left and right measurements agree at both rates.

| Metric | 60 Hz baseline | 60 Hz candidate | 120 Hz baseline | 120 Hz candidate |
|---|---:|---:|---:|---:|
| Air start to 218 px/s | 166.7 ms | 100.0 ms | 158.3 ms | 100.0 ms |
| Reverse to zero crossing sample | 166.7 ms | 100.0 ms | 158.3 ms | 100.0 ms |
| Full +218 to −218 reversal | 316.7 ms | 200.0 ms | 308.3 ms | 191.7 ms |
| Forward overshoot during reversal | 14.575 px | 8.583 px | 15.481 px | 9.442 px |
| Neutral stop from cap | 1816.7 ms | 1816.7 ms | 1816.7 ms | 1816.7 ms |
| Neutral stop travel | 196.200 px | 196.200 px | 197.108 px | 197.108 px |
| Fixed correction landing error | 36.492 px | 12.333 px | 38.304 px | 14.090 px |

The correction example starts a real held jump at full speed, then reverses input after 0.25 seconds toward a marker at the launch point. Both variants land on the same wide physical floor. Candidate landing error is below 16 px at both rates. This is a deterministic illustration of available correction, not a general claim about player accuracy or narrow-platform success.

## Preserved behavior

- Held, released and double-jump tests retain the same vertical velocity, airtime, facing, air budgets and every local head/bone sample under matched input. At 60 Hz the recorded Y traces also match exactly. At 120 Hz the maximum double-jump Y difference is 0.000015259 px; the explicit Y tolerance is 0.00005 px. No presentation code changes are needed for these checks
- Neutral drift from an identical initial position and velocity has an identical complete sampled motion trace. Analog input, repeated taps, equal opposing input, rapid alternation and native physical-key parsing retain the 218 px/s cap and 120 px/s² neutral drag
- Coyote inside/outside cases, finite air-jump spending, landing replenishment, buffered and expired jumps, pause/resume, reset, invalid/null resources and shared-resource isolation pass
- Independent full-body clearance checks pass for thin walls, side-wall/upward-component separation, ceilings, ±0.5/±1 slopes, one-way ascent/touchdown, moving carrier departure and lower-support arrival. Grounded callback replacement retains newer hurt authority
- External disabled input, action input denial, movement denial, turn denial, zero movement scale and nonzero scaled analog input remain authoritative

Owner parity begins from a recorded identical state using common baseline setup, then selects the actual baseline/candidate resource. It compares only the excluded interval. All 34 pairs per rate have zero measured position and velocity error and identical sampled owner state. Covered categories in both directions: roll, wall kick, climb, ledge, drop (including a still-live drop exception after the main action ends), dive, hurt, weapon, held charge, shield, custom motion drivers returning true and false, external movement denial, disabled input, action input denial, zero scale and crouch. Separate post-retirement measurements establish 1450 versus 2300 ordinary steering without asserting that the subsequent trajectory should stay unchanged.

The archived-controller suite compiles the actual pinned v22 `player.gd`, removing only its global class registration to avoid a name collision. With the approved v22 profile, all 26 paired cases per rate exactly match the current controller's complete sampled physical/view state (excluding support instance IDs), plus event names and timing. It uses current shared dependencies; the separate M19 archive/provenance audit establishes protected dependency bytes. It verifies 324 of 327 original sources are byte-identical; only player.gd, movement_profile.gd and the parameter-ledger generator changed. The default runner performs this proof before physics tests.

## Evidence and scope

| Suite | Cases at each rate | Result |
|---|---:|---|
| Ordinary air response, jumps and contacts | 86 scenario runs | Pass |
| Excluded-owner/gate behavior | 34 baseline/candidate pairs plus 4 scaled analog runs (72 runs) | Pass |
| Actual archived v22 controller | 26 paired cases (52 runs) | Pass |
| Approved ground response and joins | 56 runs of retained fixtures | Pass |
| Retained health compatibility | 25 scenario runs | Pass |
| Retained defeat compatibility | 23 scenario runs | Pass |
| Retained noise compatibility | 28 scenario runs | Pass |
| Cross-rate, cross-variant and current-source audit | 70 behavioral comparisons | Pass |

Raw reports, assertions, measured traces and per-suite logs are the adjacent `air_response*_results_60hz.json`, `air_response*_results_120hz.json` and `air_response*hz.log` files. `air_response_run.log` records the final complete default runner invocation. `air_response_rate_comparison.json` checks that evidence hashes still match current source bytes, not only that sources were stable while a run occurred. No historical test/report file was edited by this pass.

Limits: these are headless physical and pose-telemetry checks, not native visual acceptance. Ledge owner parity covers catch, hang and a partial pull followed by release, not a full mantle. Dive parity covers startup/descent followed by public host retirement, not a new dive-impact matrix. Changed horizontal history can legitimately change a later collision or ledge acquisition. The suite does not claim whole post-release or post-kick arcs are equal, and does not count per-frame or per-bone samples as separate tests.

## Reproduce

Use Python 3 and Godot 4.6.3. From the project directory, first import a fresh extracted project, then run:

```sh
mkdir -p /tmp/moksha-m19-data /tmp/moksha-m19-cache /tmp/moksha-m19-config
XDG_DATA_HOME=/tmp/moksha-m19-data XDG_CACHE_HOME=/tmp/moksha-m19-cache XDG_CONFIG_HOME=/tmp/moksha-m19-config godot --headless --editor --path . --import --quit
python3 combat_pc/tests/air_response_run.py --godot-bin godot --baseline-zip /path/to/retained-v22/MOKSHA-Two-Level-Project.zip
```

`--godot-bin` also accepts an absolute executable path; `GODOT_BIN` may supply the default. The runner puts writable XDG data/cache/config under the system temporary directory, executes one production call per fixed-rate callback, rejects engine/script diagnostics and stale reports, and runs the cross-rate audit. It deliberately requires the retained v22 archive with SHA-256:

`ad1450d6451afb9943943d37af3a77dc6f543869635dcd5564867c5c2835a28c`

For one focused rerun use `--suites air --hz 120 --skip-comparison`. A targeted rerun is not a replacement for the final full acceptance command. The evidence-only audit is `python3 combat_pc/tests/air_response_compare_rates.py`.
