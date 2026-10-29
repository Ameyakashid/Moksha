# Independent shared-projectile boundary review

Outcome: no remaining blocker in the reviewed scope on the recorded final source hashes.

## Final verification

- Exact production-source review copy, with no production source edits: 20 suite runs across 60 and 120 Hz, no script/runtime error diagnostics.
- 42 boundary scenario runs at each rate cover actual input-driven emission, outbound hit, lethal hit, physical reflection and lethal return, fake carrier/emitter rejection, translated parent placement, carrier/receiver geometry changes, ownership lifecycle, reflection scope retirement, terrain and cargo-layer obstruction, profile replacement, and Health callback retirement.
- A separate genuine-carrier subclass probe checks retirement immediately after the one-use claim at both rates. This variant changes one preload only in the review copy to select the probe subclass. Target Health remains unchanged and the response is retired_claim.
- 66 additional recorded outcome checks all pass. Obstruction and terminal suites assert 32 checks per rate; the unchanged stock Health/shield compatibility suite passes 46 scenarios / 214 checks per rate.
- Fresh import from a copy with no .godot cache is clean. The opt-in shared_ranged_actor scene then runs for 300 frames without diagnostics.
- All eight recorded production source hashes match the live source freeze and remain stable during the final exact-source runs.

## Defects found and corrected during review

1. Genuine attack-start events were rejected because the event's position field was absent from the strike snapshot.
2. World-space muzzle coordinates were assigned as local coordinates under translated parents.
3. Collider shape objects were incorrectly treated as collider shape indexes.
4. Duck-typed carriers and emitters could authorize damage or launch without a genuine controller action. Typed registered authority plus a one-use canonical launch claim now gate these paths.
5. Carrier shape changes and stale source transform/velocity changes were not fenced around collision callbacks.
6. A source validation callback could disable the receiver after the receiver's final generation check and still debit Health.
7. Reflected flights survived reflector disable, physics disable, world changes, and carrier disable/re-enable.
8. Reflection could proceed after the claimed receiver or defender body shape had been retired during the shield-effect callback.
9. Canonical snapshot construction dereferenced a null collider for real PhysicsServer2D-only bodies, bypassing the legacy lost_collider fallback.
10. Rejected/unconfigured carrier creation produced a settings access error instead of clean unauthorized-launch retirement.

Original failing logs and readable nonexecutable probe sources are retained separately from the final passing evidence.

## Important interpretation

Changing an equivalent source or target shape during capture rejects that captured scope. A later genuine new sweep may contact the still-eligible shape; the evidence records the capture and receipt physics frames separately and confirms the latter is newer.

Completed Health facts survive later retirement, including a reflected lethal hit that retires its own original emitter. A reset or Health notification suppression before damage_processed produces no invented applied-damage fact. New-life notifications are suppressed after reset.

## Limits

This is independent headless boundary and legacy compatibility review. It is not native visual/game-feel review, full route acceptance, production ranged/Warden migration, or universal simulation parity. The implementation owner's aggregate acceptance is separate.

## Files

- review_acceptance.json: run results, checks, exact source hashes, stability, and live-source comparison.
- final_logs/: all final exact-source runs, final post-claim variant, clean import and scene boot.
- original_failures/: original defect reproductions, preserved even after fixes.
- probes/: GDScript and Python probe text, suffixed .txt so this review packet does not add executable project scripts.
