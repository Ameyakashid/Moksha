# Held-input verification

**Passed at 120 Hz and 60 Hz:** 114 independent M10 scenarios and 333 assertions at each rate. All nine earlier suites also pass against the same final controller. All twenty complete runs have zero failed assertions, stable source hashes and clean engine logs.

Controller SHA-256: `c7c18b726210665df2304ff4aba190edda54816eaeb6fded1b44a63751f1987d`. The [detailed report](held_verification.json) pins the final harness, run traces, logs, production inputs, authored resources, research, correction proofs, 518 historical files and nine immutable snapshots.

## Selected authored MOKSHA policy

Null and fresh-only input profiles preserve ordinary fresh-press attacks. Optional repeat follows the existing three-step chain, or the null-chain single swing, with one synthetic offer per admitted callback. It uses the ordinary finite queue and reuse locks. A natural cycle must finish recovery and the 0.08-second actor-time restart before another begins. Release discards synthetic pending intent; a separately captured fresh tap keeps its documented finite buffer.

Charge uses a Starter Slash, opens its branch after 0.06 seconds of recovery, then begins its own clock at zero. An uninterrupted 0.45-second load automatically requests one Charged Thrust. Physical release is sampled before clocks and wins on the readiness callback. Continued holding cannot repeat or rearm the completed charge; a distinct release and admitted press is required. These values and choices are original MOKSHA policy, not recovered Dead Cells behavior.

| Step | Windup / active / recovery | Damage | Impulse | Prop scale |
|---|---|---:|---|---:|
| Starter Slash | 0.070 / 0.065 / 0.160 s | 1.0 | [240.0, -70.0] | 1.0 |
| Charged Thrust | 0.060 / 0.100 / 0.240 s | 2.6 | [360.0, -100.0] | 1.25 |

The thrust uses a 44×24 px contact volume, ordinary swept grounded speed of 260 px/s, 0.06-second contact pause and 1.25 strike loudness. Loading uses a 0.35 movement scale. Manual turning intersects host permissions; active entry freezes the strike-facing direction. No target seeking, extra gravity rule, hover, jump refund or airborne dash is introduced.

## Independent audit and real contact evidence

The auditor uses an independently transcribed case inventory and reconstructs profile boundaries from raw events and consecutive physics callbacks. It checks physical input edges, admitted hold identity, request identity/kind, charge identity and strike serial separately. Repeat requests retain their original physical edge, while each admitted strike receives its own serial. Release, expiry, configuration replacement, disable, hurt, reset and accepted traversal replacement cannot revive an old hold.

| Observed population | 120 Hz | 60 Hz |
|---|---:|---:|
| Committed strikes | 198 | 198 |
| Charge transition requests | 43 | 43 |
| Installed charged strikes | 39 | 39 |
| Actor contact admissions | 34 | 34 |
| Passive target effects applied | 30 | 30 |
| Passive target effects acknowledged afterward | 29 | 29 |
| Already-applied effects without later acknowledgement | 1 | 1 |
| Actual rigid-body launches acknowledged | 2 | 2 |

These are different populations. A charge transition callback can be superseded before a thrust is installed. A strike admission can be superseded before a receiver applies damage. The receiver-reset case applies one effect and then resets the source, so its later adapter acknowledgement is correctly absent. The contact-acknowledgement reset case retains its already-issued receipt. The real crate cases independently record rigid velocity, outward displacement, launch count, charge and a NoiseBus event at the actual launch position.

Mirrored target, whiff and occlusion cases, two targets in one sample, and synchronous callbacks verify per-strike deduplication and frozen payloads. Loading never emits a damage sample. Direct stale-authority API checks remain separate from these real adapter contacts.

## Timing, movement and compatibility

The new auditor passes 976 M10 profile timing checks. Across the ten paired suites, 2,314 numerical comparisons pass, including all 1,826 inherited bounds without widening or omission. Existing shield and combo timing/contact validators and prop-scaling checks run read-only on the new compatibility traces.

Charge, pending input, restart, reuse and shield clocks are checked independently. Callbacks beginning in local hitpause contribute no actor time; input capture still occurs. Ordinary phase endpoints allow one callback of quantization, and valid minimum phases allow up to three to preserve a real contact opportunity. Repeat restart permits two endpoint callbacks because request offers occur before clock advancement. No arbitrary delta or frame-rate equivalence is claimed.

Grounded, rising, falling, real slope support, a thin wall, a low roof, soft/hard landing, moving/removed support, one-way drop and climb/wall/dive transitions exercise the shared collision and resource budgets. Initial simultaneous shield input, already active nonholdable shield and shield reuse locks prevent parallel charge ownership. A denied readiness replacement leaves a valid charge intact; an accepted replacement wins.

| Suite | Scenarios per rate | Assertions at 120 Hz | Assertions at 60 Hz |
|---|---:|---:|---:|
| held | 114 | 333 | 333 |
| movement compatibility | 36 | 98 | 98 |
| combat compatibility | 49 | 135 | 135 |
| traversal compatibility | 64 | 222 | 222 |
| climb compatibility | 85 | 215 | 215 |
| wall compatibility | 146 | 478 | 478 |
| hard landing compatibility | 100 | 349 | 349 |
| soft slope compatibility | 146 | 893 | 893 |
| shield compatibility | 215 | 930 | 930 |
| combo compatibility | 295 | 1360 | 1384 |

## Corrections, evidence preservation and audit self-checks

- **Changing melee input configuration after a completed held-melee episode incorrectly retired an independent held shield because its unused input snapshot still triggered melee cleanup.** Evidence origin: Preserved implementation public-API physical before/after reproduction; independent current-case acceptance recorded separately. The final named cases are independently checked at both rates.
- **A valid minimum-duration starter could pass through all recovery within one callback and skip its eligible held-charge branch.** Evidence origin: Preserved implementation real-physics before/after reproduction; independent current minimum-phase acceptance recorded separately. The final named cases are independently checked at both rates.
- **A fresh queued repeat follow-up changed hold_id on the previous still-active strike, although its admitted physical input and request IDs remained unchanged.** Evidence origin: Independent actual-physics trace audit; exact complete before traces and harness retained. The final named cases are independently checked at both rates.

The initial paused-release draft incorrectly rejected a legitimate separate fresh press. That is retained as a harness clarification, not a production defect: the old charge identity must remain cancelled while a new physical press may create a new finite episode. Implementation-sourced before/after reproductions and independently discovered trace defects keep their distinct provenance in the [correction record](tests/held_correction_evidence.json).

7 in-memory corruption probes are rejected: changed hold provenance, changed charge-request linkage, duplicate commit, a charge clock advancing during pause, missing prop noise, missing rigid momentum and an acknowledgement without a target application. No retained evidence is modified by these probes.

All 518 recorded historical files and all nine M1–M9 snapshot archives retain their exact SHA-256 bytes. The nine earlier harnesses run with output paths redirected only; their logic, case order, parameters, assertions and numerical tolerances are preserved. Runtime/hash inventories are checked at both run endpoints and again before writing this report. Additional static transitive input hashes are labelled separately from run-time start/end evidence.

One initial combo120 compatibility process ended with external exit code -9 before completion and without an engine diagnostic. Its cause is unconfirmed. That attempt is retained separately and does not count toward acceptance. The same output-only harness was rerun alone; its complete 295-case/1,360-check result passed on the final controller. The [execution recovery record](tests/held_execution_recovery.json) pins both attempts.

## Limits

- Every duration, movement rule, impulse, damage value, repetition policy and cancellation rule is authored MOKSHA configuration. The reference source does not recover its charge scheduler or establish Dead Cells runtime parity.
- Physical input_id, admitted hold_id, request_id/request_kind and strike serial are separate identities. An observed charge_committed callback is an admission request; synchronous replacement may prevent installation of any thrust.
- Actor contact admissions, already applied passive-target effects, later adapter acknowledgements and actual rigid-body launches/noise are distinct populations. Direct API authority probes do not count as physical contacts.
- Reset cancellation exposes input_id zero after clearing consumed-input telemetry; its admitted origin is established by the matching attack_started event. Other strike identity fields must remain unchanged.
- A paused callback captures input and release but advances no actor clock. Ordinary phase endpoints allow one callback of quantization; minimum valid phases may retain up to three endpoint callbacks to guarantee an active contact opportunity. Repeat restart uses the preclock offer boundary and allows two.
- New held, M9, M8 and M7 formats record actual consecutive engine callbacks and deltas. Earlier compatibility formats establish consecutive actor ticks only; old movement/combat suites start-pin smaller inventories than they end-pin.
- Historical test logic is unchanged. Only output destinations are redirected, and their generated source bytes are checked against exact single replacements. Historical numerical bounds, files and nine snapshot archives remain unchanged.
- The intentionally invalid nonfinite-charge fixture uses the Godot overflow token 1e99999 only in its rejected input configuration. The auditor admits that exact leaf symbolically; all actor state, clocks, measurements and admitted profiles must be finite.
- Acceptance covers the named passive fixtures, the selected representative resources and recorded synchronous replacements. Native presentation, packaged boot and arbitrary custom content remain separate validation work.
