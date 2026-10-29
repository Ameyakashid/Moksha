# Shared admitted damage and committed hurt response

This bounded checkpoint adds a role-neutral response capability to the existing
shared actor. The controller remains the single action/motion owner, Godot
remains the collision engine, and the optional Health/Defeat/Noise components
retain their existing jobs. It does not migrate Warden or modify a mission
factory, enemy action sequence, room, route bot or difficulty value.

## Authored capability and committed copy

`MokshaMeleeStepProfile.hurt_protected_phases` defaults to an empty list. Opting
in to `windup` and/or `active` makes a committed step resist short hurt responses.
Only those two phase names are valid; recovery, idle and held charge are never
implicitly protected. `hurt_interrupt_seconds` defaults to 0.70, must be finite
and nonnegative, and uses a strict comparison: an effective stun duration below
the threshold is braced; an equal or greater duration enters ordinary hurt.
Impulse strength does not decide the threshold. Malformed configuration rejects
step admission rather than silently granting protection.

Existing chain/input snapshots deep-copy the authored step. A source-resource
edit changes future snapshots, not the committed action. Replacing the chain or
input profile retires its authority under the existing configuration epoch,
including before the next physics tick. Peers do not share mutable runtime
response state. Protection requires the actual current committed step and its
phase, never an AI state, role label, synthetic counter label or public payload.
`hurt_response_snapshot()` returns only a defensive read-only scalar dictionary
with current protection, phase, serial and threshold. It never exposes the
committed Resource.

## Admission is distinct from recoil

The existing incoming melee, cargo and projectile receivers still require their
real contacts and current permits. No new success path or fake hit is added.
When an admitted unguarded contact is braced:

- Full residual damage is published once to the ordinary Health observer.
- The current action, weapon serial/phase, facing, input buffers, local velocity
  and actual support are not changed by this response.
- One `hurt_braced` event replaces recoil-only `hurt_started`; the existing
  hurt noise and configured hurt hitpause still run, with callback fences.
- There is no recoil cancellation/undo, alternate movement solver, duration
  timer, damage reduction or role-specific branch.

The effective duration is the incoming `stun_seconds` when present, otherwise
`combat_profile.hurt_seconds`. A long admitted response uses the unmodified
ordinary `_receive_hurt` path. Recovery, idle, charge and empty-default profiles
retain ordinary recoil. Forced cancellation, hard landing, reset and death are
not blocked. A lethal braced Health debit clamps to zero and the existing
DefeatResponse retires the action, including any future active contact.

`receive_attack` now distinguishes `admitted_damage`, `braced`, `hurt_applied`,
`applied_recoil` and `attack_interrupted`. `hurt_applied` retains its existing
meaning of committed ordinary recoil. `receive_hit` returns true for an admitted
damaging hurt response, including an opted-in braced contact. Untouched profiles
keep their prior return behavior. `attack_interrupted` records whether the
existing weapon generation changed during the response, including a synchronous
external callback; a brace does not prevent an independent forced interruption.
The immutable controller damage receipt carries `braced`, `applied_recoil` and
`attack_interrupted` as integer 0/1 flags, preserving its existing scalar types.
The interruption flag describes the controller response before later Health/Defeat
callbacks; lethal cancellation is separately owned by Defeat. A controller amount
is not a confirmed Health loss. Consumers count only the
matching Health `damage_processed.applied` fact and generation.

Before each new feedback callback, the response captures scalar origin,
loudness, pause, effective duration, threshold and action identity. Target
reset/removal blocks old-life Health delivery. A same-life callback may retire
the action; admitted damage remains a fact while stale sound/pause stops. No
callback is allowed to replace a newer action's motion with old recoil.

## Counter response configuration

`ShieldCounterReceiver.response_stun_seconds` defaults to -1, which omits the
payload override and preserves the actor's ordinary hurt duration. Valid explicit
values are finite 0 through 5 seconds. Other values fail closed for counter
admission, without changing an independently completed incoming parry.

The exact value is captured in the receiver generation token. Its setter retires
binding authority, including changes away and back. Currentness is rechecked
after virtual validation and after the actual canonical ray's one-use claim,
including a final local read after the source callback. The receiver can apply
the configured stun only through that existing verified contact pipeline.
Canonical source damage/impulse stay unchanged. A guard, failed/out-of-range/
blocked counter, or arbitrary `kind=area` label cannot fabricate retaliation.

The generic gym opts both actors into 0.78 seconds so a genuine counter breaks
their 0.70 brace. A future Warden may select that same data; production Warden is
unchanged in this checkpoint. Existing nonbraced receiver defaults are unchanged.

## Narrow Health replacement correction

Independent tests reproduced a preexisting bug in the frozen Sentry checkpoint:
a real melee `hurt_started` callback could replace or rebind Health on the same
actor generation, then the older in-flight contact debited the new binding.
Both 60 and 120 Hz showed 30 becoming 29; red harnesses and logs are retained.

The actor now reserves a monotonic admission serial at `receive_attack` entry,
before any callback, and exposes `damage_admission_sequence()`. Each Health
binding captures a fixed floor of the current sequence plus one. Older in-flight
receipts cannot debit a replacement or rebound store. Rejected/duplicate calls
can leave serial gaps. The floor is not advanced after each debit, so nested
N+1-before-N receipt delivery remains valid. Fresh nested work after a replacement
is accepted. Reset/late bind is fenced, and legacy providers without the optional
accessor retain their prior behavior. This is an intentional lifecycle correction
outside the new opt-in field, so unchanged defaults are not claimed byte-identical.

## Gym and verification scope

`bracing_sandbox.tscn` is independently runnable and is stage 07 in the selector.
Both instances use the same `bracing_chain.tres`; the NPC requests ordinary
inputs from observations. Gold shoulders show the committed protection state.
HUD counts are Health-confirmed braced hits. J attacks, K guards/parries, A/D
moves, Space jumps and Shift rolls. R reloads the full scene; Esc returns to the
gym. The scene never assigns a successful damage/recoil/defeat result.

`hurt_response_regression.gd` exercises real melee, real cargo solver contacts
and canonical counter rays through PC/NPC input at 60 and 120 Hz. It covers
windup/active, recovery/idle/charge/defaults, strict duration boundaries, extreme
impulse independence, full Health/noise/pause, lethal Defeat, profile isolation,
failed counters, config-capture retirement and callback/binding lifecycles.
Direct nested/API probes are labelled and do not stand in for successful hits.
`hurt_projectile_regression.gd` uses ordinary emission, timed genuine reflection
and actual returned sweeps, including threshold and lethal cases.

The shared response intentionally does not preserve the old Warden's separate
220-length counter impulse cap, ordinary horizontal recoil scaling, copied
source pause capped at 0.12, or unconditional 0.75 retaliation after a parry
whose counter failed. Shared canonical impulse and authored hurt pause remain.
Ordinary shared melee hurt pause defaults to 0.06; physical cargo can explicitly
configure its own pause. Native viewing establishes only witnessed controls and
presentation; automated contacts establish exact duration/damage assertions.
No complete combat-feel, balance, physical corpse, acoustic propagation or full
mission actor-parity claim is made.

## Final counter target-state correction

Independent red probes also reproduced an older Sentry counter gap: a source
validation callback after the one-use claim could disable/re-enable the incoming
receiver, yet the old claim still debited Health before feedback was suppressed.
The new final non-callback check reads captured incoming binding, host generation,
body/hurtbox layers and exact current shape/rect/transform after that source hook.
It does not call another public currentness validator or create a validation loop.
Real post-claim callback probes cover incoming toggles, disabled/replaced/transformed
shapes, layer changes and counter-config changes; every retired case leaves the
incoming parry intact while admitting no old counter damage or recoil.

The independent stale-return probes also retire the source adapter or its shield
action after returning an earlier currentness result. A final stable source read
checks live process/ownership, the claimed adapter delivery scope and binding,
canonical permit fields, defender epoch, and its unconfirmed shield scope, saved
action/weapon generations and shield gates. No public validator is invoked again.
This closes both sides of the same preexisting claim-retirement boundary; source
reset, forced finish, shield-gate revocation, physics disable and adapter toggles
cannot authorize old counter work. Already completed incoming defense facts stay
independent; source reset/removal can suppress that retired source's diagnostics.
