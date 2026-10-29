# Expanded mission input-route validation

## Final frozen full-mission result

All four fresh full routes completed **seven substantial areas plus the ending**: Rainline, Quarantine Intake, Exchange, Freight Lock, Cistern, Relay Works, Lift Warden, and Above the Rain. Both sight choices were made at the actual Exchange station. No pre-run sight fixture is used in full-mission evidence.

| Physics Hz | Sight | Simulated active seconds | Defeated / authored | Bypassed | Archives | Deaths / retries |
|---|---|---:|---:|---:|---:|---:|
| 60 | retained | 152.450 | 40 / 46 | 6 | 2 / 5 | 0 / 0 |
| 60 | sacrificed | 145.067 | 41 / 46 | 5 | 3 / 5 | 0 / 0 |
| 120 | retained | 149.792 | 40 / 46 | 6 | 3 / 5 | 0 / 0 |
| 120 | sacrificed | 141.225 | 41 / 46 | 5 | 3 / 5 | 0 / 0 |

All four logs are clean, all reports have zero failures/source changes, and their shared 30 captured source hashes matched current bytes at aggregation. These are layout/AI-aware bot times, **not human-duration, difficulty, first-time-discovery or sonar-only-navigation validation**. Paused panels and the pause test do not count as active time. Headless results make no rendering-performance claim.

### Area times, simulated seconds

| Area | Retained 60 Hz | Sacrificed 60 Hz | Retained 120 Hz | Sacrificed 120 Hz |
|---|---:|---:|---:|---:|
| 01 / RAINLINE DISTRICT | 16.15 | 16.15 | 15.80 | 15.80 |
| 02 / QUARANTINE INTAKE | 23.98 | 23.98 | 24.36 | 24.36 |
| 03 / THE EXCHANGE | 15.13 | 14.40 | 15.17 | 14.22 |
| 04 / THE FREIGHT LOCK | 13.48 | 11.67 | 13.48 | 12.78 |
| 05 / THE CISTERN | 28.08 | 25.08 | 27.61 | 25.55 |
| 06 / RELAY WORKS | 39.18 | 40.37 | 37.01 | 34.95 |
| 07 / THE LIFT WARDEN | 14.15 | 11.60 | 14.09 | 11.75 |
| 08 / ABOVE THE RAIN | 2.28 | 1.82 | 2.28 | 1.81 |

## Freight Lock: independent direct and flank approaches

All eight isolated combinations also completed. Each delivered an intact designated crate through an actual fresh J attack, allowed it to settle naturally in the receiver, opened the real shutter and reached the isolated ending. These are separate experiments, not additional full-mission runs.

| Physics Hz | Sight | Approach | Simulated active seconds | Defeated | HP at Freight exit | Replacement requests |
|---|---|---|---:|---:|---:|---:|
| 60 | retained | direct | 16.550 | 2 / 3 | 60 / 60 | 0 |
| 60 | retained | flank | 16.617 | 0 / 3 | 60 / 60 | 0 |
| 60 | sacrificed | direct | 14.100 | 2 / 3 | 60 / 60 | 0 |
| 60 | sacrificed | flank | 15.233 | 0 / 3 | 60 / 60 | 0 |
| 120 | retained | direct | 16.242 | 2 / 3 | 60 / 60 | 0 |
| 120 | retained | flank | 16.383 | 0 / 3 | 60 / 60 | 0 |
| 120 | sacrificed | direct | 15.150 | 2 / 3 | 60 / 60 | 0 |
| 120 | sacrificed | flank | 14.867 | 0 / 3 | 60 / 60 | 0 |

The isolated room has no sight station. Its sacrificed-sight cases use an explicitly labeled, approved **pre-clock sight/profile fixture**. Their measured movement, combat, cargo delivery and door passage are ordinary input-driven gameplay. The full mission independently exercises actual Exchange choices.

## Closed-compartment recovery audit

All 24 separate recovery fixtures passed: both sides of each of the three closed barriers, at both physics rates and sight states. These fixtures explicitly place the PC at a floor start and set the sight profile before measured input. Thereafter they use ordinary movement/combat, leave every relay inactive, and keep all three physical shutters closed.

| Recovery case | Retained 60 Hz | Sacrificed 60 Hz | Retained 120 Hz | Sacrificed 120 Hz |
|---|---:|---:|---:|---:|
| service_left_floor_to_hub | 4.267 | 4.150 | 4.208 | 4.092 |
| service_hub_to_left_floor | 4.467 | 4.050 | 3.867 | 4.083 |
| lift_right_floor_to_upper_relay | 14.167 | 13.517 | 14.017 | 13.433 |
| lift_hub_to_right_floor | 5.633 | 5.133 | 5.233 | 4.883 |
| dispatch_right_floor_to_relay | 5.717 | 6.117 | 5.708 | 6.083 |
| dispatch_left_floor_to_relay | 12.217 | 10.133 | 12.175 | 10.500 |

The right-of-Lift fixture observes actual ascent and top exit at x1740. The right-of-Dispatch fixture observes ascent at x3610 followed by a normal leftward jump across the closed shutter onto the relay platform. Every final audit log is clean and its source manifest matches the frozen production bytes. These are reachability fixtures, not fresh full-mission or human playthroughs.

## Evidence

- `demo/evidence/expanded_mission_route_matrix.json`: full matrix, report/log hashes, area times and shared source manifest
- `demo/evidence/expanded_mission_route_{60,120}hz_{retained,sacrificed}.json`: four complete route traces
- `demo/evidence/expanded_mission_recovery_matrix.json`: 24 closed-compartment fixture cases, report/log hashes and source manifest
- `demo/evidence/freight_lock_route_matrix.json`: eight independent approach cases and source manifest
- `demo/evidence/freight_lock_route_{60,120}hz_{retained,sacrificed}_{direct,flank}.json`

Key production hashes:

- Host: `b16ad9c5f4dc8d1cff0d96ba95d8c9f79abe3b60e47d2886b75922df8efc6a99`
- Main data: `797ab96bfed8b8b63840b7410019ad14916e69859b159b04c0ac4f09826b28be`
- Freight area: `ca8f6478ea4b5ab48ca043632c788c3ee004b785245f8d59ae26a928d7533dd1`
- Freight receiver: `a86406967b12c52389479753604a8be08af2caf784a535d7a99a66ab3a8570c1`
- Relay Works area: `4d73aef6c03d70804dee756147da6e2451cf3c60339ac08accdb4466decb0069`
- Relay shutter: `4c54a922ab0905e978272764570ae542d2bf3b93d5c7ac2f5bfbb7ede9e7bdad`
- Sonar: `44cc08ad19b7716de1d58ca1aba6604b64f46519df9594c1c2198e48ee1b3642`

Original v27 `mission_route_*` and isolated Relay Works `relay_works_route_*` bots/reports remain preserved. Their captured sources describe earlier checkpoints; they do not certify the expanded current tree.

## Input method and boundaries

`expanded_mission_route_bot.gd` starts the actual main scene with the opening skipped and checkpoint persistence disabled. It sends raw PC button dictionaries, normal weapon taps and real proximity interactions. Key and choice handlers execute through an ordinary-process callback, avoiding the previously isolated Godot error from unpausing inside a physics-frame signal.

Navigation reads actual closed shutter collider bounds, including the independent freight shutter, and rebuilds when openings change. It uses real jumps, ladder ascent, ledge pulls and Down+Jump through one-way platforms. Receiver floor/lip/backstop solids are included. Combat uses fresh attack presses and guard; a normal roll is exercised at the ending. Pause/resume checks player position and active time freeze. Events retain area exits, remaining enemies, incoming damage, live cargo launch/latch data, sight choice, archive closing and recent physical traces.

Cargo is approached from its left and struck using J. The harness never calls `prop.launch`, applies a crate impulse, moves a crate, freezes it, changes its health, forces its receiver latch or disables a shutter. A replacement, if needed, uses the normal E interaction at the cradle. Full measured routes never teleport the player, write health, force kills/gates, disable AI/collision or manually tick the world. Ordinary host sector transitions and retries retain their normal behavior.

Route success is not a substitute for separate lifecycle/component tests or fresh native observation. Death and retry counts are reported above. Route completion alone is not treated as proof of the separate death/retry lifecycle contracts.

## Reproduce

From the project root:

```sh
mkdir -p /tmp/moksha-expanded-route/{home,config,data,cache}
export HOME=/tmp/moksha-expanded-route/home
export XDG_CONFIG_HOME=/tmp/moksha-expanded-route/config
export XDG_DATA_HOME=/tmp/moksha-expanded-route/data
export XDG_CACHE_HOME=/tmp/moksha-expanded-route/cache
for hz in 60 120; do
  for sight in retained sacrificed; do
    arg=
    [ "$sight" = sacrificed ] && arg=--sacrifice
    godot --headless --path . --fixed-fps "$hz" \
      --script res://demo/tests/expanded_mission_route_bot.gd -- \
      --hz="$hz" --sector-timeout=90 $arg \
      > "/tmp/expanded_mission_route_${hz}_${sight}.log" 2>&1
    for approach in direct flank; do
      godot --headless --path . --fixed-fps "$hz" \
        --script res://demo/tests/expanded_mission_route_bot.gd -- \
        --hz="$hz" --scene=res://demo/tests/freight_lock_review.tscn \
        --approach="$approach" $arg \
        > "/tmp/freight_lock_route_final_${hz}_${sight}_${approach}.log" 2>&1
    done
  done
done
python demo/tests/expanded_mission_route_summary.py
python demo/tests/expanded_mission_freight_summary.py
# Recovery fixtures (run each rate and sight combination):
godot --headless --path . --fixed-fps 60   --script res://demo/tests/expanded_mission_recovery_audit.gd -- --hz=60   > /tmp/expanded_mission_recovery_audit_60_retained.log 2>&1
# Repeat at120Hz and with --sacrifice; then:
python demo/tests/expanded_mission_recovery_summary.py
```

The full and Freight summary scripts require complete clean evidence, actual cargo launch/latch events, source identity and clean logs before writing their aggregates. Full-route aggregation also requires all eight completion metrics and a real Exchange choice.

## Diagnostic findings, kept separate

- `freight_lock_route_pre_backstop_*` records earlier successful staging/jump routes before the receiver's usability fix.
- `freight_lock_route_ladder_bot_diagnostic_60hz_sacrificed_flank.json` records a bot failure that jumped too early after a ladder. The harness now clears its stationary timer at actual top exit and requires grounded flank waypoints.
- Early bot diagnostics revealed a launch stance beneath a one-way platform and a shallow receiver-floor descent. Ordinary Down+Jump and a correct walk-off threshold fixed those planning errors.
- A real thin-backstop usability issue was reported: the PC requires pull-up landing support on the same physics body. The area owner widened the existing Backstop rightward to40 pixels while preserving its left cargo-contact face and top. The final matrix captures this corrected component; a separate adjacent platform was not treated as an equivalent fix.

- `expanded_mission_route_pre_recovery_60hz_retained.json` is the earlier complete 152.883-second full run before the recovery geometry fixes.
- `expanded_mission_route_recovery_diagnostic_60hz_sacrificed.json` preserves an interrupted full run that revealed an R-only floor pocket right of the closed Lift shutter. The area owner added a real floor-to-upper-platform recovery ladder at x1740. Four subsequent actual-fall routes (both rates/sight states) completed; their `relay_works_recovery_route_*` reports capture the intermediate pre-Dispatch-fix checkpoint.
- The same closed-compartment audit found the analogous Dispatch floor pocket. The owner added x3610's floor-to-relay-height ladder and its right-side shelf. The final24-case recovery fixture matrix validates both fixes with all shutters closed.
- `expanded_mission_recovery_caption_diagnostic_*` preserves any earlier recovery audit superseded by the final caption-only area edit. It is not mixed into the final matrix.

No diagnostic result is silently promoted into the final frozen matrix.
