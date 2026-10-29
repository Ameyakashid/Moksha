# Shared opt-in projectile boundary

`actors/shared_ranged_actor.tscn` inherits the existing shared actor. Device input
and NPC intention use the same controller, action resources, emitter, swept
carrier, projectile receiver, Health, DefeatResponse and committed-noise path.
The production sentry factory and its legacy scenes are deliberately unchanged.
This is the separately reviewed adapter checkpoint before production migration.

## Action and aim

The default action is a one-step FRESH_ONLY chain: windup 0.72s, active 0.001s,
recovery 0.95s, no successor, zero authored phase movement, no phase turning and
zero inherited strike loudness. The existing controller guarantees one sampled
active phase, so release/recovery can be quantized by one physics tick. There is
no second attack clock, fire command, or AI write to action/motion/health.
Ordinary forced hurt/reset/cancellation remains controller-owned. Neutral input
is not cancellation of an already committed action.

The emitter locks one finite world-space aim point at the genuine attack-start
identity. Its read-only aim provider is independent of PC/NPC role. At release,
the current world muzzle aims toward that old point. Binding in the middle of
an action cannot acquire its old start. A canonical pose/charge-role filter is
available; this checkpoint tests FRESH_ONLY and does not claim held-charge
projectile support.

The one new controller accessor returns a defensive canonical action snapshot
only inside the preexisting synchronous strike-sample scope. Diagnostic
strike_snapshot or a manually emitted signal has no release authority. Complete
sample equality, live action identity and one consumed pending start authorize
one launch. Actor-retained start history survives emitter replacement. A typed,
actor-registered emitter grants a one-use launch claim during that same sample;
the carrier must receive its exact lease/configuration/damage/velocity then.
Ownership is recorded before add_child can invoke reentrant callbacks.

The ranged composition sets ContactAdapter.enabled=false, removing actual melee
admission instead of just stopping its processing. Positive warning and release
sound have one owner. Zero step loudness produces no committed melee sound; the
controller's raw noise_requested may still observe zero loudness. Release sound
is committed only after a real carrier is admitted, and a stale noise callback
cannot notify a new life of an old emission.

## One physical sweep, two directions

The existing guard carrier still owns its circular move_and_collide sweep. Its
legacy collision-dispatch statements were extracted unchanged into a small
hook. A defensive optional collision snapshot now exists only around that real
collision. Stock carriers keep the original default dispatch and fallback.
The shared subclass does not copy the sweep or add an alternate motion solver.

Only the opt-in shared carrier uses the new registration. Both outgoing and
reflected shots require an explicitly registered projectile receiver on the
actual collided body. An absent/disabled/ineligible receiver intercepts without
any fallback damage call. The receiver binds root Health and the actor's exact
existing BodyShape; it adds no second hurtbox. Source role is never an exemption.

The live permit binds the genuine collider/shape index, carrier and target
transforms, current carrier shape resource/geometry/transform, velocity/masks,
owner and attack ID, source lease, receiver binding/reset generation, body shape
resource/geometry/transform, original sweep origin, actual contact and authored
response. Capture/currentness/claim callbacks are revalidated before commitment.
One claim and actor-retained per-carrier history reject nested/duplicate/replayed
work across receiver replacement. No public last_contact or copied packet grants
authority. Old contact geometry cannot be borrowed after callback mutation.

The receiver calls the existing receive_attack once, with kind=projectile and
carrier-based identity. That controller alone chooses guard/parry/roll/hurt,
recoil, cancellation and incoming identity. Health.damage_processed supplies
actual applied damage, including fractional guard and lethal clamping. It never
injects a damage signal, assigns health, or directly moves an actor.

## Reflection and completed facts

Reflection requires the defender's genuine canonical shield-effect scope and
the still-current claimed physical receiver/body permit. A direct reflect call,
changed payload or retired receiver cannot redirect. Successful reflection is a
physical fact: the old source exception is removed, the defender exception is
installed, ownership changes, attack ID increments once and the reflected mask
applies. Later confirmation retirement never undoes an applied redirect.

Outgoing defense flags are configurable, defaulting to block/parry/roll and
reflection. Return defaults preserve the old unguardable/unrollable response:
horizontal 100, vertical -45, stun 0.5. Return damage is max(canonical shot damage,
minimum 2). Thus authored standalone damage 1 returns 2; a future mission damage 12
shot returns 12, never 2. The actual projectile can hit its original source or a
third registered actor. A returned shot is consumed by its first physical
receiver/obstruction and cannot repeatedly return.

A completed observed Health fact survives source retirement or lethal Defeat
callbacks. A replaced/reset target receives no stale notification. Unobserved
or rejected damage is not inferred from the requested amount. Receipts include
the original generation and whether later retirement occurred. Physical work,
observed receipt and later feedback confirmation remain distinct.

## Lifetimes and configuration

Pending action and launched flight have separate lifetimes. Ordinary recovery
and nonlethal source hurt do not erase an existing shot. Source reset, defeat,
exit, emitter disable/rebind/replacement/profile change and explicit carrier
retirement remove all owned flights. Equivalent profile replacement also retires
old authority. Carrier configuration is private per launch; shape/owner/velocity
or mask mutation cannot retain the old contact authority.

Global pause freezes flight and invalidates transient contact permits. Pending
warnings are retired on pause transitions; a held input cannot invent a new
start on resume. Explicit carrier process/simulation disable retires the shot.
A reflected owner must remain in the same world, process/physics-enabled, alive
and in the same reset generation. Its owned fence is removed with the carrier;
disable/exit and later reset invalidate the return. No reflector fence or sibling
carrier may remain after scene/source cleanup. Expiry uses the inherited carrier
age, not an extra action clock.

Profiles expose masks, muzzle offset, speed 245, radius 3, lifetime 2.2, return
minimum/response, defense flags and warning/release sound. Default shared masks 41
are terrain 1 + cargo 8 + shared actor 32, obstruction 9. Cargo blocking in both directions
is intentional shared-world behavior; old mission projectile masks 3/33 remain
unchanged until a separately approved migration. The spawn circle and body-to-
muzzle segment also reject blocked muzzles. Damage comes from the canonical
controller action, not a duplicate profile damage value.

## Verification and honest limits

`projectile_regression.gd` runs at 60/120 with ordinary InputMap PC and NPC/raw
intention, real swept contacts, actual timed reflection, moving cargo, thin walls,
door closure, blocked muzzle, guard/roll/capabilities, another return target,
source/receiver/configuration lifecycle, shot expiry, positive committed sound
and lethal observed receipts. Explicit malformed/lifecycle API calls are marked
as such and never stand in for a successful physical shot. Independent review
adds separate callback/provenance/replay/shape/world/legacy regression probes.

The sixth gym stage is independently runnable; A/D, Space, Shift, J and K are
ordinary controls, R reloads and Esc returns. Native review observed an actual
traveling bolt, bidirectional Health/contact changes after moving past cargo,
reset and a readable selector. Cargo interception was inferred from bolt ending
and no actor contact, not a sampled impact frame. Native timed reflection and
exact timing/audio mix were not established; automated physical tests supply
the reflection evidence. An editor refresh during implementation briefly saw
inheritance parse errors. On the frozen sources, a full native Project Reload
restart and F6 selector→Projectile launch closed that issue: no current parse or
gameplay runtime error, only audio-device/dummy/VSync and existing lint warnings.
Independent no-cache import and 300-frame boot also passed.

Run `python3 simulation/tests/run_projectile_acceptance.py` for the frozen-source
foundation, preserved stock suites, historical aggregate and four full mission
routes. Final reports/hashes and independent review evidence accompany this
checkpoint. All previous ZIPs stay immutable. This is a trusted local-script
interface, not a security sandbox against scripts with direct object/health
access. It does not establish universal attack parity, full acoustic physics,
physical corpses, production ranged migration or finished combat feel.

## Later production sentry composition

The subsequent production migration is specified in `SENTRY_CONTRACT.md`.
It adds a default-false optional clear-aim release gate, defensive pending aim
view and default-zero(any) receiver owner-layer filter. Previous opt-in defaults
and stock physical sweep remain unchanged. Production composes all-body43/43
collision with explicit damage admission; source-layer/filter mutations retire
captured contact authority. Do not interpret the earlier opt-in-only scope as
claiming that the new production scene still uses the legacy sentry controller.
