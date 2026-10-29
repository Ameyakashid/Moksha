# Soft-slope verification

**Passed at 120 Hz and 60 Hz:** 146 M7 scenarios / 893 assertions per rate. All six earlier movement, combat, drop/dive, climb, wall and hard-landing suites pass on the same final controller. Fourteen runs have zero failures and clean engine logs.

Controller SHA-256: `4aa4132650037e5c975de27547ef06c6dd1e95a3c7384d9744524de048a8760a`. [Detailed evidence](soft_slope_verification.json) pins sources, profiles, harnesses, traces, logs and preservation hashes.

## Contact and connected movement

- Mirrored 45° and 26.565° plane landings vary incoming X, downward speed and neutral/uphill/downhill intent; actual remaining X travel is checked separately from final velocity.
- Neutral approach heights 38/40 px retain stock/instrumented equivalence over two seconds. Neutral stops, steady held speed/travel and exact recorded callback continuity are verified.
- Continuous flats, hills, valleys, separate-body seams and the actual native-lab course at both fixture and native world origins retain contact. Disconnected gaps depart support; jumps, sidewalls, low ceilings, moving-support pause and targeted one-way drop remain collision-authoritative.
- Oversized host motion reaches the finite segment cap without crossing a thin wall. Same-instance reset, paused parsed taps, removed support, explicit upward host motion and synchronous ceiling replacement preserve lifecycle authority. Mirrored grounded-uphill ceiling callbacks must retire old floor evidence when a newer airborne hurt owner takes over, including through pause and resumed ticks.
- Shared roll, melee, hurt and hard recovery retain their finite action timing; preserved M6 scenarios cover history, queues, callbacks and landing ownership.

## Run coverage

| Suite | Scenarios per rate | Assertions per rate |
|---|---:|---:|
| soft slope | 146 | 893 |
| movement compatibility | 36 | 98 |
| combat compatibility | 49 | 135 |
| traversal compatibility | 64 | 222 |
| climb compatibility | 85 | 215 |
| wall compatibility | 146 | 478 |
| hard landing compatibility | 100 | 349 |

## Corrections and evidence

- **Ordinary floor projection created uncommanded horizontal velocity and residual X travel; an unsegmented two-pixel support probe also lost continuous downhill contact** Evidence: Independent real-physics baseline on the preserved M6 actor, including neutral 38/40 px approach phases and mirrored held movement. The retained baseline reproduces the earlier standalone slope diagnostics.
- **The first slope candidate fixed gross projection but recovery-only floor normals could be classified as walls, and redundant downward support corrections accumulated actual horizontal drift** Evidence: Independent 60 Hz stock/observer pairs on 0084. A recorded 45° tangent segment reports normal (0.760298, -0.649575), reduces X speed from 218 to 199.166 px/s, and moves 3.66898 px against 3.63333 px requested. The vertical probes add no X. Stock and observational traces match exactly.
- **The first contact refinement could select the neighboring facet at a shared concave-polygon vertex, stalling held motion or launching it off a continuous crest** Evidence: Independent d36 traces on mirrored 26.6°/45° hills and the actual slope-course scene, including its exact world origin and spawn phase. Recorded support loss and stalled root travel remain failures after accounting for initial grounded reset state.
- **An uphill grounded ceiling callback could accept upward hurt but stale floor evidence immediately regrounded the new owner and removed its upward impulse** Evidence: Independent mirrored replay of the retained 4245 controller at 120/60 Hz, with four failed assertions per rate covering immediate ownership and later resumed ascent. Only the class_name declaration is removed for loading alongside the current actor; all motion code is unchanged. Original and loaded source bytes are pinned.

The [correction record](tests/soft_slope_correction_evidence.json) retains the evidence category, exact final cases and available pre-fix artifacts. Physical pre-fix observations and static-review corrections are not treated as interchangeable proof.

## Rate bounds and preservation

All 743 cross-rate bounds pass, including the 55 inherited M6 bounds. All 40 within-rate approach-phase bounds and 16 complete stock/observer trace comparisons also pass. Continuous-join crossing times may differ by at most one 60 Hz tick plus 0.02 s. Plane comparisons start at each run's observed landing; they do not impose arbitrary pre-impact path equality.

All 135 recorded historical acceptance artifacts and 6 milestone snapshots retain their recorded hashes. Counts come from the preserved-evidence manifest. M7 outputs use separate filenames and do not overwrite earlier results.

## Scope and limitations

- This is original MOKSHA contact and locomotion policy. Neither Dead Cells executable behavior, slope algorithm, numerical tuning nor exact feel was recovered or established.
- Ordinary floor response preserves the current horizontal velocity and remaining requested X at each floor collision. Actual walls and ceilings may remove blocked components; no report bound requires travel through geometry.
- Ground following uses confirmed support, tangent displacement and bounded short swept segments with the existing 2 px floor probe and a 32-segment work cap. It does not authorize an enlarged generic ledge snap. Explicit upward departures and accepted jumps must retire following.
- Paired plane metrics are measured from each run's actual first landing. Equal arbitrary pre-impact trajectories are not required. Neutral stop, steady X velocity/travel, approach-height sensitivity, continuous-join timing and preserved action timing have separate justified bounds.
- Exact full-shape queries can observe overlaps within the authored collision skin. Independent plane/rectangle clearance checks bound penetration; acceptance is not a strict zero-overlap or arbitrary concave-world proof.
- M7 records an immediate before/after sample around one production call in every real engine physics callback, including engine-frame and delta checks. Historical compatibility harnesses retain their original recorded actor ticks; older formats do not independently record engine-frame IDs/deltas. Continuous recorded actor ticks alone are not represented as that stronger proof.
- The original movement/combat harnesses start-pin a smaller file inventory than their final hash inventory. Every recorded start hash must match its final hash, every final hash must match current bytes, and the new M7 harness start/end-pins the full actor/production inventory. Earlier formats are not rewritten to imply they recorded additional start hashes.
- Compatibility covers existing hard/roll/hurt outcomes, M6 excursion history, input queues, targeted one-way cleanup, carrier ordering and synchronous callbacks within the preserved fixtures. New floor travel can change legitimate collision positions; old numerical paths are not asserted identical.
- Unavoidable continuing crush, arbitrary custom profile extremes, exhaustive collision meshes, NPC behavior, health/respawn and new gameplay scope are not established. Native presentation/feel and final packaged-project boot remain separate integration checks.

## Reproduce

From the project root, run the complete M7 harness at both rates without a `--group` filter. Save each console stream to `combat_pc/tests/m7_soft_slope_<rate>.log`:

```sh
XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 120 --path . --script combat_pc/tests/soft_slope_regression.gd -- --hz=120
XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 60 --path . --script combat_pc/tests/soft_slope_regression.gd -- --hz=60
```

Run copies of the six original compatibility harnesses with only output filenames redirected to `<suite>_compat_m7_results_<rate>hz.json`, retaining the movement harness's extra output suffix placeholder. Save `m7_<suite>_<rate>.log`. After every final run and correction record is ready, run `python3 combat_pc/tests/build_soft_slope_report.py`. It rejects incomplete coverage, stale sources, failed assertions, mismatched logs, missing samples, changed historical bytes and exceeded bounds before writing reports.

Historical re-audits require the original datasets and milestone ZIPs listed in the preservation manifest. They are not needed merely to play the project. Current traces are indexed by exact JSON pointers in the [detailed report](soft_slope_verification.json).
