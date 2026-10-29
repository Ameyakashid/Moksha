# M8 shield contacts and passive fixtures

These are original MOKSHA components, informed by the bounded source audit in `../reference/SHIELD_PARRY_EVIDENCE.md`. They do not reproduce recovered Dead Cells implementation or exact v35 geometry/timing. All dimensions, timing, speed, damage, collision-layer choices and scheduling below are authored MOKSHA tuning.

## Scene integration

Attach `shield_contact_adapter.gd` to a `Node2D` beneath the combat PC, with `actor_path=".."`. Its `_ready()` connects to `shield_effect_requested(actor, request)`; `bind_actor(actor)` can rebind. The adapter does not originate defense outcomes, noise, input windows, hitpause or damage suppression.

Three stationary instruments are available:

- `res://combat_pc/fixtures/guard_melee_fixture.tscn`
- `res://combat_pc/fixtures/guard_projectile_fixture.tscn`
- `res://combat_pc/fixtures/guard_prop_fixture.tscn`

All three scenes serialize their receiver shapes and provide safe `@tool` wire previews. Physics updates and attack/spawn entry points return immediately in the editor.

Their root position is a foot pivot. `direction=-1` fires left and `direction=1` fires right. The root receiver shape is 12×30 pixels above the foot pivot, on layer 4. The player's terrain mask remains layer 1; these instruments therefore do not block ordinary player movement. They are stationary test sources/receivers, with no AI, NPC controller or enemy progression.

All instruments expose:

- `request_attack() -> bool`: admit a fresh telegraphed attack; false if paused, disabled, already winding up, or at the carrier cap. Melee also retains `trigger_attack()` as an alias.
- `auto_attack`: false by default. If enabled, repeated attacks still have fresh positive identities and bounded carriers/lifetimes.
- `set_fixture_paused(paused: bool)`: freeze phase time and existing physical motion while retaining the pending telegraph and prior enabled state. Repeated calls are idempotent.
- `set_simulation_enabled(enabled: bool)`: host enable/disable. Disable retires an outstanding telegraph; resume requires a fresh request. Existing carriers freeze, including real rigid bodies.
- `reset_fixture()`: retire transient carriers, clear pending attack/visible counters, retain monotonic melee/emitter identity counters. It does not implicitly change host enable or pause state.
- `attack_resolved(result: Dictionary)`: an observed incoming result (and, for projectile receivers, an outgoing accepted/rejected return result).

The bullet emitter additionally exposes `fire_projectile() -> CharacterBody2D` and the prop emitter `throw_prop() -> RigidBody2D`. These instantiate real carriers immediately; they are useful to controlled harnesses, whereas the lab uses the telegraphed `request_attack()` path.

## Authored geometry and tuning

| Instrument | Telegraph | Physical contact path | Other defaults |
|---|---:|---|---|
| Melee | 0.65 s | Horizontal tip ray, 8→58 px from source at y=-17, continuously swept over 0.14 s | 1.4 s auto cooldown; damage 10; impulse (direction×155,-105) |
| Bullet | 0.5 s | Circle radius 3, `move_and_collide` over actual velocity×dt; starts 13 px forward at y=-17 | Speed 230; life 3.5 s; max 4; 1.65 s auto interval; damage 10 |
| Rigid prop | 0.65 s | Original 28×28 crate, shape CCD and Godot solver contact manifold; starts 23 px forward at y=-18 | Original impulse launch API, requested speed 230/lift -35, gravity scale 0.4; initial launch spin 0; life 5 s; max 2; 2.8 s interval |

A root-to-player distance around 40 px suits the melee source. A bullet emitter around 48 px away and a prop fixture around 67 px away give useful short practice approaches. Their exact arrival depends on physics rate, actual geometry and physical integration. These positions are demonstration tuning, not a claim that every arbitrary launch hits the same sampled shield phase at 60 and 120 Hz.

The original crate tuning is duplicated per spawned instance. The old crate scene, `prop.gd`, global resources, launch API, launch/impact/break noise and old game remain unchanged. The original sprite is hidden on the instance; the new bridge draws only an original wire box. Original impulses, mass, gravity, damping, bounce and solver contacts remain real. `launch(direction, force)` still works through the existing melee prop adapter. Prop return damage is an explicit receiver record; it does not imply an NPC health implementation.

## Incoming descriptor and identity

Production fixtures call the actor's `receive_attack(payload)`, carrying:

- positive integer `attack_id`; `kind` of `melee` or `projectile`
- `source` as a live node or null remote owner; `carrier` for projectiles
- finite world-space `origin`, `contact_position` and `incoming_velocity`
- independent `blockable`, `parryable`, `reflectable`, `counterable`, `rollable`
- `amount`, `impulse`, and the legacy `source_position` compatibility alias

Melee identity belongs to its source. Bullet identity belongs to the actual carrier. The rigid carrier identity belongs to `GuardPropAdapter`, which controls the parent rigid body. Remote source ownership is a weak reference; removing a remote source does not turn a still-live carrier into an invalid attack. Destruction of an entire fixture does naturally remove its descendants.

The melee tip uses the first hit of a terrain-or-player ray. A terrain hit retires that tip before any actor descriptor is emitted. Bullets use one continuous sphere motion against terrain, player and return receivers. A wall collision retires the bullet. Rigid props use shape CCD and actual solver contact records, with a minimum incoming speed 45 and a closing normal-speed check. The contact position is `get_contact_collider_position()`, on the struck collider, not the possibly penetrating prop face. No timer alone produces a hit. The actor independently validates body contact, occlusion, facing, eligibility and identity/deduplication.

## Synchronous outgoing shield effects

The actor issues `shield_effect_requested(actor, request)` only after a successful incoming parry. Requests use the motor's schema: `shield_serial`, String `attack_key`, `effect` (`counter`/`reflect`), `source/source_id`, `carrier/carrier_id`, `target_id`, frozen `defender_origin` (`origin` compatibility alias), `incoming_origin`, `contact_position`, `facing`, `normal`, `damage`, `impulse`, `reflect_direction`, `reflect_speed`, `max_range`.

Before applying an effect, the adapter checks `actor.shield_effect_is_current(serial, key, effect)`. It then requires an explicit receiver result and synchronously invokes `actor.confirm_shield_effect(serial, key, effect, target_id, accepted, details)`. Deferred or stale/reset/canceled scopes cannot confirm. A receiver returning void or an object other than a Dictionary with a Boolean `accepted` does not confirm an effect.

Counter receiver interface:

- `get_shield_counter_hurtbox() -> CollisionObject2D` is optional; without it, the receiver itself must be the collider.
- `receive_shield_counter(payload: Dictionary) -> Dictionary` must explicitly report `{accepted: bool, ...}` after applying its intended result.
- The payload extends the frozen request with `defender`, `defender_id`, and actual `counter_contact_position`.

Counter reach is conservative and geometric: the adapter examines at most 16 enabled hurtbox shapes, aims rays at their transformed centers, and accepts only an actual first hit on that hurtbox, in front of the frozen origin and within the request range. Terrain participates in the same ray. Shape centers only choose query directions; actual intersections determine distance. This is not a general radial explosion/area-damage solver. An explicit `counterable` melee source without a reachable accepting receiver keeps its incoming parry but has no confirmed counter damage.

Carrier interface:

- `reflect_from_shield(payload: Dictionary) -> Dictionary` must explicitly report acceptance after changing real velocity and intended owner.
- `set_fixture_paused(paused)` and `set_simulation_enabled(enabled)` control simulation without inventing new contacts.
- The ordinary bullet and rigid bridge permit one redirect per launch. They transfer weak ownership to the defender, exempt that defender from the outgoing body collision, remove their old physical-owner exemption, and increment the outgoing attack identity. Reflection changes actual `velocity` or `RigidBody2D.linear_velocity`; it never teleports the carrier.
- Return receivers implement `receive_guard_projectile(payload) -> Dictionary`. Payload includes the live carrier, owner, attack identity, damage, real contact, incoming velocity and `reflected=true`.

The adapter rechecks owner/target lifetime around callbacks. If a receiver physically applies an effect and then invalidates the actor scope, its report distinguishes `applied=true` from `confirmed=false`. This is not represented as a rollback. Incoming defense, outgoing application and confirmed outgoing success remain separate.

## Scheduling, actual physics, pause and cleanup

Normal actor priority is 0; fixture roots run at physics priority 100; bullet and prop-contact bridges at 110. A controlled actor driver at priority 20 therefore also precedes incoming contacts. Melee/bullet queries use the actual current callback. The rigid bridge observes the latest completed Godot solver contact state after the actor's current update. It does not backdate shield time to force a parry or promise engine-rate-identical contact arrival. Independently generated exact shield-window tests should use actual carrier geometry on their selected tick.

A rigid body's node transform may lag its already-committed PhysicsServer transform by one finished step when global pause is requested. Before freezing, the bridge synchronizes the node to that committed transform, then stores linear/angular velocity, prior freeze, processing and original prop simulation-enabled state. Resume restores them once. This is a synchronization to completed physical movement, not additional pause-time movement or a widened motion tolerance. While paused, physical travel is zero in the focused checks; merely turning off a script would not have frozen the body.

Transient bullets/props are children of `Carriers`/`Props` beneath the fixture. Lifetimes and caps bound work. Reset disables collision and simulation before queued deletion. Paused rigid bodies really freeze. Original prop impact callbacks retain the original `simulation_enabled` guard and world-space noise origins. Defense noise remains actor-owned, so this adapter does not duplicate guard/parry noise.

## Deliberate extension boundary

This pass supports ordinary non-piercing bullets and real thrown crates. It does not implement grenades, fuse ownership, in-range grenade-area reflection, first-enemy piercing, original wall-passing projectiles or special shield variants. Those require separate carrier/area adapters and explicit tests; ordinary reflection does not imply them. Additional categories should extend the descriptor/receiver interfaces while retaining actor eligibility and synchronous accepted-result confirmation.

## Focused verification

`components/tests/guard_component_smoke.gd` runs actual Godot physics with production scripts. Its 25 checks pass at 120 and 60 Hz: real swept defense and accepted return receivers; mirrored melee/bullet/prop routes; counter rejection; live carrier after remote-owner deletion; 4000 px/s bullet and rigid prop versus 2 px terrain; original prop launch-noise origin; pending telegraph cancellation on disable and preservation on global pause; idempotent rigid freeze/resume; transient cleanup.

Results and logs are `guard_component_smoke_results_120hz.json`, `guard_component_smoke_results_60hz.json`, and matching `guard_component_smoke_120hz.log`/`60hz.log` in `components/tests/`. Before-fix evidence retains the rigid pause synchronization failure and the penetrating-own-face contact observation. Those observations are not discarded or presented as passed results. The broader independent M8 acceptance suite owns full motor boundary/regression coverage.

Reproduce from the project root:

```sh
XDG_DATA_HOME=/tmp/moksha-m8-components-data XDG_CONFIG_HOME=/tmp/moksha-m8-components-config XDG_CACHE_HOME=/tmp/moksha-m8-components-cache /usr/local/bin/godot --headless --path . --script res://combat_pc/components/tests/guard_component_smoke.gd -- --rate=120
```

Use distinct writable XDG paths and `--rate=60` for the second rate. A clean Godot 4.6.3 engine log is required alongside the assertions.
