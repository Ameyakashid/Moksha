# Confirmed-strike target health verification

Date:2026-10-12. Engine:Godot4.6.3 stable official (`7d41c59c4`).

## Fresh focused results

-60Hz:43 scenarios,145 assertions,0 failures; actual review scene23 assertions,0 failures.
-120Hz:43 scenarios,145 assertions,0 failures; actual review scene23 assertions,0 failures.
-Discrete health outcomes match across rates. Runtime/harness hashes remain stable during each run.
-Import and all four runs have no script/runtime error or warning diagnostics.

The suite runs the unchanged PC once per actual physics callback, its original
ContactAdapter, and the passive existing MovementMotor. API malformed-input,
lifecycle and replay probes are explicitly separate from real contact cases.
Captured frames are evidence, not independent cases or assertions.

## What passed

1. Real left/right Slash, Backhand and Finisher contacts debit the unchanged Health
   component by1/1.15/1.8. Each retains exactly one independent knockback response.
2. Real three-step chains in both directions produce3→2→0.85→0. The final1.8 hit
   applies0.85, depletion occurs once, subsequent real overkill remains0, and the
   target stays enabled/settles on its floor. Explicit reset allows fresh strikes.
3. Misses, terrain occlusion and source reset during confirmation produce no health
   loss or knockback. Two real sources sharing a serial each count once.
4. Thirty malformed field/missing-field variants reject in an actual admitted
   source callback without consuming the eventual valid identity.
5. Duplicate callbacks and still-current replays after reset, rebind, disable/enable,
   component replacement and diagnostic clearing do not double-debit.
6. Earlier struck listeners reset, unbind, disable, detach, rebind, queue-remove or
   reset the source without allowing later old accounting. Already committed
   independent knockback remains an applied fact.
7. Health-change/damage listeners reset, unbind or remove safely; no stale depletion
   follows. Provider generation retirement before the Health slot rejects the receipt.
8. Binding ownership, invalid replacement, scene pause, processing disable, zero
   damage, huge finite overkill, noncurrent sources and source-query recursion pass.
9. With health absent, disabled, unbound and enabled, every recorded target motor
   position, velocity, pause, stun, collision and source-clock sample matches within
   each rate. Three real contacts remain three physical responses in every mode.
10. Actual review-scene Q comparisons pass left/right at both rates: OFF3HP with
    three contacts; ON0HP with real2/0.85/0 receipts. Reset, pause/resume, repeated Q
    interruption and1/2 switching pass. These key-handler checks do not claim native
    keyboard routing or rendered UI verification.

## Preservation and prior checkpoints

Existing Health, PC, contact adapter, knockback component, passive target/motor and
approved ground/air/chain resources are unchanged. The new fixture inherits the
previous target; the old knockback review remains available. Original checkpoint
reports are retained under their original names and are not relabelled as current.
Only launcher/documentation edits accompany the additive new files.

A separate pre-change fresh baseline run on2026-10-12 passed, at each60/120Hz:
knockback44 scenarios/157 assertions; current combo response79/274; light-chain
comparison13/42. Those baseline results are distinct from this new suite. They do
not imply a full rerun of every historical controller or visual test.

## Reproduce

`python3 combat_pc/tests/target_health_run.py --output-dir /tmp/moksha-health`

The runner uses isolated writable Godot config/cache directories, rejects diagnostics,
records exact source hashes and writes compressed traces plus a summary in the
chosen directory. Earlier generated reports are never overwritten. The source ZIP
includes runnable tests and this readable report; generated traces/logs are separate.

For a manual check, open `combat_pc/target_health_review.tscn` and press F6 (or F5
for the project default). Q compares,1/2 toggles health, J attacks, A/D moves, R
resets, F mirrors and Esc pauses. Capacity3 is demonstration tuning; no death, AI,
healing or combat-stat model has been added.

## Limits

No rendered viewport/manual playtest was possible in this executor (no native
display). UI pixels, input-device behavior and perceived feel are not certified.
No exact Dead Cells rules, REA-derived constants, full-game integration or complete
historical regression pass is claimed. Cross-rate comparison concerns discrete
health outcomes; physics trajectories are compared across component modes at each
rate, not asserted bit-identical between60 and120Hz.
