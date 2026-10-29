# Shared shield counter: a separate actual-contact effect

## Composition and authority

`ShieldCounterReceiver` is an optional root child of `shared_actor.tscn`. It is
uniquely registered on the actor by a weak reference. It requires that exact
actor, its bound Health component, and the existing registered
`BodyShape/IncomingStrikeReceiver`. There is no second physical hurtbox and no
role test. Player input and NPC intent drive the same controller.

Incoming melee retains an explicit `counterable` setting, default false. The
Strike gym and focused counter suite opt in. Removing or disabling the counter
receiver withdraws retaliation, without changing a completed incoming parry.
Shield and attack availability remain ordinary actor capabilities; counter
strength/range/impulse remain the existing per-actor shield profile.

The shield adapter first validates the complete canonical request using a new
read-only `shield_effect_snapshot()` accessor. That accessor returns a defensive,
read-only copy only during the controller's already-existing synchronous effect
scope. It adds no outcome, state or movement mutation. All existing defense,
recoil, hitpause, attack cancellation and damage receipt logic is retained.

## Physical permit

The generic ShieldContactAdapter discovers the registered opt-in receiver. It
captures receiver binding and target damage generation, exact shared hurtbox and
shape identity/size/transform, and incoming receiver generation before querying.
An actual ray to the live hurtbox must hit it before any configured obstruction,
within authored range and frozen shield-facing geometry. The defender and all of
its descendant collision objects are excluded. A missing or disabled real body
shape cannot substitute an approximate box. Legacy host
`receive_shield_counter` and projectile `reflect_from_shield` routes remain.

Only this synchronous dispatch creates a one-use claim. It binds exact adapter,
defender, target actor, receiver, adapter revision, target/defender reset epochs,
shield serial, original incoming attack key, ray contact, origin, damage, impulse,
facing and range. Altered dictionaries and replay outside that scope reject.
Pause/resume (including ALWAYS-mode hosts), disable/re-enable, detachment,
rebinding, mask/config changes and reset retire captured authority. Internal
explicitly PAUSABLE observers must be present and correctly configured.
These are local trusted gameplay contracts, not network authentication.

## Response and identity

The receiver only calls the existing `receive_attack`. It never assigns health,
velocity, position, attack/defense state or defeat. Health observes the normal
controller receipt; Noise and Defeat retain their own existing roles. The
counter payload is nonblockable, nonparryable, nonrollable, noncounterable and
nonreflectable. It is a resolved retaliation, not a fresh shield duel.

Counter identity is defender instance + `area` + lifetime-monotonic shield serial.
Ordinary melee identity remains source instance + `melee` + attack serial, so the
same numeric serial cannot collide. A future unrelated shared area emitter must
not reuse this reserved identity lane. Reset epochs are additional fences, not
serial replacements. Weak per-defender high-water history lives on the receiving
actor across reset and receiver replacement. Dead references are pruned; 64 live
sources is a fail-closed bound, never an eviction policy that revives replay.

## Commit point and reports

Validated dispatch commits one existing controller operation. Counter recoil
cancels the original attacking actor's active strike, so the captured incoming
sweep ends immediately. A read-only ContactAdapter receipt predicate permits
only the already completed defender parry observation to survive that ordinary
retirement; it cannot authorize a new response or resume the sweep.

`counter_resolved.amount` is the actual observed Health loss, capped at remaining
health. Normal lethal counter emits one bounded debit/defeat and may confirm.
Target reset, Health replacement, source retirement or bridge changes during
callbacks can suppress diagnostics/confirmation. A callback from `counter_resolved` occurs after that value receipt has
truthfully completed: the receipt remains a fact, but a post-emission retirement
check suppresses stale adapter confirmation. Already applied work is never
described as rolled back. A retired effect can report its applied fact while
being unconfirmed. The controller's own target-generation guard prevents old
work debiting a reset life. A successful incoming parry remains logically
independent from whether an outgoing counter is reachable or accepted.

## Evidence and scope

`tests/shield_counter_regression.gd` uses timed real raw input, actual incoming
shape sweeps and actual counter rays for PC↔NPC and NPC↔NPC in both directions.
It checks nonlethal/lethal accounting, noise, recoil/cancellation, preserved parry
receipts, multi-target interruption, live crouch shape, missing shield/attack,
guard/rear/range/wall/disabled/absent receivers. Explicit boundary probes cover
canonical and permit alteration, replay, replacement, disabled/detached/cross-world
hosts, shape loss/change, reset, pause and hurt/Health/depletion callbacks.
No direct boundary probe stands in for a successful gameplay contact.

The gym remains five independent stages. Stage 05 now shows counter counts and
uses ordinary J attacks and timed K parries. R reloads the scene, Esc returns to
the selector, F12 writes `evidence/native_counter.png`, preserving prior strike
captures. Automated tests establish timing/defense; native viewing establishes
only observed controls and presentation. Audible mix remains unverified in the
cloud's dummy-audio environment.

The immutable counter checkpoint preceded production actor migration. Current
ordinary sentinel integration is documented in `SENTINEL_CONTRACT.md`; listener
configuration reuse is in `LISTENER_CONTRACT.md`. Ranged and Warden remain legacy. No new campaign content, universal faction policy,
physical corpses or acoustic propagation is included. All four real mission routes
and legacy shield/reflection/combat/Health suites remain regression gates.

## Optional response duration added by the shared hurt checkpoint

`response_stun_seconds=-1` preserves the host default by omitting the override.
Finite explicit values 0..5 are a target capability, captured in counter generation
and invalidated by any setter change. Only the existing canonical ray and one-use
claim admit it. Invalid values fail closed; a parry can still complete without a
counter. The generic bracing gym uses 0.78 to interrupt its 0.70 threshold; no
production Warden change is included. See `HURT_RESPONSE_CONTRACT.md`.
