# Shield verification

**Passed at 120 Hz and 60 Hz:** 215 M8 scenarios and 930 assertions per rate. All seven earlier movement, combat, drop/dive, climb, wall, hard-landing and soft-slope suites pass against the same final controller. All sixteen runs have zero failed assertions and clean engine logs.

Controller SHA-256: `69b74005a5e2bae8e89287e1c089795de910bc4ebfcace2ecf880aad418cc7e4`. The [detailed report](shield_verification.json) pins profiles, harnesses, traces, logs, source evidence and historical preservation.

## Defense, physical effects and ownership

A finite accepted shield attempt has separate raise, parry, hold and recovery phases. Guard reports residual damage once; a full incoming parry closes its window before synchronous callbacks. Independent use-lock timing survives ordinary cancellation and pauses with actor time.

Direct incoming descriptor probes test resolver geometry, categories, identity and permissions. Separate fixtures establish actual swept-projectile, telescoping-blade and rigid-body solver contact. Counts below describe observed records rather than turning API calls into physical collision claims.

| Incoming route | Records at 120 Hz | Records at 60 Hz |
|---|---:|---:|
| actual rigid-body solver contact | 2 | 2 |
| actual swept projectile contact | 16 | 16 |
| actual telescoping blade contact | 10 | 10 |
| direct incoming API descriptor probe | 387 | 387 |

Incoming defense success does not imply a successful counter or redirect. Physical adapter results distinguish actual application from current-scope acknowledgement:

| Physics rate | Counters applied / confirmed | Redirects applied / confirmed | Later rigid return contacts | Applied without acknowledgement |
|---|---:|---:|---:|---:|
| 120 Hz | 6 / 4 | 6 / 6 | 2 | 2 |
| 60 Hz | 6 / 4 | 6 / 6 | 2 | 2 |

The applied-but-unacknowledged counter operations occurred before synchronous reset invalidated the request owner. They remain recorded as physical applications; the controller does not publish stale success. Later rigid return contacts are outgoing receiver collisions, not additional incoming parries. Frozen geometry and request scope govern outgoing effects.

Incoming history retains a bounded recent-ID range for each live authenticator and attack kind. Reset, freed carriers, reordered arrivals, stale IDs and callback ownership are assessed only within the exact recorded scenarios; the bound is not a global cap on every possible emitter.

## Timing and compatibility

All 142 profile-based timing checks and 814 cross-rate bounds pass. The latter retain all 743 M7 bounds without widening. All 56 contact-phase comparisons and 16 inherited stock/observer comparisons pass.

Shield opening and closing compare actual incoming snapshots with the effective per-case profile. Natural recovery and lock expiry use observed events and unpaused callback time. Explicitly scheduled projectile edges compare with descriptor probes at the same phase; rigid impacts are evaluated at their observed phase without assuming equal impact times from equal spawn positions.

| Suite | Scenarios per rate | Assertions per rate |
|---|---:|---:|
| shield | 215 | 930 |
| movement compatibility | 36 | 98 |
| combat compatibility | 49 | 135 |
| traversal compatibility | 64 | 222 |
| climb compatibility | 85 | 215 |
| wall compatibility | 146 | 478 |
| hard landing compatibility | 100 | 349 |
| soft slope compatibility | 146 | 893 |

## Corrections and preserved evidence

- **Structured incoming hurt could overwrite a newer synchronous host owner phase and continue stale feedback** Evidence: Implementation-side real-physics reproduction retained with its exact pre-fix source, harness and failing output; independent final cases cover admission, hurt-start and noise callback replacements.
- **Reset from a shield start or phase callback cleared the input dictionary while the old physics tick continued reading it** Evidence: Independent actual-physics trace and engine log contain missing x/jump_released errors in the admitted tick after synchronous reset. The preserved source is the exact tested 623955eb checkpoint.
- **Ordinary jump or air-jump completion incorrectly used forced cleanup and cancelled an independently held shield** Evidence: Real visual-integration replay retained the soft-landing cancellation on 623955eb. Independent mirrored final cases cover ground/air jump completion and distinguish hard-landing preemption.
- **The rigid defense bridge reported the penetrated prop-side point instead of the contacted actor surface** Evidence: Retained component-level 60 Hz solver observation and failing result distinguish local and collider contact coordinates. Independent final mirrored cases verify actual rigid contact, redirect, return receiver, noise and pause.
- **Pausing a rigid prop could retain an outdated Node pose and allow one already-committed physics displacement to appear afterward** Evidence: Retained component-level before-fix test reports 2.0969 px of paused travel. Independent final rigid cases enforce paused position and cleanup; the component suite separately verifies idempotent resume.

The [correction record](tests/shield_correction_evidence.json) identifies the precise final cases and available before evidence. Static review and recorded physical pre-fix failures are distinct evidence categories.

All 198 recorded historical acceptance artifacts and 7 milestone ZIPs retain their manifest hashes. These counts are computed from the preservation manifest. M8 compatibility files use separate output paths; prior reports and traces are unchanged.

## Scope

- The shield lifecycle, input policy, phase permissions, geometry, damage, impulses, timing and feedback are authored MOKSHA rules. The source audit establishes bounded concepts and historical developer statements, not recovered Dead Cells v35 executable parity or exact feel.
- Direct incoming-API descriptor probes exercise resolver contracts against actual actor geometry. They do not independently prove a projectile sweep, blade collision, or rigid-body solver contact. Those physical routes are counted and identified separately in the detailed report.
- An incoming parry is resolved before outgoing work. Adapter application and current-scope counter/redirect acknowledgement are separate evidence. A physical operation may have occurred before a synchronous callback resets its owner; that operation is retained as applied without a stale success acknowledgement.
- Incoming history is bounded per live authenticator and attack kind by an authored recent-ID window. It is not a fixed global memory cap: total entries depend on active buckets. Nearby out-of-order identities remain eligible; stale identities cannot regain eligibility through pruning. Projectile carriers authenticate independently of remote sources.
- M8 and inherited M7 samples include actual consecutive engine-frame IDs and callback deltas. Older compatibility formats only record consecutive actor ticks; they are not presented as independent engine-callback continuity proof.
- The original movement/combat harnesses start-pin smaller inventories than they end-pin. Every recorded start hash must match its end hash, every end hash must match current bytes, and the M8 harness pins its full recorded inventory at both ends. Historical formats are not rewritten to imply additional observations.
- Timing checks use each case's effective profile and actual contact/event samples. Local hitpause excludes whole paused callbacks from actor-time recovery and use-lock measurements. Rigid contacts are evaluated at their observed phase; equal spawn placement at different rates does not establish equal impact timing or require arbitrary pre-impact trajectory equality.
- Callback/lifecycle acceptance covers the exact recorded synchronous owner, gate, target, reset and delayed-confirmation cases. It does not authorize effects after request scope closes or prove arbitrary external adapter implementations safe.
- The shield remains within the existing shared movement/contact motor. No health, universal stamina, shield energy, grenade/fuse simulation, NPC behavior, progression or newly recovered source system is established. Native presentation/feel and packaged-project boot remain separate integration checks.

## Reproduce

From the project root, run the complete shield suite at both rates, without a group filter, and save each console stream as `combat_pc/tests/m8_shield_<rate>.log`:

```sh
XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 120 --path . --script combat_pc/tests/shield_regression.gd -- --hz=120
XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 60 --path . --script combat_pc/tests/shield_regression.gd -- --hz=60
```

Run the seven original compatibility harnesses with only output paths redirected to `<suite>_compat_m8_results_<rate>hz.json`, preserving movement's extra suffix placeholder. Save `m8_<suite>_<rate>.log`. After all final runs, redirect provenance and correction evidence are ready, run `python3 combat_pc/tests/build_shield_report.py`. It rejects filtered or incomplete runs, stale sources, failed assertions, unclean logs, changed historical bytes, missing callback samples and exceeded bounds before publishing either report.

Historical re-audits require the original evidence files and milestone ZIPs listed in the preservation manifest. They are not required to play the project. Each current scenario has exact JSON-pointer trace links in the detailed report.
