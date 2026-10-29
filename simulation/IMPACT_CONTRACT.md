# Shared physical cargo impact: bounded module

The original opt-in checkpoint is extended by `MISSION_CARGO_CONTRACT.md`.
Mission cargo now uses this source with charged-only/break configuration and
mask43, including the production PC. The historical opt-in observations below
remain distinct from the later production verification.

Run `res://simulation/impact_sandbox.tscn` alone (F6), or choose stage 03 in
`simulation/gym.tscn`. A/D moves, Space jumps, J strikes/launches cargo, K guards,
R reloads the whole stage, and Escape returns to the selector. Two crates start
in real free fall above independently instanced actors. No trigger assigns an
impact, health value, forced fall, guard result, or target selection.

## Optional assets and host capabilities

- `components/physical_cargo.tscn` inherits the stock crate art, rigid body,
  launch, contact-noise and material-break behavior. Its script replaces both
  automatic and public legacy `take_hit` admission. Stock `prop.gd` retains legacy behavior through minimal charge/break extension hooks.
- `components/physical_impact_receiver.tscn` registers once on a physical actor.
  `host_path`, `health_path`, `provider_path`, `response`, and an optional
  `required_host_flag` describe capabilities. There is no PC/NPC tag branch.
- `actors/impact_player.tscn` composes the production combat PC, the existing
  optional Health and DefeatResponse, and a receiver using `DEFENDED_ATTACK`.
  The host's `receive_attack` owns shield geometry, guard, parry, roll, recoil,
  hitpause and its generation-stamped health receipt.
- `actors/impact_npc.tscn` composes the production NPC and a receiver using
  `HEALTH_AND_IMPULSE`. Its existing `StrikeHealth/Health` remains the only health
  store. The host's `apply_impulse` owns motion/stun; the receiver publishes a
  generation-stamped receipt through the existing provider. Positive configured
  hitpause additionally requires and uses the host's `apply_pause` API.
- Both assets require the same genuine solver contact to reach the receiver.
  Equal unguarded profiles debit equal health. Guard is a configured host
  capability; this module does not add a shield/roll decision system to NPC AI.

The source's mask43 includes terrain1, PC body2, cargo8 and NPC body32. An actor
also needs an enabled physical shape, compatible collision masks and a registered
receiver. Masking, configured availability and health eligibility are separate
requirements. Production mission cargo now selects mask43 and charged-only shared admission.

## Captured contact and response

`_integrate_forces` captures Godot's actual target-surface contact position,
world-space normal, source contact-point velocity and target contact-point
velocity. The velocities include rotation. Admission uses the closing component
of their difference along the normal, not total COM speed, proximity, an AI
observation or a timer. A wall can physically prevent the contact.

`physical_impact_profile.gd` supplies an enabled flag, minimum closing speed,
damage, response speed, vertical bias, stun, hitpause and blockable/parryable/
rollable flags. The response velocity is `-normal * response_speed` plus the
vertical bias. These are authored gameplay responses to real collisions, **not
kinetic-energy damage or mass-conserving momentum transfer**. Each host's existing
controller remains authoritative. Godot still solves the physical bodies.

Defense uses the existing identified `projectile` payload solely because that is
the PC's supported carrier contract. `reflectable` and `counterable` are always
false. A timed parry can prevent damage, but this module does not redirect the
rigid cargo, create a counter, or prevent the solver's ordinary physical contact.
Held guard retains the PC's authored 75% absorption and guard recoil. Overhead
contacts are outside the frontal shield when the stock geometry says so.

## Identity, lifecycle and receipts

A new source starts passive epoch1. Each receiver can be affected at most once in
that epoch, including an unlaunched falling crate. Bounce, resting contact and
later recontact do not automatically rearm damage. A valid production `launch`
advances the epoch and rearms receivers; source replacement has a new identity.
The same physical launch can reach multiple distinct registered receivers.

A source-owned one-use pending record retains the exact captured packet and weak
target/receiver references. Only that record may open a synchronous delivery
scope. Altered or fabricated packets cannot establish scope. The receiver checks
that scope, source epoch, receiver binding, host/provider generation, world,
process state, finite fields, capabilities and retained weak per-source history
before applying anything. Identities are consumed before callbacks; malformed
or retired packets cannot debit a fresh life. The replay history survives receiver
replacement and actor reset; at 64 simultaneously live source identities it fails
closed. Freed-source entries are pruned.

Use `set_impact_simulation_enabled` to pause this optional source. Call
`invalidate_pending_contacts` before an external reset or reposition; it retires
pending contacts without rearming damage. Launch and process/pause/tree
notifications perform that invalidation themselves. The source also fences
previous-step contact reports through the next physics frame. Arbitrary external
writes to inherited properties are not a substitute for these lifecycle APIs.
The normal stage resets by replacing the whole scene; it has no gameplay teleport.

Health and motion callbacks may reset, disable, rebind, remove or retire a host or
source. Generation checks prevent subsequent stale effects and feedback. Ordinary
NPC defeat advances its provider generation once: a matching completed lethal
`Health.damage_processed` receipt permits only reporting the completed terminal
contact. A reset-to-full/rebind/source retirement still suppresses the old result.

`impact_resolved` and `physical_contact_resolved` publish immutable value-only
receipts. `amount` is the Health-confirmed amount actually applied (so lethal
clamping is explicit); `residual_damage` is the defense result before Health's
remaining-health clamp. Contact position, point velocities, normal speed, epoch
and physics frame describe the captured event. Diagnostic copies do not mutate
history. A rejected response does not break cargo or apply a fallback legacy hit.

## Scope and verification

Run at both rates:

`godot --headless --path . --fixed-fps 120 --script res://simulation/tests/physical_impact_regression.gd -- --hz=120`

The suite has 225 checks per rate. Gameplay evidence uses production PC/NPC,
actual falling/rotating/moving rigid cargo, real relative closing speed, raw J
launch and raw K guard/parry. Explicit API/lifecycle tests are labelled; test-only
interceptors interrupt an already captured real contact and never manufacture a
successful gameplay collision. Tests cover source/receiver reset, disable,
replacement, pause, cross-world moves, malformed packets, replay barriers,
callback reentrancy, optional pause, lethal results and stale feedback.

The bounded module has no automatic repeated-contact damage episodes, splash,
faction model, physical corpse, complete melee/attack unification, or common
actor motion solver. Contact reporting is finite (at least 16 records per source),
so a sufficiently crowded scene can exceed capacity. Registered custom source
implementations are trusted to uphold the captured-contact contract; this is a
local gameplay integrity boundary, not a security sandbox against arbitrary
scripts. The opt-in assets depend on the rest of this project; copy the complete
project rather than only this directory.
