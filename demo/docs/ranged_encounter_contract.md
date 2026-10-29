# Reusable ranged sentry

`demo/components/ranged_enemy.tscn` inherits the existing DemoEnemy scene and extends its demo-only script. The original MovementMotor, Hurtbox, StrikeKnockback, StrikeHealth and scalar Health components remain in charge of movement and incoming sword/prop damage. This feature does not edit any preserved combat or movement component.

## Host integration

Instantiate `res://demo/components/ranged_enemy.tscn`, set encounter overrides before adding it to a Node2D room, then call `configure(player, event_bus)`. The intended player is the unchanged `combat_pc/player.tscn`; the optional event bus is the existing NoiseBus. Scene default `kind` is `sentry`; the host can use `sentry` or `ranged` as its data tag and select this scene accordingly. The tag does not switch its behavior.

It retains the base enemy contract:

- `dead`, read-only `health`, `ai_state`, `attack_serial`, and `last_attack_result`.
- `defeated(enemy)` once per life, plus `attack_resolved(enemy, result)` for outgoing stock-PC results while the shooter survives.
- `configure(player, bus)`, `set_room_bounds(left, right, floor_y)`, `set_blind_mode(value)`, `reset()` and `reset_at(position)`.
- Body layer **32**, mask **9**; sword Hurtbox layer **4**. Props should use mask **33**.
- `enemies` and `actors` groups; inherited health/knockback, melee counter, corpse, reset and sonar-facing shape behavior.

Ranged additions:

- `projectile_launched(enemy, projectile)` emits once per released carrier.
- `shots_fired` is a lifetime diagnostic count; `projectile_epoch` fences live carriers across reset, death and source exit.
- `receive_guard_projectile(payload)` accepts a physically swept, reflected demo carrier, deduplicates its identity and feeds the same Health provider.
- Projectiles join `demo_projectiles`; they are room-owned siblings of the sentry, and also explicitly retired if their shooter leaves.

No host polling, separate projectile service, extra autoload or custom player action is required.

## Authored encounter values

| Property | Default |
| --- | ---: |
| Health | 2 |
| Windup | 0.72 seconds |
| Recovery | 0.95 seconds |
| Reposition interval after recovery | 0.30 seconds |
| Base movement speed | 58 px/s |
| Detection range | 430 px |
| Desired distance | 170 px |
| Retreat threshold | 115 px |
| Projectile speed | 245 px/s |
| Shot damage | 1 |
| Reflected damage | 2 |
| Projectile radius | 3 px |
| Projectile lifetime | 2.2 seconds |

Inherited `max_health`, `movement_speed`, `windup_override`, `attack_damage_override` and `detection_range` tune the sentry. Additional exports are `projectile_speed`, `preferred_distance`, `minimum_distance`, `projectile_lifetime` and `reflected_damage`.

A sentry holds its lane when it cannot see the player. When visible, it modestly approaches distant targets or retreats from close ones during its short reposition window. The existing actual-terrain support rays and room limits stop it at ledges. It still commits to an attack at close range: players can interrupt it instead of chasing an indefinitely retreating enemy.

Aim is captured at the start of the full windup. Movement during the telegraph does not cause a homing shot. The inherited warning ring plus a short aim line and bow/antenna silhouette distinguish it from melee enemies. Its real-world warning emits `enemy_windup`; release emits `enemy_attack` from the muzzle. Damage and defeat use the base `enemy_damage` and `enemy_death` events. Blind presentation follows `set_blind_mode`; the host can alternatively apply its normal whole-world sensory blackout.

## Physics, defense and lifecycle

The demo projectile extends `combat_pc/fixtures/guard_projectile.gd`, preserving its circular `move_and_collide` sweep. Initial mask **3** includes terrain1 and player2. It cannot tunnel through a one-pixel wall between frames. The sentry checks terrain visibility before commitment and again from its body to the muzzle and along the committed aim line at release, so a closing door does not create a bolt on its far side.

The preserved carrier owns the call to the stock PC's `receive_attack()`. Its real source, contact, incoming velocity and identity reach the existing guard/parry/roll decisions. A held front shield absorbs the stock 75 percent. A correctly timed shield physically redirects the same carrier through the unchanged ShieldContactAdapter. After that accepted redirect, the demo changes its mask to **33**, allowing it to sweep terrain and enemy bodies while the preserved carrier removes its original shooter collision exception and adds its defender exception. The returned bolt deals two damage, making one accurate reflection enough to kill a fresh sentry. Other sentries can receive the same returned carrier.

Only one incoming contact is committed per carrier. Reflected hits validate live carrier, owner, attack identity and contact before applying a generation-stamped receipt through StrikeHealth to scalar Health. Death and reset synchronously retire every owned carrier; deleting only the sentry also retires room-sibling shots. Removing the room removes both. Each carrier additionally checks its live shooter and generation every physics callback and expires within its bounded lifetime. No timer or deferred fire callback can release after a canceled windup.

## Verification

From the project root:

```sh
for hz in 60 120; do
  XDG_DATA_HOME=/tmp/moksha_ranged_data \
  XDG_CONFIG_HOME=/tmp/moksha_ranged_config \
  XDG_CACHE_HOME=/tmp/moksha_ranged_cache \
  /usr/local/bin/godot --headless --path . --fixed-fps "$hz" \
    --script res://demo/tests/ranged_regression.gd -- --hz="$hz"
done
```

Both 60 and 120 Hz pass **16 scenarios / 74 checks / 0 failures**. Evidence is in `demo/tests/ranged_results_60hz.json` and `ranged_results_120hz.json`.

Actual Godot callbacks drive the stock PC and physical carrier. Coverage includes direct hit and no double-hit, held guard, timed reflection killing its original shooter through scalar health, canonical noise provenance, preexisting wall occlusion, one-pixel wall sweep, door closure during windup, a late real jump that lets the locked shot pass underneath, stock sword interruption, launched rigid-body crate defeat, in-flight reset/death, death during windup, shooter deletion, whole-room disposal, bounded expiry and ledge-safe retreat. Explicit API lifecycle probes are named in the report. Preserved carrier, player, shield adapter, health, strike health, strike knockback, motor and prop source hashes are verified unchanged during each run.

These are headless functional tests. They do not claim native visual review, full mission balance or navigation across gaps/stairs. The sentry does not jump or pathfind.
