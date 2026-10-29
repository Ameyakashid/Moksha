# Legacy demo enemy composition

Ordinary production sentinels and listeners now use the shared composition
described in `simulation/SENTINEL_CONTRACT.md` and `simulation/LISTENER_CONTRACT.md`.
This legacy scene remains for regression fixtures and as the existing ranged
and Warden inheritance base. The contract below documents that legacy scene.


`demo/components/enemy.tscn` inherits the preserved `combat_pc/fixtures/health_target.tscn`. Its demo-only script extends that fixture, retaining the production MovementMotor, Hurtbox/ContactTarget, StrikeKnockback, StrikeHealth and scalar Health components. No preserved source or project setting is edited by this component.

## Host integration

Instantiate the scene, set `kind` to `sentinel`, `listener`, or `warden` before adding it to the tree, then call `configure(player, event_bus)`. The player is the production `combat_pc/player.tscn`. The event bus uses the existing NoiseBus `emit_noise(origin, kind, loudness, source)` method and `noise_emitted` signal. Passing no bus still exposes the enemy's `noise_requested` signal for a host adapter. Do not forward that signal back to the same bus when a bus is already configured.

- `dead`: bool; `health`: read-only scalar; `ai_state`: readable state name
- `defeated(enemy)` emits once per life; the host decides room completion/rewards
- `attack_resolved(enemy, result)` reports a surviving attack's stock PC result
- `reset()` returns to initial spawn and full health; `reset_at(position)` changes spawn and resets
- `set_room_bounds(left, right, floor_y = 0)` or exported `room_left`/`room_right` constrain walking; floor_y is accepted for host convenience, but actual ray-tested terrain owns support
- `set_blind_mode(bool)` optionally hides the authored drawing except briefly after its own sound. Host SonarView blackout can be used instead, and needs no call here
- `hear_noise(origin, kind, loudness, source)` can be called directly if another bus adapts the existing signature
- `ai_enabled` stops decisions without disabling movement/health reception
- Exports `patrol_radius`, `detection_range`, `hearing_range`, `max_health`, `movement_speed`, `windup_override`, and `attack_damage_override` tune encounters; zero override means archetype default

### Collision contract

The movement body is layer **32**, mask **9** (terrain1 plus props8). The player-contact Hurtbox remains layer **4**. The stock PC ContactAdapter targets mask12, so only that Hurtbox can accept a sword hit, avoiding duplicate body + hurtbox damage. Set demo prop `collision_mask = 33` (terrain1 plus enemy body32). Player terrain mask1 ignores enemy bodies.

The enemy joins `enemies` and `actors`. Its authored wireframe uses no external art. SonarView can discover its actual body shape and enemy group. Defeat disables both shape anchors and their collision layers; it cannot leave a live sonar threat or a hittable corpse. Reset restores shapes and collision masks.

## Encounter behavior

| Kind | Health | Walk/chase speed | Windup | Damage | Reach |
| --- | ---: | ---: | ---: | ---: | ---: |
| sentinel | 3 | 82 px/s | 0.56 s | 1 | 43 px |
| listener | 2 | 112 px/s | 0.46 s | 1 | 43 px |
| warden | 8 | 70 px/s | 0.86 s | 2 | 57 px |

All patrol at 43% speed, brake before real platform edges, chase through clear horizontal sight, show a circular telegraph and warning sound, lock facing at commitment, sweep one active physical rectangle, then recover. Warden has a longer readable delay, reach and recovery rather than unsupported boss systems. Listener directly detects nearby movement only, and otherwise pursues the actual last heard player/prop noise for 3.2 seconds. Configured hearing-peer groups preserve the old same-script equivalence: ordinary
melee/listener, ranged and Warden are separate peer sets. This is AI policy.

## Combat authority and lifecycle

Outgoing melee is admitted only by a `PhysicsShapeQueryParameters2D` overlap with the actual player body's layer2 shape, plus an obstruction ray. It calls the existing PC `receive_attack()` with a unique, monotonic attack ID, finite real origin/contact/velocity and `blockable`, `parryable`, `counterable`, and `rollable` flags. The PC owns damage/guard absorption/parry timing/roll invulnerability. Each enemy swing is spent before the call; no active-frame repeat is possible. Face is latched during telegraph, so dodging behind the enemy works.

Player melee arrives through the unchanged ContactAdapter and Hurtbox `struck` signal. StrikeKnockback applies motor impulses; the enemy's override cancels any windup/active swing synchronously. StrikeHealth owns normal strike receipt validation and sends it to the preserved scalar Health store. Depletion cancels attack identity, stops decisions and motion, disables receivers, emits physical defeat noise, then emits `defeated`.

Shield counters go through the stock ShieldContactAdapter's actual hurtbox ray. `receive_shield_counter()` verifies the current defender effect scope, target and unique attack key before applying stagger and publishing a generation-stamped receipt through the same scalar health provider. A counter can kill synchronously without resurrecting an outgoing hit.

`take_hit(amount, direction, from_prop = false)` is a compatibility boundary for legacy `prop.gd`, which has already admitted the actual rigid-body collision and deduplicated its launch. It routes a generation-stamped receipt into the same health store and motor stagger. It is not a second PC melee receiver because the body is outside the PC's target mask. The supplied prop's splash, if enabled, remains its existing policy.

Reset fences the health/knockback adapters before motor reset, restores health and colliders, clears attack state, and retains monotonic outgoing identity so an old attack cannot match a new life.

## Tests

Run from the project root:

```
XDG_DATA_HOME=/tmp/moksha_enemy_data XDG_CONFIG_HOME=/tmp/moksha_enemy_config XDG_CACHE_HOME=/tmp/moksha_enemy_cache /usr/local/bin/godot --headless --path . --script res://demo/tests/enemy_regression.gd -- --hz=120
```

Repeat with `--hz=60`. JSON results are written under `demo/tests/enemy_results_*hz.json`. Actual Godot physics callbacks drive the unchanged PC and the enemy's motor, plus real ContactAdapter queries, real shield counters and a launched RigidBody crate. Scenarios cover one-hit swing ownership, guard, parry/counter, lethal parry, escaped target, wall occlusion, incoming melee health and knockback, interrupted telegraph, reset/death boundaries, listener pursuit/edge safety and prop damage. The explicit direct-depletion test is labeled as an API boundary probe. The suite hashes preserved player/motor/health/prop source files before and after execution.

Limits: this is flat/stepped room combat, not navigation/pathfinding. Enemies do not jump gaps or climb to a target. Headless functional validation does not replace native presentation/playability review.
