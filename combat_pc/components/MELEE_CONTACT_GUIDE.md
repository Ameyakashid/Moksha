# Reusing chained melee contacts

The PC owns input, phase timing, facing, strike identity and which targets have
already been hit. `contact_adapter.gd` owns the Godot volume/visibility queries
and calls the appropriate receiver. The original wireframe only presents those
decisions. None of these components requires the inspection lab.

Assign `resources/light_chain.tres` to the actor's optional `melee_chain` property
for the three-step example. Leave it null for the existing single-swing profile.
Step resources control timing, permitted interruptions, movement, contact size,
damage and impulse independently. The actor snapshots an episode; editing a
shared resource does not rewrite an attack already in flight. The complete
input/retention/cancellation contract is in `../MOTOR_CONTRACT.md`.

The contact adapter attaches under the actor and binds `strike_sample`. Its actor
must implement `confirm_strike(serial, target_id, contact_position)` and
`is_strike_current(serial)`. The latter is essential: it distinguishes a current
sample, including two targets contacted in one admitted hitpause sample, from a
retired attack or a later paused callback.

Each step gets a new serial and a new swept volume. A target is accepted only
inside the actual forward strike intersection with a clear terrain ray from the
strike origin. A different step may hit the same target again. A wall, a stale
serial, a canceled phase or an already visited target cannot create another hit.

The outgoing payload includes the frozen contact geometry, damage, impulse,
facing, serial, chain serial, step index/label, pose identifier and consumed input
identity. The existing receiver forms remain:

- `receive_strike(payload)` for explicit fixture or host receivers
- `launch(direction, prop_launch_scale)` for living physics props
- The preserved game's enemy hit interface for later integration

New combat receivers should use `receive_strike(payload)` to consume fractional
damage and the full impulse. The preserved enemy compatibility call accepts only
integer damage and a direction, so it does not represent all per-step data. No
NPC health or response was added to this PC-only pass.

Confirmation can invoke user callbacks. The adapter rechecks actor ownership and
target lifetime before applying a captured payload. If a receiver applies its
effect and then resets/replaces the actor, that physical application remains
counted, while stale follow-up feedback and the remainder of the old sweep stop.
`reset_actor` is the supported teleport API. A position change observed during a
live sample keeps that already-resolved contact but seeds the following sweep
from the new position; it does not draw a damaging line across the skipped gap.

`fixtures/chain_target.tscn` is an independent passive instrument with a foot
pivot. It records every delivered strike, including its serial, step, contact,
impulse and damage value. It deliberately does not hide duplicate deliveries by
deduplicating them again. It has no AI, health system or hit-producing timer.
Its history is bounded and resets with the inspection start. In the lab, **T**
selects this target; three fresh **J** presses request the example chain. Holding
J produces one swing because this example has no held-repeat or charge branch.

All numerical values and phase permissions are original MOKSHA tuning. The
source confidence and missing Dead Cells consumers are documented in
`../reference/MELEE_COMBO_CHARGE_EVIDENCE.md`. The profile is not an extracted
Dead Cells weapon or an exact timing claim.
