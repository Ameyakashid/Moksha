# Reusing confirmed-strike target health

`strike_health.tscn` is one detachable receiver adapter plus an instance of the
existing `Health` scene. It translates an already-confirmed `struck(Dictionary)`
signal into the existing `damage_resolved` provider contract. The Health script
and scene are unchanged: they own current/capacity, clamping, change notifications
and one depletion event per positive-to-zero crossing.

This piece never creates attacks, queries contacts, moves a body, adds invulnerability,
heals during combat, or chooses death/AI behavior. At zero the passive fixture can
still receive contacts and knockback. `ContactAdapter` remains the spatial hit and
occlusion authority; the player still owns strike identity, phases and hitpause.

## Composition

- Instance `components/strike_health.tscn` next to an existing contact receiver.
  Set `receiver_path` to that receiver, for example `../Hurtbox`. Default `..`
  supports placing the component directly under a receiver.
- The receiver must be a live same-world `Node2D` with `struck(payload: Dictionary)`.
  Its synchronous delivery comes from the unchanged ContactAdapter.
- Set the child `Health.maximum_health` in the Inspector. The composed component
  defaults to3; capacity is sampled on reset using the existing Health rules.
- `bind_receiver(receiver) -> bool` also supports explicit integration. A failed
  bind preserves an existing valid binding; rebinding does not silently refill.
  Only one StrikeHealth owner may bind each receiver. StrikeKnockback uses its
  separate owner/history and coexists without either depending on the other.
- The example `fixtures/health_target.tscn` inherits the previous passive knockback
  target and adds this child. Its tiny host override calls `reset_to_full()` before
  the existing motor/contact reset. Removing StrikeHealth remains valid.

Removing or disabling health leaves the motor, hurtbox, contacts and knockback
running. `enabled=false` rejects new receipts and preserves the balance. Re-enable
alone does not refill. `unbind()` disconnects accounting without changing health
or motion. The component's exit disconnects it as well.

## Admission and accounting

The adapter requires a strict captured `eligible=true`, `phase=active`, nonnegative
integer serial, finite nonnegative damage, finite Vector2 contact position and a
live processing same-world source. The source must still confirm
`is_strike_current(serial)`. This query accepts the existing synchronous admitted
sample even after source hitpause starts; a fresh eligibility snapshot at that
point would incorrectly discard a real hit.

The amount is the payload's existing damage, with no new multiplier, rounding,
armor, damage type or randomization. Zero damage is a valid once-only receipt.
Finite overkill safely clamps in Health; its receipt distinguishes `amount` from
actual `applied` loss. Further hits at zero do not repeat depletion.

Identity is source object plus monotonically increasing strike serial. Two sources
can both use serial1. A weak-reference high-water ledger stays with each receiver
through reset, diagnostic clearing, disable, unbind/rebind and replacement of this
component. Freed sources are pruned. The bound is64 live source identities; when
full, a new source rejects rather than evicting a live identity and permitting
replay. No strong source references or deferred damage are retained.

`consume_strike(payload)` is a synchronous integration/testing seam, not a second
contact authority. Dictionaries are not unforgeable receipts. Only the actual
ContactAdapter→receiver path establishes a physical contact; separately labelled
API tests do not count as real hits.

## Reset and interrupted callbacks

Call `reset_to_full()` before resetting or teleporting the host. It advances the
provider generation, fences delivery for the remainder of the current engine
physics frame, then asks the existing Health to refill via its reset event.
Leave the child's existing `reset_with_actor=true` for this behavior. Calling only
`Health.reset_to_full()` does not fence the receiver's in-flight delivery and is
not the host reset API.

`reset_history()` advances the same fence without refilling or clearing consumed
identities. Enabled transitions, binding changes, and component pause/processing
notifications use it automatically. The next actual physics frame releases the
fence; synthetic calls within one frame cannot do so. A paused tree, disabled
component, unavailable receiver or deleted source rejects before accounting.

Identity is committed before publishing a read-only value receipt. The existing
Health verifies provider ID and generation when its slot runs, so an earlier
listener's reset or rebind cannot debit a new generation. Its existing notification
generation also prevents a health-change listener reset/removal from receiving a
stale depletion. The adapter performs no state writes after publication. Source
query recursion rejects; later distinct valid receipts can be processed normally.

`resolved_count` means admitted receipts emitted, not guaranteed Health commits:
a subscriber can be removed or a generation can be retired before Health's slot.
Use `Health.damage_processed` for actual before/after/applied accounting. Its
read-only receipt carries source/receiver IDs, serial, contact position, label,
amount, before/after/maximum and actual applied loss. `depleted` carries no policy.
`last_receipt` and `diagnostic_snapshot()` return copies; diagnostic clearing never
rearms identity or changes health.

## Authored values and source limits

No Dead Cells damage or health equivalence is claimed. The existing source audit
[`M21_KNOCKBACK_EVIDENCE.md`](../reference/M21_KNOCKBACK_EVIDENCE.md) records missing
commercial-game hit/damage method bodies. This pass uses the independently authored
MOKSHA contracts and reuses no commercial source or assets. REA was not required.

New review/composition choices are capacity3; a64-live-source safety bound; a
one-real-frame interruption fence; ordinary attack taps at0.35/0.55/0.78 seconds;
a3-second observation window per off/on pass; and a three-receipt visible history.
The wall layout mirrors the prior knockback review. These are authored demonstration
or defensive choices, not recovered gameplay constants. The existing responsive
chain damage1/1.15/1.8, attack timings, movement, knockback scale/stun and hitpause
are unchanged. Thus the demonstrated real sequence is3→2→0.85→0, with the final
incoming1.8 applying only the remaining0.85.

## Review and verification

F5 opens `target_health_review.tscn`. Q runs the same three ordinary input taps with
health off and then on; knockback remains on. J attacks, A/D moves,1/2 select health
off/on, R resets, F mirrors and Esc pauses. HUD/bar values come from actual Health
state and receipts. This does not script strike delivery or assign health outcomes.

Run `python3 combat_pc/tests/target_health_run.py --output-dir /tmp/moksha-health`.
It imports the project, runs real-physics plus separately labelled API tests at
60/120Hz, compares discrete outcomes, and exercises the actual review scene.
See [the focused report](../tests/target_health_report.md) for coverage and limits.
The current executor has no native display: functional tests passed headlessly;
visual layout and perceived feel remain unreviewed here.
