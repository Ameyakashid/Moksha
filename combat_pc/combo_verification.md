# Chained-melee verification

**Passed at 120 Hz and 60 Hz:** 295 M9 scenarios at each rate; 1,360 assertions at 120 Hz and 1,384 at 60 Hz. All eight earlier suites pass against the same final controller. All eighteen runs have zero failed assertions and clean engine logs.

Controller SHA-256: `a1f37be07965aa1956dfb73d372b24579371a0178df44e7cc3805097a5550b99`. The [detailed report](combo_verification.json) pins the production sources, authored profiles, harnesses, traces, logs, source study and historical evidence.

## Authored chain and input ownership

The optional chain has three distinct step identities and original pose keys. Each accepted fresh edge commits one new strike serial and is consumed once. A single pending slot keeps the first accepted request without refreshing its deadline when extra presses arrive. The default policy has no automatic hold-repeat or charged branch. A null chain retains the single-swing fallback.

Every value below is authored MOKSHA tuning. Per-case profile overrides and admitted-episode snapshots are retained in the detailed evidence.

| Step | Pose | Windup / active / recovery, seconds | Next step | Prop launch scale |
|---|---|---|---|---:|
| 1: Slash | slash | 0.070 / 0.065 / 0.160 | 2 | 1.00 |
| 2: Backhand | backhand | 0.065 / 0.070 / 0.170 | 3 | 1.00 |
| 3: Finisher | finisher | 0.120 / 0.100 / 0.240 | ends chain | 1.25 |

Queue boundaries are evaluated at the observed pre-advance step age. Movement cancellation and turning use the phase reached after that callback advances. Idle retention, pending-input expiry, phase time, melee reuse lock and shield lock are distinct clocks. Host denial can defer a still-valid request; expiry and retirement prevent delayed unwanted attacks.

The eight step-2 recovery-entry cancellation cases deliberately differ by rate: their 0.020-second gate remains closed after the 120 Hz request tick but is open after the 60 Hz request tick. Each accepted transition adds three cleanup checks, explaining the 24-assertion difference. The builder independently reconstructs both outcomes from each profile and recorded pre-request sample.

## Actual contacts, payloads and callbacks

Physical receipts are tied to recorded Godot engine callbacks and eligible production-adapter strike samples. The builder checks strike, input, episode and pose identity; committed facing; shape; damage; impulse; and prop launch scale against the admitted step. In-place resource edits use the earlier episode snapshot until a new episode starts.

| Observed population | 120 Hz | 60 Hz |
|---|---:|---:|
| Actor contact admissions | 58 | 58 |
| Passive target effects applied | 37 | 37 |
| Passive target effects acknowledged afterward | 31 | 31 |
| Already-applied target effects without later acknowledgement | 6 | 6 |
| Actual prop launches acknowledged | 6 | 6 |
| Ineligible notifications caused by active-entry pause | 2 | 2 |

The 37 target applications and 37 combined adapter receipts are different populations: adapter receipts include six prop launches, while target applications include six receiver callbacks that apply their effect before replacing the owner. Those six effects remain counted, but no stale later acknowledgement is claimed. An actor admission by itself does not establish an applied receiver effect. Direct stale-serial/snapshot API probes and the recursive-tick refusal probe remain separate from actual physical contacts.

Mirrored hit, two-target, whiff and occlusion cases verify once-per-target-per-step behavior, later-step eligibility and once-per-strike contact pause. Reset/hurt/forced replacements at attack start, phase entry, noise, confirmation, pause, receiver and contact acknowledgement stop unapplied work. Resolved contact points remain frozen across relocation; removed or withdrawn targets cannot receive pending effects, and transport cannot create a sweep across a skipped world path.

All 8 same-rate prop-scaling checks pass. Backhand/Slash and Finisher/Slash horizontal-speed ratios match their profile ratios within 0.002 after the same two solver callbacks. Identical crate tuning and zero spin isolate the step-dependent launch strength; a merely positive impulse is insufficient.

## Clocks, movement and compatibility

All 2,024 M9 profile timing checks and 1,826 cross-rate numerical bounds pass. The latter retain all 814 inherited bounds without widening. All 56 inherited contact-phase comparisons, 16 stock/observer pairs and 142 shield timing checks pass.

Phase timings use cumulative unpaused actor time. Ordinary endpoints permit one callback of quantization. Valid sub-callback phases retain a real active sample even when entry feedback pauses them; their separately identified bound allows up to three endpoint callbacks. Ineligible entry notifications cannot stand in for that later eligible sample. Sampled pending deadlines, retention, melee locks and shield locks are independently recomputed, including their paused intervals.

The connected chain also covers mirrored slopes, thin-wall collision at high authored speed, a low roof, rising/apex/falling entry, soft and hard floor contact, spent air budgets, moving and removed supports, targeted one-way cleanup and ledge geometry. The falling cases retain ordinary gravity and airborne resources. Compatibility retains the earlier movement, combat, traversal, climb, wall, hard-landing, soft-slope and shield contracts.

| Suite | Scenarios at each rate | Assertions at 120 Hz | Assertions at 60 Hz |
|---|---:|---:|---:|
| combo | 295 | 1360 | 1384 |
| movement compatibility | 36 | 98 | 98 |
| combat compatibility | 49 | 135 | 135 |
| traversal compatibility | 64 | 222 | 222 |
| climb compatibility | 85 | 215 | 215 |
| wall compatibility | 146 | 478 | 478 |
| hard landing compatibility | 100 | 349 | 349 |
| soft slope compatibility | 146 | 893 | 893 |
| shield compatibility | 215 | 930 | 930 |

## Corrections and preservation

- **A strike-confirmation callback could retire the actor while the contact adapter still applied the old hit afterward** Evidence: Independent actual Godot physics contact through the production melee ContactAdapter.
- **A valid short active phase could lose its sole contact sample when entry feedback requested hitpause** Evidence: Preserved implementation physical reproduction and independent fixed-checkpoint actual-physics replay.
- **A pending fallback press could survive a chain-configuration round trip and later execute without a new edge** Evidence: Independent actual physics input sequence and production passive target contact.

The [correction record](tests/combo_correction_evidence.json) retains exact before-source hashes and final replay cases. The short-active-phase issue has implementation-sourced physical before evidence and an independently observed fixed checkpoint; it is not presented as an independent failing before replay.

All 384 recorded historical acceptance artifacts and 8 milestone ZIPs retain their recorded hashes. M9 compatibility traces use separate output filenames. The builder verifies that each redirected harness changes only its output path and that earlier scenario order, parameters and assertion totals remain intact.

## Scope and limitations

- Step count, timing, queues, cancellation, geometry, movement, damage, impulses and feedback are original MOKSHA policy. The source study does not establish recovered reference-game values, executable equivalence or exact feel.
- Direct strike-authority API probes, production-adapter passive target contacts and actual prop applications are separate evidence categories. A confirmed actor event alone does not establish that a receiver applied an effect.
- Reset clears consumed-input telemetry before its cancellation event, which therefore carries input_id zero. The cancellation keeps its prior strike, chain, step and pose; its original fresh edge is established by the matching attack_started event. Ordinary scheduled callbacks and the explicit recursive-API refusal probe are reported separately.
- An entry feedback pause may emit an ineligible active-phase notification. It is not an eligible contact sample or a target application. The finite short phase must retain a later eligible sample after pause.
- Actor clocks are measured from actual events and recorded callbacks. A callback beginning in local hitpause contributes no action-clock time. Unrelated shield locks retain their own observed lifetime.
- M9, M8 and M7 record consecutive actual engine-frame IDs and callback deltas. Older compatibility formats record consecutive actor ticks only and do not establish the stronger engine-callback observation.
- The original movement/combat suites start-pin smaller source inventories than they end-pin. Their recorded start hashes must match end hashes, and every end hash must match current bytes; historical formats are not rewritten.
- Acceptance covers the recorded passive fixtures and synchronous ownership replacements. It does not establish arbitrary custom profiles, adapters, collision meshes, NPC systems, health, progression or reference-game parity. Native presentation and packaged-project boot remain separate integration checks.

## Reproduce

From the project root, run the complete M9 suite without a group filter and save each console stream to `combat_pc/tests/m9_combo_<rate>.log`:

```sh
XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 120 --path . --script combat_pc/tests/combo_regression.gd -- --hz=120
XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 60 --path . --script combat_pc/tests/combo_regression.gd -- --hz=60
```

Run the eight original compatibility harnesses with only output filenames redirected to `<suite>_compat_m9_results_<rate>hz.json`, retaining movement's extra suffix placeholder. Save `m9_<suite>_<rate>.log`. The exact redirect identities are recorded in `tests/combo_compatibility_redirects.json`.

After all final evidence is ready, run `python3 combat_pc/tests/build_combo_report.py`. Add `--check-only` for the identical audit without writing reports. It rejects incomplete or filtered runs, stale sources, failed assertions, diagnostic logs, missing callback samples, changed historical bytes and exceeded bounds before publishing either report.

Historical re-audits require the original evidence files and milestone ZIPs listed in the preservation manifest. They are not required merely to play the project. Every M9 scenario has exact JSON-pointer trace links, per-rate assertions and per-rate parameters in the detailed report.
