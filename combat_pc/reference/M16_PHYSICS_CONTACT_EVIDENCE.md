# M16: rigid-body impact-noise evidence

Audited 2026-10-05 against the official **Godot `4.6.3-stable` tag**, matching the native validation runtime version. The decisive files were retrieved directly from the Godot repository. This note distinguishes engine behavior from MOKSHA's authored event policy; it does not claim recovered Dead Cells behavior or acoustically calibrated sound energy.

## Proven engine behavior

- **Coordinates and sampled velocity.** The built-in Godot Physics 2D backend records both contact positions in world coordinates and a world-space normal toward the reporting body. It captures both bodies' contact-point velocities together, including angular motion, before applying that contact's warm-start impulse. Earlier contacts may already have applied warm-start impulses, so this is not a guarantee of untouched pre-solver velocity for the whole island. See [contact construction and reporting][pair].
- **Impulse timing.** The contact report receives an accumulator before the current iterative solve updates it. The body stores a value copy, and the public getter returns that stored value. A fresh energetic contact may report zero. Treating this as the current completed collision impulse, or requiring a positive impulse to admit an impact, is unsupported. See [reporting/solver ordering][pair], [copy into body contacts][body-header], and [direct-state getters][getters].
- **Safe polling window.** The main loop increments the physics-frame counter, synchronizes and flushes queries, runs `_physics_process`, then advances the next step. `body_get_direct_state()` permits the synchronized window and rejects a locked space. Polling there reads the last completed step's contacts; current body velocity is a different sample. Deferred callbacks can run both before and after the step, so the frame counter and `is_in_physics_frame()` alone do not identify when an arbitrary reset happened. See [main loop][main] and [server access guard][server].
- **Sleeping and retained contacts.** Normal step processing resets the contact count inside body force integration; that integration is called for active bodies. An inactive body's records can therefore survive sleep. A cached contact must not become a fresh event merely because the observer resumed. See [active-body loop][step] and [contact reset][body].
- **Finite reporting capacity.** When the body contact buffer is full, deeper contacts can replace shallower ones. A missing reported contact is not proof that no collision occurred. See [contact buffer policy][body-header]. The [public API reference][api] describes the getters but does not promise identical solver timing for another physics backend.

## Authored MOKSHA policy

The impact candidate is calculated from a real reported contact:

`closing_speed = max(0, -(local_contact_velocity - collider_contact_velocity).dot(normal))`

This is an authored impact-strength proxy in project distance units per second. The minimum speed, loudness mapping/clamps, quiet threshold, separation/quiet rearm durations, manifold aggregation, and symmetric-pair ownership are gameplay choices. They are not engine constants, measured acoustic energy, or extracted reference-game values.

`physics_contact_noise.gd` observes an existing body without applying motion. It keeps shape-pair contact episodes, selects the strongest admitted contact per opposing body, and captures the struck surface point from `get_contact_collider_position()`. Hysteresis and elapsed simulation time permit later bounces while suppressing repeated resting samples. Deferred delivery uses a captured receipt rather than a later body position. Sleep must preserve episode history: blindly discarding the first wake sample can lose the real collision that woke a stationary prop.

For two participating props sharing a bus, ownership must consider only a live, enabled, eligible peer and must not make two reports of the same encounter. Report-capacity limits still bound what either observer can detect. Floor and wall shapes on one static body require separate episodes even when output is consolidated by opposing body.

## Single-source integration contract

Attach one observer to a plain `RigidBody2D` and bind it explicitly to that body and the intended noise bus with `bind_body(body, event_bus)`. The bus must expose the component's required `emit_noise` method and `noise_emitted` signal. A fixture may use the exported body/bus paths instead. Contact reporting must have sufficient capacity; the observer manages the reporting settings it owns.

For explicit host resets, call `reset_contact_history()` before teleporting or replacing motion. The clearest sampling contract is to perform reset/motion in the host's `_physics_process` before the observer: the following callback then sees a completed post-reset step. Resetting during idle after step F leaves old records visible at callback F+1; that path needs its own stale-sample fence or a reset queued into the next physics callback. Ordinary wake-by-collision is distinct from an explicit reset.

Use one impact-noise producer for each body's contacts. The existing top-level `prop.gd` has a separate legacy impact-noise path; adding this observer alongside that path would duplicate its responsibility. Migrating that host requires choosing the observer as its sole contact-impact producer. Launch/break events are separate event kinds. No NPC behavior is needed to exercise this component.

## Validation and remaining scope

The source audit establishes coordinates, sampling order, and access constraints. Runtime fixtures must separately establish first impact, floor/wall/prop locations, meaningful strength ordering, later bounces, symmetric deduplication, resting silence, reset/pause/sleep behavior, and equivalent policy at 60 and 120 physics ticks per second. Rate equivalence means the same event policy, not identical numerical trajectories or timestamps. Consult the M16 fixture/test results for actual pass/fail claims; this source note is not a test report.

Sustained scraping and rolling noise, other physics backends, and production integration into the legacy prop are outside this component's verified scope. Tangential contact is not silently reclassified as an impact. A backend change needs a fresh source/runtime check.

[pair]: https://github.com/godotengine/godot/blob/4.6.3-stable/modules/godot_physics_2d/godot_body_pair_2d.cpp#L459-L592
[body-header]: https://github.com/godotengine/godot/blob/4.6.3-stable/modules/godot_physics_2d/godot_body_2d.h#L345-L386
[getters]: https://github.com/godotengine/godot/blob/4.6.3-stable/modules/godot_physics_2d/godot_body_direct_state_2d.cpp#L189-L235
[main]: https://github.com/godotengine/godot/blob/4.6.3-stable/main/main.cpp#L4878-L4953
[server]: https://github.com/godotengine/godot/blob/4.6.3-stable/modules/godot_physics_2d/godot_physics_server_2d.cpp#L1005-L1021
[step]: https://github.com/godotengine/godot/blob/4.6.3-stable/modules/godot_physics_2d/godot_step_2d.cpp#L139-L153
[body]: https://github.com/godotengine/godot/blob/4.6.3-stable/modules/godot_physics_2d/godot_body_2d.cpp#L612-L624
[api]: https://docs.godotengine.org/en/4.6/classes/class_physicsdirectbodystate2d.html
