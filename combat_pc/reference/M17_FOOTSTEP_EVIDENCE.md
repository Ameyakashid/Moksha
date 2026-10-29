# M17: character footstep-source evidence

Audited 2026-10-05 against Godot **4.6.3-stable** and the existing reusable NPC. This is a source audit and proposed integration contract, not a runtime pass report or a claim about recovered reference-game behavior.

## Existing host boundary

`movement/actors/npc.tscn` already composes `MokshaMovementMotor`, `npc_intent.gd`, and a static wireframe. The motor alone changes velocity and calls `move_and_slide()`. Its disabled and hit-pause branches return without moving. Its `landed(speed)` signal captures downward velocity before the move, only on a new floor transition above its existing 50 px/s threshold. The wireframe has no animated foot-plant track. Legacy `enemy.gd` has its own X-distance/global-bus step producer; adding a second producer there would duplicate responsibility.

Keep those files, the PC, M15 surfaces, and M16 impacts unchanged. An inherited NPC motor bridge can bracket `super.step_motor(dt)` and feed a detachable source; it must not copy or replace the movement algorithm.

## Engine facts

- [Public CharacterBody2D contracts][character-api] describe the last move's floor state, motion, collisions, and real velocity. Real velocity follows slope travel; requested `velocity` is different. `get_last_motion()` is only the final submotion. Moving-platform collisions precede the character's own slide collisions.
- [Engine ordering][character-source]: the move snapshots position, refreshes the previous platform's velocity through direct state at the character origin, clears collision records, applies carry, then performs character motion. Real velocity includes both. Later floor/wall collisions replace platform data; post-move platform velocity is not necessarily the carry used. Leaving can add platform velocity to requested velocity afterward.
- [Getter implementation][character-getters]: `get_position_delta()` subtracts the saved position from the *current* transform, so a later teleport changes it. [Floor snap][character-snap] can set floor/platform data without appending a slide collision. Skipping the move leaves the preceding move's floor/collision fields available.
- [Kinematic collision positions][collision-api] are world-space collision points. A floor-classified normal and current floor state must qualify the point; the last collision can instead be a wall.
- [Direct-state point velocity][point-api] includes translation and rotation. [Static-body velocity][static-api] can act as a conveyor without changing the support transform. [Animatable bodies][animatable-api] estimate velocity when moved and support physics synchronization.

## Recommended sample and carry contract

Each accepted sample should identify its binding/reset epoch and unique sequence, elapsed physics time, whether the motor actually ran, before/after positions and floor state, ordinary-locomotion eligibility, verified support point/normal/RID, captured carry displacement, and any landing signal received during that move. Finish immediately after the motor. Never manufacture a new sample by polling retained fields in a later child callback. Capture the motor's enabled/pause guard **before** calling it, because the final pause tick can decrement its timer to zero without moving.

For the verified previous floor support, sample direct state immediately before movement, honoring platform layers. Match the engine's point argument: `actor.global_position - support_state.transform.origin`. Do not use a support transform delta from a different interval, or blindly subtract pre/post `get_platform_velocity()`.

For unobstructed translation, carry is current support-point velocity times physics delta. For clipped carry, a read-only `PhysicsServer2D.body_test_motion()` can predict its applied travel using the actor's current transform, carry vector, safe margin, `recovery_as_collision = true`, and exclusions for that support RID/object. [PhysicsBody2D's implementation][body-source] uses this result directly for platform carry because sliding cancellation is disabled. [Motion parameters][motion-api] expose those settings. Skip the query when the engine would skip zero carry. This equivalence requires the same support and unchanged physics world before the actual move; it needs runtime verification.

Accumulate the floor-tangent component of captured actor displacement minus carry only for admitted grounded locomotion. Actual braking travel may count; input, facing, or elapsed time alone must not generate steps. Require fresh contact/support evidence and suppress idle, airborne, dash/stun, discontinuous, duplicate, and invalid samples according to the component's declared policy. Reset cadence on bind/reset/teleport and establish a fresh baseline on resume. A floor probe can supply a current support point when snap omitted a collision, but identify it as a queried support point, not a recovered collision or animated foot plant.

Capture landing separately, emit at the captured support point, and reset cadence to prevent a simultaneous walking step. The motor's scalar landing speed is a gameplay strength proxy, not contact-normal relative impact energy; changing that meaning would need a richer host signal and separate validation.

## Limits and verification

The engine's prior platform RID is private. A floor probe cannot guarantee reconstruction when several supports or floor/wall contacts compete. Fail closed for ambiguous support, missing direct state, stale contact, or unsupported transformations. Do not claim arbitrary rotating/scaling supports, every physics backend, or skeletal foot-plant synchronization. Cadence, spacing, loudness, reversal/reset rules, and thresholds are authored policy.

Required fixtures: flat/slope travel in both directions, start/brake/stop/reverse, stationary and airborne silence, distinct landings, blocked movement, hit-pause/resume, disable/rebind/reset/teleport, static conveyor carry, translating-support carry and speed reversal, own walking on those supports, and 60/120 Hz behavior. The runtime report must state which cases actually passed.

[character-api]: https://docs.godotengine.org/en/4.6/classes/class_characterbody2d.html
[character-source]: https://github.com/godotengine/godot/blob/4.6.3-stable/scene/2d/physics/character_body_2d.cpp#L38-L115
[character-getters]: https://github.com/godotengine/godot/blob/4.6.3-stable/scene/2d/physics/character_body_2d.cpp#L419-L489
[character-snap]: https://github.com/godotengine/godot/blob/4.6.3-stable/scene/2d/physics/character_body_2d.cpp#L315-L353
[collision-api]: https://docs.godotengine.org/en/4.6/classes/class_kinematiccollision2d.html#class-kinematiccollision2d-method-get-position
[point-api]: https://docs.godotengine.org/en/4.6/classes/class_physicsdirectbodystate2d.html#class-physicsdirectbodystate2d-method-get-velocity-at-local-position
[static-api]: https://docs.godotengine.org/en/4.6/classes/class_staticbody2d.html#class-staticbody2d-property-constant-linear-velocity
[animatable-api]: https://docs.godotengine.org/en/4.6/classes/class_animatablebody2d.html
[body-source]: https://github.com/godotengine/godot/blob/4.6.3-stable/scene/2d/physics/physics_body_2d.cpp#L62-L108
[motion-api]: https://docs.godotengine.org/en/4.6/classes/class_physicstestmotionparameters2d.html
