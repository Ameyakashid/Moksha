# Optional rigid-body contact noise

Instance `physics_contact_noise.tscn` beneath a `RigidBody2D`. Set its explicit
`event_bus_path` to the local instance of the existing `scripts/sensory/noise_bus.gd`.
The default `body_path` is `..`. Alternatively, add the component to the tree and
call `bind_body(body, bus)`; its Boolean result reports whether binding succeeded.
Only one component may bind a body. Bodies and the bus must share the component's
SceneTree and World2D. An empty bus path does not discover a global bus.

This component observes physical impacts. It does not move bodies, launch props,
play audio, generate scrape/rolling events, or implement NPC hearing. Use it on
plain rigid bodies or hosts that do not already publish the same impact. The
historical `prop.gd` has its own impact emitter and remains unchanged.

## Contact policy

The child reads its body's `PhysicsDirectBodyState2D` once per eligible physics
callback. It uses the strongest approaching manifold contact for each shape pair,
with speed `max(0, -(local_velocity - collider_velocity).dot(normal))`.
Godot 4.6's reported contact positions and normal are already world-space; both
contact-point velocities include angular motion. `origin` is the actual collider
surface point, not either body's center. A fresh impact can report zero cached
impulse, so impulse is deliberately not an admission requirement.

`contact_noise_profile.tres` exposes the authored policy: minimum closing speed
85 px/s; loudness `clamp(speed / 240, 0.45, 1.9)`; quiet rearm at at most 20 px/s
for 0.05 seconds; separation rearm after 0.025 seconds. These are MOKSHA choices,
not recovered source-game constants. Timing uses physics delta seconds at either
60 or 120 Hz. A quiet or separated episode only rearms; a real new above-threshold
contact must still occur before noise is published.

Episode identity includes collider object ID and both shape indices. Separate
floor and wall shapes on the same static body trigger independent impacts, even
simultaneously. Multiple manifold points within each shape pair produce only
its strongest newly eligible impact that step. One concave shape containing both
floor and wall shares an episode; a rapid change between its faces without quiet
or separation can be suppressed. Author separate shapes if those faces need
independent impact episodes.

For two instrumented dynamic bodies on the same bus, same-step reciprocal
candidates with reversed shape indices share a claim. The lower body ID owns delivery while eligible; a
sleeping, frozen, disabled, removed, or nonprocessing peer cannot own it. Both
episodes disarm. The claim is committed before bus callbacks and survives peer
removal during those callbacks. An instrumented body still reports impacts
against uninstrumented bodies, or when its peer's contact capacity omitted that
pair. Different buses receive their own events.

Contact reporting is bounded by Godot's body capacity, set to at least the
profile's `max_contacts_reported` when bound. Contacts discarded by the engine
cannot be reconstructed. `capacity_reached_count` identifies samples at capacity;
it is a warning that records may be omitted, not proof of loss. Increase body or
profile capacity for complex piles. No world scan repairs omitted contacts.

## Lifetime and host controls

- `enabled` and `simulation_enabled` gate observation only; they do not freeze or
  alter the rigid body. Pending receipts are invalidated when either changes
- Call `reset_contact_history()` **before** teleporting or resetting the body.
  This fences queued old receipts and clears contact episodes
- For first-step correctness, perform host spawn/reset/teleport/launch commands
  in the host's `_physics_process`, with priority less than the observer's 120.
  Call `reset_contact_history(true)` before the motion change, or pass `true` as
  the optional third argument of `bind_body(body, bus, true)`. This explicit
  pre-step contract rejects current-frame old contacts and accepts the next
  completed solver step. Newly instanced children can first auto-bind normally,
  then receive `reset_contact_history(true)` from that host callback
- Ordinary bind/reset and local enable/resume calls conservatively reject
  through the next physics frame. The following callback reads the first known
  completed post-change solver step. This can drop one boundary contact if an
  arbitrary idle/deferred caller changes an existing body's reporting; use the
  explicit host physics-boundary contract when that first step must be heard
- `Engine.is_in_physics_frame()` alone cannot identify that boundary: Godot
  flushes deferred callbacks both before and after the solver step while it is
  true. Pass `true` only from the documented host `_physics_process` location
- Passive sleep preserves disarmed episodes and cancels pending deliveries,
  without dropping the first waking contact: an actual impact may wake the
  body. Quiet retained contacts and already-disarmed impacts do not replay.
  Sleep admission uses the authoritative server state; the scene property's
  one-tick lag during a real impact wake cannot suppress that collision.
  Freeze/disable and scene pause/resume retain episode history and apply the
  conservative sample fence
- `unbind()` and component removal invalidate queued work, unregister the
  observer, and restore only contact-monitor/capacity settings that the component
  changed and whose values still match its assigned values. No physical motion,
  gravity, damping, collision mask, material, or body processing is changed
- Moving the component or source into a different World2D rejects observation
  and delivery until explicitly rebound in a valid shared world

## Receipts and diagnostics

The unchanged bus receives `emit_noise(origin, kind, loudness, owning_body)`.
Delivery is deferred outside locked physics. Immutable captured receipts retain
their sampled origin, velocities, and strength even if another callback changes
a transform. `impact_emitted(receipt)` runs after bus delivery only if component,
body, bus, binding, and reset epoch still qualify after bus callbacks.

Receipt fields: `serial`, `epoch`, `binding`, `physics_frame`, `source_id`,
`body_id`, `source_name`, `collider_id`, `collider_name`, `local_shape`,
`collider_shape`, `origin`, `local_position`, `normal`, `local_velocity`,
`collider_velocity`, `relative_velocity`, `closing_speed`, `kind`, `loudness`,
and `contact_count`. Despite its engine name, `local_position` is world-space.
`contact_count` counts manifold points for the selected shape pair.

`emitted_count`, `last_event`, `recent_receipts`, and `debug_snapshot()` expose
accepted deliveries and bounded recent history. Snapshot counters distinguish
samples, queued candidates, rejected candidates, and symmetric suppression.
`reset_diagnostics()` clears counters/history without rearming physical episodes
and fences any post-callback diagnostic signal. Serial values remain monotonic;
there is no highest-serial deduplication that could lose reentrant receipts.

Engine timing and coordinate references: Godot 4.6.3
[paired contact reporting](https://github.com/godotengine/godot/blob/4.6.3-stable/modules/godot_physics_2d/godot_body_pair_2d.cpp#L459-L488),
[main-loop synchronization and stepping](https://github.com/godotengine/godot/blob/4.6.3-stable/main/main.cpp#L4878-L4953),
and [active-body integration](https://github.com/godotengine/godot/blob/4.6.3-stable/modules/godot_physics_2d/godot_step_2d.cpp#L139-L150).
