# Reusing struck-target physical knockback

`strike_knockback.tscn` is one optional receiver component. It connects an existing
confirmed melee receiver to the existing `MokshaMovementMotor`. The body actually
moves through the motor's `move_and_slide`; the contact target's inherited flash
and three-pixel drawing recoil remain presentation only.

The PC still owns attack admission, identity, facing, phases and source hitpause.
`contact_adapter.gd` still owns physical contact and occlusion. The motor still
owns velocity, stun, gravity, terrain collision and local pause. This component
does not produce hits, change damage, create health/death/AI, or add audiovisual
feedback. Removing it leaves the contact instrument usable on its own.

## Composition and Inspector setup

1. Use a `MokshaMovementMotor` body with its ordinary collision shape. A passive
   target stays **enabled**, has neutral intent, and has no input/AI provider.
   Set the body to collide with terrain without blocking the PC.
2. Instance the existing `fixtures/chain_target.tscn` as a child named `Hurtbox`.
   Its Area2D is the only melee receiver, on existing target layer 4. Keep its
   contact shape attached to the motor; no target script changes are needed.
3. Instance `components/strike_knockback.tscn` beside `Hurtbox`, under the motor.
   Set `receiver_path` to `../Hurtbox`, `motor_path` to `..`, and leave
   `receiver_signal` at `struck`. Its default paths both point to its parent,
   which also supports a motor that directly implements the receiver signal.
4. Leave `profile` on `resources/knockback_profile.tres`, or assign a separate
   resource for a different response. Duplicate a shared resource before tuning
   only one target. The component never edits a shared resource during a hit.

For explicit setup, add the nodes to one SceneTree/world and call
`bind_receiver(receiver: Node2D, motor: MokshaMovementMotor) -> bool`. The receiver
must be the motor or one of its descendants. A second component cannot bind the
same receiver even when the first is disabled. A failed new binding preserves an
existing valid binding. Changing exported paths or the signal name at runtime
does not silently rebind; call `bind_receiver` again.

The receiver signal has one `Dictionary` argument and is delivered synchronously.
The existing `struck(payload)` already has this shape. A different host can set
`receiver_signal` to its equivalent signal. Never use a deferred connection for
confirmed PC strike delivery. Calling `consume_strike(payload) -> bool` directly
is an integration/testing seam, not an alternate authority to invent hits.

## Signed impulse and authored response

The payload's impulse is already signed in world space. The component multiplies
it component-wise by `velocity_scale` and caps the total vector length. It never
multiplies by facing a second time. The resulting velocity **replaces** motor
velocity through `apply_impulse`; it is not an additive force or mass simulation.

| Profile field | Default | Meaning / accepted range |
| --- | --- | --- |
| `velocity_scale` | `(0.55, 1.0)` | Nonnegative scale per axis, each at most 4 |
| `stun_seconds` | `0.18` | Existing motor stun, greater than zero and at most 2 s |
| `maximum_speed` | `420` | Total initial speed cap, 1–2000 px/s |
| `copy_source_pause` | `true` | Reuse the source's current remaining confirmed pause |
| `maximum_pause_seconds` | `0.12` | Copied-pause cap, 0–0.25 s |

All values are original MOKSHA tuning. For example, the existing first-chain
impulse `(240, -70)` becomes `(132, -70)` before the cap. The mirrored hit becomes
`(-132, -70)`. Existing motor gravity, braking and collisions determine the actual
travel distance; the component promises no fixed displacement. Its speed cap only
limits the assigned initial velocity, not later gravity or unrelated motor input.

The current motor's impulse operation cancels dash/flight assistance and sets
stun. It does not clear input buffers. Hosts with movement intent need to choose
their own input interruption policy; this component does not silently take it.

The [M21 source audit](../reference/M21_KNOCKBACK_EVIDENCE.md) explains the recovered
source limits. No Dead Cells knockback, stun, resistance or target-freeze constants
were recovered or asserted, and no external game code was copied here.

## Contact and pause ordering

The unchanged flow is PC strike sample, ContactAdapter physics acceptance, PC
confirmation, source hitpause, target `receive_strike`, target `struck`, immediate
motor impulse/pause, then the component's `knockback_applied` receipt. The original
adapter continues with its own post-contact feedback and lifetime checks.

Use the original packet's `eligible == true` and `phase == active`, then the live
source's `is_strike_current(serial)`. Confirmation can already have started source
hitpause. The source deliberately remains current inside that admitted synchronous
sample, even though a **new** `strike_snapshot().eligible` would be false. A delayed
call during source pause is correctly rejected outside the admitted scope.

The component reads the source's `hitpause_remaining` once, bounds it by the
profile, and invokes the existing motor's `apply_pause`. It never pauses the
source. A later first contact in the same strike can have zero remaining pause,
because the PC pauses only once per strike. A source without that optional
property contributes zero pause. Negative/nonfinite/nonnumeric values reject.
The motor keeps a longer pre-existing pause through its own `max` behavior; the
receipt reports the newly requested pause, not a replacement for a longer one.

For matched default pause timing, schedule the passive motor before the PC. The
review host sets `process_physics_priority = -10` **after** `super._ready()`;
the existing motor otherwise sets 10, while the PC runs at 0. With this ordering,
neither decrements the newly committed pause until the following physics tick.
Using the stock later priority consumes one recipient pause tick on the contact
frame and can resume it one tick early. The component does not change scheduling
or add a second pause clock. A deliberately lower pause cap or independently
longer motor pause also prevents exact source/target duration matching.

During local pause the existing motor retains velocity and freezes stun,
gravity and collision stepping. On resume, its stun branch brakes horizontal
velocity, applies gravity and resolves terrain collision. Neutral motor behavior
resumes after stun.

## Reset, disable, removal and interrupted delivery

Call `reset_history()` **before** the host teleports or resets the receiver.
Then call the motor's `reset_at(position)` and the target's `reset_target()`.
Resetting only the target's visible counters does not reset physical motion.
The passive review host wraps exactly this ordering; the old motor and target
scripts remain unchanged.

Reset, binding changes, enabled transitions and scene pause/resume invalidate the
component's current delivery generation. They also reject all deliveries for the
remainder of that real engine physics frame, including an otherwise valid new
strike in that frame. Admission resumes on the next physics frame. This prevents
an earlier `struck` listener from resetting the target, then letting a later slot
apply the old contact. Tests must advance a real frame; repeatedly calling a
synthetic tick within one engine frame does not clear this fence.

`enabled = false` or `unbind()` stops future responses. Exiting the tree
disconnects the receiver. These actions do not zero already-committed velocity,
stun or pause: the motor owns them and finishes them normally. Use the explicit
host reset when that motion must be cleared. No impulse is queued or deferred,
so reset cannot later release a hidden old launch. A disabled/nonprocessing motor,
paused tree, disabled processing mode, detached/reparented receiver, deleted source,
or another world rejects before assigning motor state.

The consumed-source history belongs to the receiver's lifetime, held in private
runtime metadata. It uses weak source references and the highest consumed serial
for each source. PC serials increase between attacks. Resetting counters,
resetting the body, disabling, detaching/rebinding, or replacing this component
does not make an already consumed source/serial fresh. Freed sources are pruned.
The bound is 64 live source identities per receiver; if full, a new source rejects
until one is freed. It does not evict a live source and accidentally permit replay.
Two different source objects can both apply serial 1.

The stock motor's impulse/pause methods do not emit callbacks. If a host subclass
adds callbacks, the component rechecks binding, receiver/source lifetime and
current source strike between calls. A reset, detach, disable or retired source
after impulse prevents a later old pause or receipt; the already committed impulse
remains an applied fact. Nested consumption during these calls rejects. Receipt
listeners can reset, rebind, free nodes, or admit a newer strike; the component
does no stale mutation after publishing its receipt.

## Diagnostics and validation limits

`knockback_applied(receipt: Dictionary)` fires only after the physical commit.
The receipt is read-only and contains values only: `source_id`, `receiver_id`,
`motor_id`, `serial`, `contact_position`, `input_impulse`, `applied_velocity`,
`stun_seconds`, `pause_seconds`, and `physics_frame`. It owns no actor references.
`last_receipt`, `recent_receipts` (at most 16), and `diagnostic_snapshot()` return
copies. Editing a diagnostic copy cannot alter consumption history or motor state.

`applied_count` counts committed impulse calls, including a commit whose later
notification was retired by a host callback. `rejected_count` and `last_reason`
describe rejected input. `reset_diagnostics()` clears visible counters/history
only; it never rearms a consumed strike. A read-only signal receipt remains a
historical fact even if an earlier listener resets the body before a later
listener receives that same receipt.

Validation requires live same-world source/receiver/motor, current source strike,
an integer nonnegative serial, strict captured active/eligible flags, finite
Vector2 contact/impulse, and finite bounded tuning. Very large finite inputs that
overflow when scaled reject rather than assigning nonfinite velocity. The
component ignores packet damage, facing and any packet-provided pause/stun values.

This is a defensive synchronous boundary, not a cryptographic receipt or an
independent contact detector. An arbitrary caller can construct a dictionary;
actual contact is established by the unchanged ContactAdapter call path. Keep
the target's raw delivery counter visible so duplicate deliveries remain
observable even when duplicate physical effects are suppressed.
