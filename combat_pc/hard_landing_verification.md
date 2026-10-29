# Hard-landing verification

**Passed at 120 Hz and 60 Hz:** 100 hard-landing scenarios / 349 assertions per rate. All five earlier movement, combat, drop/dive, climb and wall suites also pass on the same controller. Twelve runs have zero failures and clean engine logs.

Controller SHA-256: `55dd19f58275d91d86122dd44e602927618f168c380611ad1f07d0e527465b41`. [Detailed evidence](hard_landing_verification.json) pins tested production files, profiles, harnesses, traces and console logs.

## Connected behavior

- Optional trigger; below/at/above height and speed boundaries; both conditions required; final swept distance and relative moving-floor impact velocity.
- Ordinary and high/low dive impacts, exactly-once semantic/noise dispatch, bounded small-body impact/recovery, finite skid, host-facing gates, and fresh input before/at/after release.
- Independent airborne budgets; real jump/grip reset rules; no reset from roll/dive/weapon/hurt; carrier motion excluded; actual spent-resource landing and repeated same-instance reset.
- Exact active-dive roll protection through its own lifetime, including after i-frames, plus contact immediately before/at/after expiry and cancelled/startup/expired/post-impact exclusions.
- Native queued taps and latest repress through recovery and pause; host permission changes, disabled input, low headroom, floor removal, moving support, one-way stacked drops, thin geometry and mirrored slopes.
- Synchronous host callbacks retain newer hurt/forced ownership; the old landing transaction cannot continue stale setup, phase work or handoff over a newer owner.

## Corrections and evidence

- **Horizontal-only hard skid outran the floor probe on a continuous downhill slope.** Evidence: Direct pre-fix physical kernel reproduction; independently retained final slope cases.
- **A floor-sweep projection could replace authored incoming horizontal momentum before hard recovery.** Evidence: Independent physical trace before scoped hard-recovery policy refinement.
- **Zero pending Animatable translation overwrote nonzero solver surface velocity.** Evidence: Static review corrected before independent physical verification.
- **Requested rather than actual blocked carrier motion could alter fall history.** Evidence: Static review corrected before independent physical verification.
- **Fall history needed to begin at the actual supported release position.** Evidence: Static review refinement followed by independent physical verification.
- **A newer hurt owner from the actual dive-impact callback was overwritten by the pending hard-landing handoff.** Evidence: Independent physical before-fix trace.
- **Synchronous hard-start or phase callbacks could be overwritten by remaining setup from the retired owner.** Evidence: Direct pre-fix kernel reproduction followed by independent callback matrix.

The [correction evidence](tests/hard_landing_correction_evidence.json) distinguishes physical pre-fix traces from review corrections verified afterward. No collision tolerance was widened to hide a failure. Setup/observation clarifications are recorded in the JSON.

## Rate comparison and preservation

All 55 paired bounds pass, including the unchanged 28 previous bounds. Controlled slope tests preserve the same incoming X at both rates; recovery timing allows one boundary step. The project remains at 120 Hz, with 60 Hz used only as a runtime test override.

99 earlier artifacts and all five milestone ZIPs retain their hashes. TRACE_ARCHIVE.md has one intentional archive-instructions update, with before/after hashes and original text verified in the M5 snapshot. Current M6 traces and compatibility outputs are separate from earlier evidence.

## Scope

- All thresholds, fall-history resets, phase durations, skid braking, gates, queues and poses are authored MOKSHA policy. The pinned audit supports ordinary high-fall stun and the historical live-stomp-to-roll exception; no recovered Dead Cells numerical or executable parity is claimed.
- The optional hard-landing trigger defaults false; these fixtures explicitly enable it. The previous movement and combat contexts remain covered separately with their original settings.
- Trigger classification uses actual swept free-fall excursion and the downward Y component relative to the contacted floor. Carrier displacement is excluded; ordinary roll, dive, weapon and hurt ownership does not erase the excursion. Ground/grip and genuine fresh jumps have explicit reset policies.
- Only the exact roll accepted from live dive descent is protected, before its exclusive lifetime end. The protection is independent of combat i-frames. Startup, expired/post-impact dives and cancelled or ordinary rolls do not acquire persistent immunity.
- Hard recovery retains existing finite input buffers through its bounded phases. A hitpause requested by a synchronous mid-tick callback freezes subsequent callbacks; the already-admitted physics step may finish using the new owner. This policy does not roll back motion already processed.
- Hard recovery preserves incoming horizontal momentum and follows the confirmed floor tangent with swept braking. The inherited final collision travel and soft-land solver are not normalized; comparisons do not claim arbitrary frame-identical pre-impact paths.
- The landed hard flag records pre-callback physical qualification; current recovery ownership is reported separately by main_action and hard_land_active. A synchronous later hurt/forced reaction can legitimately preempt the recovery.
- The bounded fixtures cover rectangular/one-way floors, supported slopes, thin geometry, moving supports and explicit invalidation. They do not establish escape from an indefinitely advancing crusher, arbitrary collision meshes or a new hazard/health/respawn system.
- Headless acceptance uses actual Godot physics and parsed keyboard events. Native presentation, final export boot and subjective feel checks are separate; this report does not infer animation parity.

## Reproduce

Run the new harness with writable XDG paths, redirecting the console to the matching `combat_pc/tests/m6_hard_landing_<rate>.log`:

```sh
XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 120 --path . --script combat_pc/tests/hard_landing_regression.gd -- --hz=120
XDG_DATA_HOME=/tmp/moksha-combat-test-data XDG_CACHE_HOME=/tmp/moksha-combat-test-cache XDG_CONFIG_HOME=/tmp/moksha-combat-test-config godot --headless --fixed-fps 60 --path . --script combat_pc/tests/hard_landing_regression.gd -- --hz=60
```

For compatibility, copy movement/combat/traversal/climb/wall harnesses to `/tmp` and redirect only output filenames to `<suite>_compat_m6_results_%dhz.json` (movement retains its extra `%s` suffix). Save `m6_<suite>_<rate>.log`. Run `python3 combat_pc/tests/build_hard_landing_report.py` to reject stale sources, failed checks, engine errors, missing physics samples, changed historical evidence or exceeded bounds.

The current evidence is delivered separately in `MOKSHA-PC-Landing-Verification.zip`. Historical preservation re-audits also require the earlier datasets and original snapshots; they are not needed merely to play the project or execute a current regression.

Traces: [landing 120 Hz](tests/hard_landing_results_120hz.json), [landing 60 Hz](tests/hard_landing_results_60hz.json), and ten `*_compat_m6_results_*hz.json` files indexed in the detailed report.
