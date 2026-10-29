# Character Footsteps

`character_footsteps.tscn` is one optional child for an upright `CharacterBody2D`. It observes real grounded locomotion and forwards `enemy_step` / `enemy_land` through an explicitly supplied local NoiseBus. It never moves the actor, reads player input, runs an AI, discovers a global bus, plays audio, or changes the existing PC/contact/surface components.

The review fixture inherits `movement/actors/npc.tscn`. Its small `footstep_npc_motor.gd` bridge calls the unchanged `MokshaMovementMotor.step_motor()` once and brackets that call. The inherited intent component is disabled; a host can call the existing `set_intent()` interface. Removing `Footsteps` preserves the same motor and physical motion.

## Minimal host interface

1. Add the child and call `bind_body(character_body, local_noise_bus)`. Both must already share its live World2D. Alternatively set `body_path` and `event_bus_path` explicitly before `_ready`. The bus must provide the existing `emit_noise(origin, kind, loudness, source)` method and `noise_emitted` signal.
2. Immediately before one real `move_and_slide()` operation, call `begin_motion_sample(dt, ordinary_locomotion)` and retain its integer token. Do not begin a sample for an enabled/pause guard that returns without moving.
3. If the motor emits a real landing signal during that operation, pass its captured pre-collision downward speed to `capture_landing(speed)`.
4. Immediately afterward call `finish_motion_sample(token, ordinary_locomotion)`. The booleans describe the motor's before/after permission for ordinary running/braking; dash, stun and external impulse must be false. A dash that starts and ends in this same tick must also be false. These permissions alone never produce a footstep.
5. Call `reset_history()` **before** teleport/reset, external impulse, or changing the mover's physical context. For an actual motion freeze such as hit pause, call `suspend_motion()` before the freeze and on skipped pause ticks. It fences pending tokens and discards partial stride/carry history while retaining the measured airborne episode. Tree pause/resume uses this suspension automatically. The first frozen body position and World2D anchor stay fixed across repeated calls; resumption preserves flight only if the actor stayed there. `unbind()`, `enabled`, `simulation_enabled` and leaving the tree retire the full history. An unannounced skipped frame still starts fresh history. If a signal handler mutates physics during the bracket, the host must reset the observer in that handler before the mutation.

The sample token includes a binding/reset epoch. A reset, mute, detach or rebind during a motor signal prevents that old operation from producing an event. Only one completed sample per physics frame is accepted. The child does not poll `get_position_delta()` later, and has no deferred noise queue.

One observer owns the body's metadata registration. Binding a second observer fails even while the first is muted; unbind the first explicitly to transfer ownership. The bridge's observer child name is `Footsteps`; future hosts can call the generic interface from any child reference.

## Actual travel and contact

Cadence accumulates actual displacement during the bracket minus the platform carry applied by Godot. It projects that relative displacement onto the current floor tangent, so slope distance includes vertical travel. A default step requires 28 pixels of accepted travel, matching the old enemy's spacing as authored tuning. Input/facing changes, idle time, wall pushing, and carry alone cannot accumulate distance. Ordinary braking can count while it is still moving. A stop discards the partial stride; reversal counts the real braking/reversing path without an immediate synthetic strike. At most one step is emitted per completed sample; there is no catch-up burst.

The origin is a **current queried support point**, not the actor center or an animated foot plant. Three short floor rays sample the configured sole footprint. They must agree with the actual `is_on_floor()` / floor normal and, when available, the matching floor slide collider. This also handles floor snap, which can establish a floor without a slide collision. Competing support IDs, missing contact, and non-walkable normals suppress the sample. `sole_offset`, probe width and probe lengths must fit the host's collision shape; the supplied capsule NPC has a bottom-origin sole.

For platform carry, the observer samples the previous verified floor support's **fresh physics direct-state point velocity** before the motor. This includes a static conveyor's virtual velocity. It then runs a read-only `body_test_motion` with the same carry parameters/exclusions as Godot 4.6.3, obtaining the travel actually available when a wall clips carry. Subtracting requested velocity, post-move platform velocity, or an unrelated support transform delta would count some passive platform motion as walking. The read-only query never moves either body.

Supported hosts have world-up, unrotated, unit-scale body transforms. Supports are live `StaticBody2D`, `AnimatableBody2D`, or `RigidBody2D` floors with constant transform basis and translation-only carry, including static conveyors and fixed rotated slopes. Dynamically rotating/scaling/skewing supports, CharacterBody floors, TileMap-owned physics bodies, ambiguous mixed floor/wall ownership, and arbitrary skeletal foot placement are outside this component. A prior wall contact suppresses cadence for that transition even if `platform_wall_layers` is zero: the engine can still have cached that wall as its private platform owner. Cadence resumes after a fresh unambiguous floor-only sample. A basis change against the retained grounded support, or current nonzero physics angular velocity, is rejected. This is not a detector for every transform change during an airborne approach; changing scale/skew and rotation remain outside the verified scope. The physical world must remain unchanged between the carry query and the actual motor operation, except for that actor's own movement. The source does not promise another engine version or physics backend has the same carry semantics.

## Landings

A transition from actual air to a current floor emits `enemy_land` only when it has a captured landing signal, enough airborne time, enough vertical excursion, and enough pre-collision downward speed. Defaults are 0.06 seconds, 6 pixels and 70 pixels/second. A small initial gravity settle is silent; a real initial drop or later jump/fall can land audibly. A landing clears cadence and emits no walking step in the same sample. A real motion pause freezes the airborne evidence without adding paused time, so a qualified flight paused just before touchdown still lands once after resuming. Mute, disable, reset and teleport retire that evidence. A landing is a physical floor event even after a non-walking flight; dash/stun motion never becomes `enemy_step`.

The motor's landing speed is its existing downward gameplay strength proxy, not a computed contact-normal relative impact energy. Loudness clamps that proxy using the profile. All thresholds, spacing and loudness are editable authored policy in `footstep_profile.tres`; the resource contains no runtime history.

## Receipts and inspection

`footstep_emitted(receipt)` fires **after** delivery to the local NoiseBus, provided that the bus callback has not reset, rebound, muted or destroyed the observer. The bus is the authoritative route. The receipt is read-only and contains only copied scalar/vector/string data:

- `kind`, captured `origin`, floor `normal`, `loudness`
- `body_id` / `source_id`, `source_name`, `support_id`, `support_name`, `support_shape`
- `relative_distance`, `relative_speed`, `landing_speed`, captured `support_motion`
- `serial`, `epoch`, `binding`, `physics_frame`, `stride_distance`, `total_ground_distance`, `foot_index`

All state is committed before the bus callback; lifecycle checks fence the optional post-bus signal. `last_event` and `recent_receipts` return defensive copies. History is bounded by `recent_receipt_limit` (default 32, maximum 256). `reset_diagnostics()` clears those records/counts without changing movement/cadence. `debug_snapshot()` also gives `stride_phase`, `last_relative_travel`, `last_support_motion`, `motion_suspended`, current `support_id`, sample/rejection counts and a short `reason`. The phase/distance can drive a passive review gait cue but is not an animation foot-plant claim.

Engine-source rationale is in [M17_FOOTSTEP_EVIDENCE.md](../reference/M17_FOOTSTEP_EVIDENCE.md). Native acceptance results are recorded separately; loading the scene alone is not proof that every listed platform/contact case passed.
