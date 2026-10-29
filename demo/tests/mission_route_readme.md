# Mission route validation

## Final frozen result

**All four fresh input-driven runs passed the final six substantial areas plus the ending.** Both 60 Hz and 120 Hz lifecycle suites passed **34 assertions each**. There were no route failures, deaths, retries, source changes, runtime errors or warnings in these final runs.

| Physics rate | Sight choice | Simulated active seconds | Defeated / authored | Bypassed | Archives | Deaths / retries |
|---|---|---:|---:|---:|---:|---:|
| 60 Hz | retained | 135.900 | 34 / 42 | 8 | 3 / 5 | 0 / 0 |
| 60 Hz | sacrificed | 120.817 | 33 / 42 | 9 | 3 / 5 | 0 / 0 |
| 120 Hz | retained | 130.567 | 34 / 42 | 8 | 3 / 5 | 0 / 0 |
| 120 Hz | sacrificed | 120.658 | 34 / 42 | 8 | 3 / 5 | 0 / 0 |

These are simulated active times for a fast layout/AI-aware bot. **They do not validate a 15–30-minute human duration, human difficulty, or blind navigation using only sonar.** The bot bypassed some optional enemies and two optional archives. Native visual, audio and performance review is separate.

## Final evidence and reproducibility

- `demo/evidence/mission_route_frozen_matrix.json`: aggregate results, exact report SHA-256 values, per-area times, incoming damage outcomes, and the shared frozen source-hash manifest.
- `demo/evidence/mission_route_60hz_retained.json`
- `demo/evidence/mission_route_60hz_sacrificed.json`
- `demo/evidence/mission_route_120hz_retained.json`
- `demo/evidence/mission_route_120hz_sacrificed.json`
- `demo/evidence/mission_route_lifecycle_60hz.json`
- `demo/evidence/mission_route_lifecycle_120hz.json`

All four runs captured identical SHA-256 values for the production `.gd`/`.tscn` files directly in `demo/` and `demo/components/`, including the mission scene, opening component and sonar wrapper, plus the preserved PC and this route bot. The captured hashes also matched the current files when the aggregate was generated. A changed captured source makes the route test fail. Other independently authored test files are deliberately excluded.

### Area times, simulated seconds

| Area | Retained 60 Hz | Sacrificed 60 Hz | Retained 120 Hz | Sacrificed 120 Hz |
|---|---:|---:|---:|---:|
| Rainline District | 17.72 | 17.72 | 16.36 | 16.36 |
| Quarantine Intake | 23.18 | 23.18 | 24.00 | 24.00 |
| The Exchange | 15.37 | 14.77 | 15.17 | 14.22 |
| The Cistern | 28.10 | 24.65 | 27.54 | 24.78 |
| The Listening Works | 30.78 | 26.88 | 30.77 | 26.93 |
| The Lift Warden | 18.47 | 11.80 | 14.43 | 12.56 |
| Above the Rain / ending | 2.28 | 1.82 | 2.28 | 1.81 |

## What the route test does

`mission_route_bot.gd` starts the production mission afresh with the opening skipped. It reads geometry and AI state to plan its route, then sends only ordinary raw PC button dictionaries and the production key/interaction handlers. It builds a directed platform graph, chooses inactive relays in order, crosses physical gaps and ledges, uses up/neutral inputs for ladders, closes archive panels with E, fights with fresh attack presses and guard input, makes the explicit sight choice, and performs a normal roll. Every onward interaction uses the host's real proximity and gate checks.

Measured routes never change the player's position, health or collision; never force kills, gates or enemy state; never disable AI; and never manually tick the world outside the production physics loop. Checkpoint persistence is disabled during routes. All seven completion metrics are required. A pause/resume check verifies both the player and active timer freeze. Events record per-area exits, remaining enemies, relay counts, ladder transitions and incoming damage. Recent traces retain exact positions, velocities, AI states and navigation targets for blockers.

The bot is intentionally much better informed than a human player, including on sacrificed-sight routes. Headless route success establishes mechanics and reachability rather than the quality of the sensory experience. Ordinary physics contacts and rigid-body interactions can produce small route-time differences between runs; no frame-perfect human benchmark is claimed.

## Separate lifecycle fixtures: 34 assertions per rate

`mission_route_lifecycle.gd` deliberately uses direct state/position fixtures, kept outside route completion and timing evidence. It checks:

- Title, new mission, opening skip and normal input movement
- Pause freezes movement and active time; resume restores both
- Retained and sacrificed sight, including the advertised +25% run/roll values
- Optional cache collection, paused archive reading, excluded reading time and E-to-close
- PC damage receipt → attached Health → DefeatResponse, with idempotent defeat handling
- Retry after defeat and from pause, restoring spawn/full health while retaining sight and archives
- Ending, title return, and clean fresh replay
- Schema-2 checkpoint validation and continue restoring sector, sight, statistics, caches and previous area metrics

Save fixtures refuse to write unless the process's user-data directory is under `/tmp/`. Their state writes are not treated as gameplay accomplishments.

## Run again

From the project root, use writable temporary application directories:

```sh
mkdir -p /tmp/moksha-route/{home,config,data,cache}
export HOME=/tmp/moksha-route/home
export XDG_CONFIG_HOME=/tmp/moksha-route/config
export XDG_DATA_HOME=/tmp/moksha-route/data
export XDG_CACHE_HOME=/tmp/moksha-route/cache
godot --headless --path . --fixed-fps 60 --script res://demo/tests/mission_route_bot.gd -- --hz=60
godot --headless --path . --fixed-fps 60 --script res://demo/tests/mission_route_bot.gd -- --hz=60 --sacrifice
godot --headless --path . --fixed-fps 120 --script res://demo/tests/mission_route_bot.gd -- --hz=120
godot --headless --path . --fixed-fps 120 --script res://demo/tests/mission_route_bot.gd -- --hz=120 --sacrifice
godot --headless --path . --fixed-fps 60 --script res://demo/tests/mission_route_lifecycle.gd -- --hz=60
godot --headless --path . --fixed-fps 120 --script res://demo/tests/mission_route_lifecycle.gd -- --hz=120
python demo/tests/mission_route_summary.py
```

`--probe-sector=N` is an explicitly labeled direct sector-start diagnostic. Its `_probeN.json` output is excluded from full-route evidence. Do not confuse a successful sector probe with a fresh full completion.

## Superseded diagnostics, retained separately

- `mission_route_baseline_*hz_*.json` and `mission_route_baseline_bot.gd` describe the abandoned compact twelve-sector layout. They are not evidence for the current six-area mission.
- `mission_route_polish_pre_sonarfix_*hz_*.json` preserve the earlier polished-layout matrix. Gameplay completed, but the two 120 Hz runs correctly flagged a sonar source change during execution. The frozen matrix above replaces them.
- `mission_route_bot_initial_failure.json` preserves an early bot-navigation failure that spent its air jump too soon. It was not classified as a production defect.
- `_probe5.json` records a direct Listening Works diagnostic. Releasing/regripping and waiting for ladder top exit before attacking solved the bot's repeated detach loop. No production geometry change was needed.

Do not combine timings from these different layouts or source versions into a single pacing claim.
