# Shared non-solid world boundary

## Composition and physical meaning

Every production room composes `BoundaryHazard`; the mission PC, all four shared
NPC factories, ordinary props and designated freight compose `BoundaryReceiver`.
The mission places the default local y = 0 boundary at room y = 420. It has
no collision shape and does not supply support. Godot movement/gravity puts each body there;
the hazard observes its configured witness after ordinary actor physics.

The default witness is **the body's origin** for every role, with zero local
receiver offset. Actor origins happen to be at their feet; cargo origins are at
their centers. This is one explicit point rule, not a claim of shape-overlap or
whole-body containment. A transformed hazard uses its local y > 0 half-plane;
exactly on the line is safe. A finite per-receiver witness offset is configurable
for other assets and does not depend on player/NPC identity.

The source only scans registered, live, processing receivers in its current
ancestor world scope. Missing/disabled capability is ineligible. Default
`OCCUPANCY` applies once on the first eligible outside sample, labelled
`initial_outside`, not a crossing. `REQUIRE_INSIDE_FIRST` requires a safe sample
first. `crossed` is true only for consecutive eligible safe/outside observations
with unchanged source transform and witness offset. Geometry changes are labelled
separately. This is discrete sampled position evidence, not a swept crossing
proof between every sample.

## Episodes and response configuration

An outside episode is reserved **before** admission or callbacks. It gets one
attempt, even if admission later retires or a partial effect happened. Continued
outside occupancy, pause/resume, receiver replacement or same-life Health reset
does not grant another attempt. A genuinely observed safe sample rearms it. An
actor `reset_actor` creates a new damage generation and a new episode; a new cargo
body is a new lifetime. Disabled receivers are not sampled. On re-enable, an
unseen host's initial occupancy follows the configured policy.

`BoundaryProfile` privately configures lethal-current-Health (default), fixed
nonnegative damage, and nonnegative hurt duration. The authenticated observation
calls the **existing** controller admission, immutable damage receipt, Health
debit and optional DefeatResponse. No boundary code assigns Health, NPC `dead`,
mission failure or room clear. Guard, parry, roll and committed bracing do not
exempt a body from this world constraint. This privilege requires the registered
receiver's exact one-use synchronous permit; there is no general bypass flag.
The attack retains current velocity rather than adding a fabricated launch.
Configured damage is not an impact-energy simulation.

Cargo explicitly selects `CARGO_RETIRE`. A current canonical packet retires its
pending impact/charge captures, increments source epoch, clears charge and visited
targets, and marks it non-simulating **before** presentation or the one `destroyed`
fact. Nested launch/break and pending packet delivery cannot revive it or debit a
later target. Godot removal is deferred normally. The freight cradle observes the
same destroyed fact and its existing replacement API remains available.

## Guarded Health debit and lifetime fence

Ordinary incoming receipts retain their existing trusted controller-signal
contract and nested ordering. The new optional, role-neutral guarded debit has
four integer fields only: Health instance id, binding epoch, change epoch, and
reservation serial. Health internally reserves weak participant references,
world, native transforms, physics-processing state, physics frame and exact
controller generation/admission serial. No Node, Resource, Callable or validator
is inserted into `damage_resolved`. The sealed receipt is scalar-only and
read-only; only that exact Dictionary identity may consume the reservation.

The one-use claim and the final debit check are separate. At actual debit, Health
locally rejects reset/rebind/replacement, changed participant identity/world,
queued/detached/paused/disabled participants, transform changes and frame expiry.
There is no user callback in this final validation. An earlier signal listener
therefore cannot reset the same Health store and let the old lethal amount debit
the new state. Nested genuine ordinary damage may retire the older guarded
reservation without suppressing the newer genuine receipt. Ordinary N+1-before-N
receipt ordering remains supported; there is no global highest-serial filter.

Up to 16 outstanding reservations are retained, pruned on reserve, and expire
when the synchronous receiver/source scope closes or on reset/unbind. A bounded
128-range scalar admission history recognizes previously guarded generation /
serial pairs even if optional fields are stripped from a copied receipt. Adjacent
serials merge. At capacity a new disjoint guarded admission fails closed; ordinary
damage remains usable. History survives same-life Health reset and clears on new
generation or binding; the existing binding floor rejects earlier serials.
There is no persistent Node/token history. This is an in-process component
contract, not protection from arbitrary hostile script rewriting private state.

Source and receiver property setters and lifecycle notifications invalidate active
scopes. Source/receiver local-transform notifications catch move-and-return in a
callback; canvas/world notifications retire a world swap even if restored before
the receipt reaches Health. Production room and mission roots inherit `BoundaryScope`, whose
synchronous local-transform hook invalidates descendant observations. For other
external repositionable ancestors, compose that hook or call
`hazard.invalidate_observations()` **before** repositioning; uninstrumented
ancestors are otherwise expected to stay fixed during delivery. Native equality
checks alone do not promise detection of every arbitrary ancestor move-and-return.
A result is `resolved` only when a matching genuine current `Health.damage_processed`
fact was witnessed, including valid zero damage, or cargo retirement committed.

## Mission observation

PC loss now observes the current `DefeatResponse.defeat_started` lease, current
player/response identities and the mission Health bound to that actor at zero. Stale defeated
actors cannot pause or count a death against a freshly reset/replaced player.
Existing failure, pause and retry behavior then runs once. NPC room-clear and
kill accounting observe the existing common Health → Defeat → facade facts.
The actual authored Cistern gap is not a locked combat room. The locked-gap
regression demonstrates a reusable risk and fix, not a claim that the original
campaign contained that exact locked-gap softlock.

## Independently runnable review and verification

Open `res://simulation/boundary_review.tscn` and press F6. The title explicitly
labels a **locked-gap review fixture**. It clones Rainline with initial geometry /
spawn configuration: an open floor gap, four real factory NPCs initially airborne,
neutral AI intent, two real props, and the common y = 420 boundary. There are no
fall/kill/clear triggers. A/D walks, Space jumps, J can launch cargo, Enter retries
after ordinary defeat. The red line and fixed two-line HUD legend show the rule.
This is an isolated fixture, not a full-route native playthrough.

`godot --headless --path . --fixed-fps 60 --script res://simulation/tests/boundary_regression.gd -- --hz=60`

Repeat at 120 Hz. Production tests include five-role actual gravity crossings,
real guard/parry/roll/bracing, landing/edge/jump-return negatives, rotated geometry,
initial occupancy policy, real reentry, fixed/zero damage, charged/passive and
factory freight retirement, genuine held impact/charge callbacks, prior-listener
Health/reset/binding/source races, stripped/copied receipt replay, stale mission
observers, actual Cistern defeat/retry and labelled locked-room clear.
Initial placement and direct API/lifecycle probes are labelled separately from
actual physical crossing evidence. Tests do not teleport a body to manufacture
an asserted gravity outcome.

`python3 simulation/tests/run_boundary_acceptance.py` runs the prior 69 foundation
stages plus boundary review/60/120 (72), stock compatibility, held input, four
Health/Defeat/shield compatibility suites at both rates, the 19-stage historical
aggregate and all four full input-driven production routes. It records fresh
`boundary_*` evidence and restores preceding report bytes. Final measured counts,
independent review, native limits and preservation hashes are indexed in
`evidence/boundary_acceptance.json` and `VERIFICATION.md`.

This checkpoint does not implement physical corpses, shape-overlap hazards,
physical acoustics, new campaign content, balance guarantees, decorative asset
extraction, or a universal environmental damage engine.
