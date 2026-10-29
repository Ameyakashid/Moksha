# M12 optional health integration acceptance

Verified on 2026-10-05 with Godot 4.6.3 stable, using the real combat player scene and actual physics callbacks.

| Suite | 60 Hz | 120 Hz |
|---|---:|---:|
| Focused health integration, final component | 182 checks / 25 scenarios / 0 failures | 182 checks / 25 scenarios / 0 failures |
| Existing shield compatibility | 214 checks / 46 scenarios / 0 failures | 214 checks / 46 scenarios / 0 failures |

All 792 assertions in the reported suites passed. Each run's production hashes remained stable. The final health runs use the corrected component. Shield compatibility uses the same unchanged final actor with no health component attached; its reports retain the component's earlier hash as an incidental source snapshot and were not rewritten after the component-only fix.

One lifecycle defect was found and fixed: when a `health_changed` observer called `Health.queue_free()` at zero, the queued component still emitted `damage_processed` and `depleted` once each. The production fix checks component and actor lifetime, binding/change generation, and reset generation after each outgoing notification. The new regression verifies that both component and actor `queue_free()` callbacks suppress those stale signals. The focused probe passed 8/8 after the fix, and both cases also pass inside the final 60/120 Hz suites. The failing reproduction and passing rerun are preserved in `health_queue_free_before.log` and `health_queue_free_after.log`.

## Focused coverage

- Hurt subtracts the resolved amount; guard subtracts only residual damage; parry and roll evasion produce zero-damage receipts without spurious health changes
- Duplicate attack identities produce no second debit or defense/health notification; fresh reordered in-window IDs and identical local IDs from distinct sources remain independent; projectile identities use their carrier
- Out-of-window and malformed identities do not debit; legacy `receive_hit` booleans and independent legacy contacts remain compatible; negative damage cannot heal and nonfinite residuals cannot corrupt health
- Actor receipts and processed snapshots are read-only scalar dictionaries. Existing defense events precede the appended damage receipt
- Reset during hurt or defense callbacks suppresses old-generation receipts; reset before the health observer handles an already emitted receipt rejects that stale receipt
- A nested receipt with serial N+1 can reach health before outer serial N. Both debit once, and the processed before/after values follow actual delivery order
- Hurt replaced at `action_changed` has not committed and does not debit. Replacement at `hurt_started` retains the already committed debit and preserves the new host-owned motion/action
- Removed and queued-for-deletion actors cannot emit a later health receipt. Component detachment, repeated binding, replacement actor binding, invalid binding, and retained callbacks cannot charge the wrong store
- A reset or unbind during `health_changed`, or reset during `damage_processed`, suppresses stale outer notifications and depletion
- Queuing either the component or actor for deletion from `health_changed` suppresses subsequent `damage_processed` and `depleted` signals
- Overkill clamps health to zero, `applied` reflects only the actual debit, and `depleted` fires once per full-to-zero transition. Repeated damage at zero stays clamped. Actor reset opt-out and invalid maximum-health fallback are checked
- Real swept melee fixtures cover hurt and guard. A real moving projectile contacts the player's collision body and debits once
- Attached-versus-absent actors match exactly through 216 motor samples at 60 Hz and 432 at 120 Hz across running, turning, jumping, rolling, shielding, and melee. Original movement-event sequences match. All four defense results and subsequent recoil/pause/recovery match with and without the component

The focused suite executed 463 real physics callbacks at 60 Hz and 823 at 120 Hz. The driver verifies the requested delta and rejects duplicate sampling of the same engine physics frame. Reports contain bounded assertions and measurements; they omit per-tick dumps.

## Existing shield compatibility scope

`health_shield_compatibility.gd` inherits the existing shield regression and invokes its unchanged `outcomes`, `history`, `callbacks`, and `effects` groups. These cover defense outcomes and identities, bounded history, synchronous owner replacements, effect confirmation, actual counter contacts, and projectile reflection. Only orchestration and report output are new. Historical shield tests and results were not modified.

## Reproduce

From the project root, create writable Godot cache/data folders, then run each suite at both rates:

```sh
mkdir -p /tmp/moksha-health-cache /tmp/moksha-health-data
XDG_CACHE_HOME=/tmp/moksha-health-cache XDG_DATA_HOME=/tmp/moksha-health-data godot --headless --path . --script res://combat_pc/tests/health_regression.gd -- --hz=60
XDG_CACHE_HOME=/tmp/moksha-health-cache XDG_DATA_HOME=/tmp/moksha-health-data godot --headless --path . --script res://combat_pc/tests/health_regression.gd -- --hz=120
XDG_CACHE_HOME=/tmp/moksha-health-cache XDG_DATA_HOME=/tmp/moksha-health-data godot --headless --path . --script res://combat_pc/tests/health_shield_compatibility.gd -- --hz=60
XDG_CACHE_HOME=/tmp/moksha-health-cache XDG_DATA_HOME=/tmp/moksha-health-data godot --headless --path . --script res://combat_pc/tests/health_shield_compatibility.gd -- --hz=120
```

Focused outputs: `health_results_60hz.json`, `health_results_120hz.json`, `health_run_60.log`, and `health_run_120.log`.

Compatibility outputs: `health_shield_compatibility_60hz.json`, `health_shield_compatibility_120hz.json`, and the corresponding `.log` files.

Verified final SHA-256:

- `combat_pc/player.gd`: `0e6272b8203f30bcb65f51f776e2039d9c926f0b2aacff426b2984dc3a6861d1`
- `combat_pc/components/health_component.gd`: `ce42673d261a9d8638a53ce8221d341a283eafedb5e1c876b8f72874737f2d71`

The earlier component hash recorded by the unchanged-actor shield runs is `e9282c4e2666963476bca64df24867fdb894989ccfbacfbeaae32eddff9f1f00`.

This is headless integration acceptance. Native visual review is owned by the parent task. These checks do not introduce or claim death, healing, persistence, combat AI, or recovered Dead Cells numerical parity.
