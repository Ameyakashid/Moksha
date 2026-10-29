# Shared production cargo admission

Current production actor/cargo contact configuration and the later shared support/pressure changes are documented in `ACTOR_CARGO_CONTRACT.md`. The checkpoint details below remain historical evidence.

The mission's ordinary crates and designated freight now inherit the same
`simulation/components/physical_cargo.gd` used by the physical-impact gym.
`demo/components/mission_prop.gd` only selects mission source policy and draws
its wire crate. Actor roles do not select contact admission or damage math.

## Deliberate gameplay changes

Previously mission crates used mask33 (terrain1 + NPC32), the production PC used
layer2/mask1, and the PC had neither a physical-impact receiver nor `take_hit`.
That accidental physical/damage exemption is removed. Both mission factories now
use mask43 (terrain1 + PC2 + cargo8 + NPC32), the mission PC composes the shared
receiver, and cargo can physically collide with other cargo. This intentionally
adds player cargo vulnerability and real cargo chains; it is not exact outcome
preservation. No faction/owner immunity is invented. An authentic returning crate
can affect its launcher. Melee peer masks and existing AI capabilities remain
unchanged.

Mission damage remains charged-only. Initial falling or rolling mission cargo
cannot damage an actor without a live production launch or captured chain
charge. Passive gym cargo retains its independently configured passive epoch1.
The existing launch still sets charge2.5s, target speed465, lift-185 and random
spin9..17, and performs the physical impulse, visuals, sound and launch signal.
Mission contact threshold80 and damage3 come from the existing private prop
tuning at ready. Response180 plus vertical bias-80, stun.42, blockable/parryable/
rollable are the shared profile's authored responses. They are not kinetic-energy
damage or mass-conserving character motion.

## Source authority and deferred geometry

The unchanged core source contract captures real Godot solver contact position,
normal and both contact-point velocities, including rotation. The closing normal
component, not absolute COM speed or proximity, gates admission. A source-owned
immutable pending packet, weak target/receiver references, epoch, lifecycle,
receiver binding and provider generation authorize one synchronous delivery.
No fabricated pending packet, `take_hit`, group splash or fallback damage is used
when a receiver is missing, disabled, stale, obstructed or otherwise rejects.

Two narrow shared controller corrections are required for the production
composition. An authenticated captured projectile's exact live same-world physical carrier is excluded
from the obstruction ray so that an actor whose terrain mask includes cargo does
not treat the incoming crate itself as a wall. Every other terrain/cargo blocker
remains in that ray; ordinary non-permitted projectiles and melee/area payloads
receive no carrier exclusion.

Also, a cargo-colliding character can already move between the solver's captured
surface contact and the deferred response. The receiver grants a single exact
attack-derivative permit while its source packet is live. The controller verifies
the host's registered receiver, descendant/world/lifecycle, and that one-use
scope before replacing only its redundant *current* body-rectangle check. The
original captured point is neither moved nor fabricated. Obstruction, current
shield geometry, roll capability, incoming identity and every source/host
generation check remain in force. The permit is claimed before extension
callbacks, and incoming identity is checked again after them. An altered attack,
a later call or an unrelated attack cannot borrow it.

## Epochs, charge and chains

A source begins epoch1. Only a valid production `launch` advances its epoch and
clears its visited actors and chain recipients. Each receiver can consume at most
one contact per source epoch, regardless of bounce, rest or later recontact.
Charge expiry retires pending damage/transfer packets; simulation disable,
relaunch, pause/tree transitions and explicit invalidation do the same. A new
source identity is distinct. Reposition/reset callers must invalidate first.

Shared charge transfer replaces the inherited direct charge assignment through
a minimal stock-prop extension hook. It requires a real rigid contact between
two compatible shared sources, active donor charge, and relative normal closing
speed strictly greater than the donor's chain_speed130. The donor's exact
source-owned pending charge packet and one-call scope bind the target's epoch
and lifecycle. Each donor epoch transfers to each recipient at most once. The
recipient receives max(current charge, chain_charge_seconds1.5); no launch,
velocity assignment, torque, epoch advance or receiver-history clear occurs.
Godot alone exchanges the physical momentum. Target/source retirement fences a
queued transfer; receiver reentrancy is rejected.

Consequently, recharging a recipient that already spent its epoch on an actor
cannot hurt that actor again. Even relaunching the recipient does not let the
same donor epoch transfer to it again. A new genuine donor launch can transfer
again, while only the recipient's own genuine launch rearms its actor history.
Resting pairs cannot perpetually extend one another's charge. The legacy stock
crate still uses its original compatibility charge behavior; mission factories
never select that source. Compatible shared cargo is required for the new chain
protocol, not an arbitrary object that merely exposes `launch`.

## Actor capability and terminal response

The production PC and shared sentinel/listener use DEFENDED_ATTACK with their
existing controller, Health and DefeatResponse. The legacy enemy base scene now
composes HEALTH_AND_IMPULSE with its existing StrikeHealth/Health provider. Sentry
and Warden inherit that scene; their controllers, AI and projectile logic are
unchanged. No second health store or motion solver is introduced. The gym NPC
now inherits this same receiver rather than adding a duplicate registration.

Unguarded contacts debit the same authored three damage and deliver the same
normal-based response request. Existing host mechanics still decide motion.
Warden's virtual apply_impulse preserves bracing during genuine windup/active:
short cargo stun.42<.70 produces full damage but does not cancel that committed
attack or add recoil/stun. Ordinary shared enemies have no shield/roll intent
capability. A configured PC's frontal held guard retains75% absorption, timed
parry prevents damage, and an invulnerable roll can evade. Cargo never advertises
reflection or a melee counter. Real rigid-body solver contact still occurs.

Mission cargo selects break_on_accepted_impact. One accepted response, including
accepted guard/parry/evade, can consume that fragile crate. Rejection/retirement
cannot authorize a break or any fallback hit. Existing material-impact noise and
hard-impact break counts continue independently, including for uncharged crates.
Health-confirmed actual damage (including fractional guard and lethal clamp) is
in the immutable physical receipt. The old integer `impacted` presentation signal
retains the authored amount, not a second damage application.

Receipt callbacks can reset/rebind/disable an actor or source. Generation/binding
checks suppress subsequent impact/shake/burst/break authority. Once a valid break
sets alive=false, destruction is committed: exactly one terminal destroyed signal
and queue_free still complete. A callback at prop_break can suppress later stale
break-burst presentation; it cannot revive a committed destroyed source. Source
replacement from the freight cradle explicitly invalidates pending authority
before retiring the old crate. Freight support/settling, latch, shutter, E
replacement, room retry and mission objectives remain genuine physical rules.

## Verification and limits

Run `python3 simulation/tests/run_cargo_acceptance.py`. It runs the focused
production cargo suite and both-rate foundation/stock/freight checks, the
historical aggregate, and all four real-input eight-sector mission routes.
`mission_cargo_regression.gd` uses actual InputMap J/K/Shift, physical production
sources/hosts and controlled fixture positions/initial velocities. Its equal-hit
raw-J fixture uses explicit horizontal/no-spin tuning to avoid asserting that
every randomized launch must hit. Production launch values are unchanged and
remain exercised by mission/freight routes. Initial-charge and callback lifecycle
probes are explicitly labelled; they do not fabricate successful collisions.

The independent reviewer runs a separate copy and adds charge/epoch, captured
geometry authority, obstacle and callback-retirement probes. Native rendered
observations are a separate gate with explicit coverage limits. Exact results,
source manifests and immutable archive hashes accompany the acceptance record.

This slice does not unify the remaining actor motion solvers or ranged attack
protocols, add physical corpses, change Warden AI/bracing, simulate acoustic
reflection, add splash, or establish complete physical realism/finished feel.
Contact report and live-source-history capacity remain finite. The APIs are a
local trusted-script gameplay boundary, not a sandbox against arbitrary scripts
that already own direct health or physics access. The sentinel legacy take_hit
shim remains for historical stock-crate/lifecycle fixtures; no mission cargo
source can dispatch through it. Prior checkpoint ZIPs remain immutable.
