# Shared incoming melee: actual contacts, one response owner

## Implemented boundary

`actors/shared_actor.tscn` now composes a detachable
`BodyShape/IncomingStrikeReceiver` and role-neutral `ContactConfig`. The exact same
combat controller still owns movement, attack phases, guard, parry, roll, recoil,
reset and defeat authority. Its authoritative response logic remains unchanged; the counter slice adds a
read-only scoped canonical request accessor. Health still observes
its `damage_resolved` receipts; neither AI nor this bridge writes health or motion.
Player InputMap and NPC intentions reach the same ordinary raw-input scheduler.

The receiver is a real Area2D child of the controller's actual BodyShape. After
actor readiness it shares that runtime Shape2D and inherits the body's center
transform. Crouch, standing and reset therefore use the controller's live shape,
not a second periodically synchronized body rectangle. Its own local transforms
must remain identity. Missing, detached, disabled or replaced body/child shapes
reject the contact. One registered receiver is permitted per host.

## Actual contact and authority

The existing ContactAdapter performs the real forward shape sweep, intersection
and clear terrain ray. It now requires the exact bound source and live processing
state, and excludes the source actor's descendant hurtboxes. For sources exposing
`strike_snapshot`, passed authoritative fields must match one canonical snapshot
captured before confirmation. Forged same-serial geometry, damage and impulse
cannot create a shared hit or drive a fabricated large-distance sweep. Existing
sources without that API retain the legacy contact contract.

Opt-in receivers expose `capture_strike_generation` and
`strike_generation_is_current`. The adapter captures receiver binding and target
reset generation before `confirm_strike`, then rechecks after both capture and
confirmation callbacks. Its synchronous permit binds adapter revision, exact
source and receiver objects, source reset epoch, strike serial, target generation
and consequential contact values. A dictionary replay outside the dispatch scope
is not a contact. These are trusted local gameplay interfaces, not a network
security/authentication protocol.

The bridge maps source `serial` to incoming `attack_id`, actual sampled origin to
`origin` and `source_position`, `damage` to `amount`, and preserves the actual
intersection point and authored impulse. `incoming_velocity` is zero: the existing
melee resolver derives the incoming direction from geometry. Recoil impulse is
not misrepresented as a measured weapon velocity. Blockable, parryable and rollable
are receiver settings; shield availability remains actor capability configuration.

## Identity, interruption and commit point

The source controller's attack serial increases over its whole lifetime and is
not reset by `reset_actor`. Incoming identity is source instance + melee + serial;
source `damage_generation` is a separate reset-epoch fence. A replacement source
is a different instance. Generic source extensions must preserve this serial
contract. Weak source/serial history is retained on the receiving actor across
receiver detach/replacement and actor reset. It has a 64-live-source bound; it
rejects overflow rather than evicting still-live identities and enabling replay.
The logical host ID is used for source confirmation and adapter visitation.

A receiver/source transition before dispatch prevents a target response from the
old captured token. Source confirmation may already have recorded the target or
started source hitpause; those earlier actions are not rolled back. The final
validated call to the existing `receive_attack` commits one controller operation.
If a later callback only retires the source or bridge, that operation may finish;
its effects cannot be rolled back. The controller's own target-reset/removal fence
still prevents an old operation debiting a new target life. Stale bridge feedback
and the remainder of that captured sweep stop.

The separately proven counter slice adds one observation-only exception: a
defender's completed `strike_resolved` parry receipt may survive when its
confirmed physical counter cancels the attacking source's strike. The bridge
must have observed that defender's matching zero-loss Health receipt, with the
same receiver/target generation, source reset epoch and adapter binding. Merely
returning `parried` or retiring a source for another reason does not qualify.
The source adapter's `contact_confirmed` feedback remains suppressed and the
captured attacker sweep still ends. `contact_receipt_is_current` never admits a
new response or restores attack authority; it validates an already completed
observation only.

Retirement ends that sampled operation, not the controller's entire attack serial.
A later genuine active physics sample may contact an eligible, previously unhit
actor. An already committed hit cannot replay against the same host, even after
reset/replacement. The acceptance tests distinguish these cases explicitly.
Global pause, disabled processing, bridge toggles, binding changes and mask changes
retire captures. Internal explicitly PAUSABLE observers also catch a pause/resume
cycle beneath ALWAYS-mode hosts. Missing/disabled observer dependencies fail
closed. Use `reset_actor` for a new life/teleport; directly refilling the
Health scalar is not a generation-reset API.

`ContactAdapter.confirmed_contacts` counts physical dispatches. It does not promise
a health debit. `strike_resolved` reports completed defense/accounting observations;
its `amount` is actual Health loss, including a lethal hit capped at remaining
health. Health callbacks that reset/rebind/remove state can suppress that report.
Defeat remains the existing detachable policy; ordinary lethal contact is retained
as a value receipt without authorizing any further response.

## Role-neutral configuration

`actor_contact_profile.gd` contains body layer/mask, terrain mask, hurtbox layer,
strike target mask, obstruction mask and groups to add/remove. `ContactConfig`
adopts a private duplicate and applies it after controller readiness. Runtime
changes use `configure(resource)`, not edits to a previously supplied resource.
The default shared configuration is body layer 32, body/terrain mask 1, hurtbox 64,
strike target mask 76 (64 plus legacy fixture4 and prop8), obstruction 1 and
`simulation_actors` membership, removing the inherited `combat_pc` group. These
are configurable composition choices, with no player/NPC branch. Existing
physical cargo mask 43 includes layer 32. Removing ContactConfig leaves its last
applied configuration; removing the receiver stops new incoming shared melee.

## Test and stage scope

`tests/incoming_strike_regression.gd` drives actual InputMap PC attacks, NPC raw
intent attacks in both directions, NPC-to-NPC contact, equal guard/parry/roll
outcomes, absent shield capability, rear/unblockable contacts, real range and wall
rejection, self exclusion, distinct strikes, multi-target admitted hitpause,
lethal Health/Defeat/Noise, private masks/groups, live crouch shape and real cargo
compatibility. Explicit API/callback probes cover altered payloads, foreign source
binding, capture/confirmation retirement, shape removal, reset and replacement.
They are separately labelled and never stand in for successful physical hits.

`strike_sandbox.tscn` is independently runnable and gym stage 05. A/D, Space,
Shift, J and K drive the player. The NPC's `melee_intent_policy.gd` observes real
terrain/LOS/range and requests movement or attack input. Contact and response
remain physical/controller decisions. R reloads the whole stage, Esc returns to
the selector and F12 captures the viewport.

## Explicit next boundary

Parry, guard and roll are implemented. `counterable` remains a configurable false
default; the Strike gym now explicitly enables the separately proven detachable
counter receiver. See `COUNTER_CONTRACT.md` for real ray admission, independent
identity, one-use permits and completed-parry receipt semantics. The immutable strike checkpoint preceded production migration. Current ordinary
sentinels and listeners now compose these bridges while preserving mission configuration,
defeat/room-clear, health/reveal/sonar and perception interfaces; see
`SENTINEL_CONTRACT.md` and `LISTENER_CONTRACT.md`. Other archetypes, corpse capability, acoustic propagation
and complete asset separation remain pending. All four mission routes and
both-rate legacy suites remain gates.
