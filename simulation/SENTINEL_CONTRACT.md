# First production migration: ordinary sentinel

Current production actor/cargo contact configuration and the later shared support/pressure changes are documented in `ACTOR_CARGO_CONTRACT.md`. The checkpoint details below remain historical evidence.

This describes that immutable checkpoint. The later charged-cargo integration
adds shared production source/receiver composition and two narrow controller
contact-admission corrections; see `MISSION_CARGO_CONTRACT.md`. Actor policy
and motor logic from this checkpoint remain unchanged.

## Composition and authority

`demo/components/shared_sentinel.tscn` inherits `simulation/actors/shared_actor.tscn`.
Its root facade inherits the unchanged `combat_pc/player.gd`; it does not override
`physics_tick`, `receive_attack`, gravity, movement, melee, shield or damage.
`IntentDriver` alone schedules the NPC. `SentinelPolicy` observes actual support,
terrain rays, sight and admitted sound, and returns ordinary movement/attack intent
through `NPCInputSource`. No policy writes facing, position, velocity, health,
footing, weapon phases or action clocks. The shared controller decides consequences.

This first checkpoint migrated ordinary `sentinel` entries. The subsequent
listener slice reuses this exact scene with an archetype resource; see
`LISTENER_CONTRACT.md`. Ranged sentry and Warden retain legacy controllers. The mission PC
adds just `BodyShape/IncomingStrikeReceiver`, with counter response permitted; its
existing mission scheduler, 60-point Health, DefeatResponse and NoiseRelay remain.
The stock player scene itself is unchanged.

## Configuration and host contract

Authored resources retain health3 (mission damage override12), speed82, patrol43%,
initial decision delay0.6, windup0.56/active0.14/recovery0.72 seconds, damage1,
43×27 strike at (25.5×facing,-22), impulse(130×facing,-65), and 16×36 body geometry.
The single-step melee resource locks turning and requests no attack travel. Real
controller braking replaces the old AI's immediate velocity assignment. Physics,
hitpause, full incoming recoil and interrupted-action recovery now follow the
shared controller; this is intentionally not a claim of numerical legacy motion
identity. Jump, roll, shield, drop, dive and climb permissions are explicitly off.
There is no new general-purpose ledge-grab permission in this slice.

The facade preserves `configure(player,bus)`, bounds, `kind`, health/damage/speed/
windup/hearing overrides, `enabled`, `ai_enabled`, `dead`, read-only `health`,
`defeated(enemy)`, `attack_resolved(enemy,result)`, `set_blind_mode`, `hear_noise`,
`reset` and `reset_at`. Mission route diagnostics read projections of actual
controller phases; there is no second AI action clock. Disabling decisions sends
neutral intent while already committed actions, braking, gravity and collision
continue. Disabling the actor suspends its scheduler and incoming eligibility.

Explicit contact configuration is body32/mask9, actual incoming hurtbox4, outgoing
mask64, terrain9 and obstruction1. The mission PC retains body2 and gains hurtbox64.
Stock PC mask12 therefore hits the sentinel once; the sentinel does not gain peer
friendly fire or prop launching. `enemies`/`actors` groups remain; inherited
`combat_pc` membership is removed. The counter receiver uses that exact incoming
shape, not an approximate or duplicate collider.

## Receipts, noise and presentation

Incoming melee and counter use the already-reviewed synchronous physical permits.
Controller responses feed Health; a brain never directly debits it. The facade
observes the configured defender's completed `strike_resolved` receipt to expose
`attack_resolved`. The bounded confirmed-counter parry exception described in
`COUNTER_CONTRACT.md` survives source recoil; source `contact_confirmed` and the
remaining sweep remain retired. Reset epochs still reject stale observations.

A semantic-only facade `_commit_noise` override maps committed footstep/strike/land
names and delegates to the original generation/serial/source pipeline. One ordinary
NoiseRelay forwards each event once. Genuine attack-start emits `enemy_windup`;
positive-applied Health receipts emit `enemy_damage`; genuine defeat emits
`enemy_death`. The pre-Health generic `hurt` noise is suppressed so sonar HIT means
an actual debit, not merely a recoil attempt. HIT origin is actor response position
plus (0,-20), as in the legacy scene, not a claimed collision point. Shared strike
noise retains its real committed strike-center origin. No-bus `noise_requested`
continues to expose semantic events. Reset during callbacks cannot emit old-life
HIT/DOWN/warnings into a new generation.

The separate view retains tan wire silhouette, facing blade, actual-phase warning
ring/!, active reach, health bar, damage flash and defeat fade. Sound opens local
reveal; production blackout/sonar uses the ordinary event bus and actual shapes.
No audible mix quality is claimed on the cloud dummy audio device.

## Defeat, reset and compatibility boundaries

The existing DefeatResponse acquires the controller defeat lease. `dead` becomes
observable and `defeated` emits once per life. Generation-checked deferred cleanup
then disables body/hurtbox layers/shapes and scheduling after synchronous terminal
Health/counter receipts finish. An intervening reset invalidates that cleanup.
Reset uses `reset_actor`, restores composition and full Health, clears intention,
reveal and per-life observations, and retains lifetime-monotonic attack serials.
There are no physical corpses in this policy.

Legacy mission props still own their real collision and per-launch deduplication.
The facade's three-argument `take_hit` compatibility shim calls inherited
`receive_attack` only, never health or velocity directly. This path is explicitly
not authenticated shared-cargo contact/epoch parity. `prop.gd` is unchanged and
shared cargo remains a separate opt-in composition.

AI peer hearing is explicit group configuration rather than script equality.
Legacy ordinary sentinel/listener and shared sentinel use `mission_melee_hearing`;
ranged and Warden have separate peer groups matching their previous script
partitions. This policy only filters source evidence; HearingQuery and acoustic
physics are unchanged. Cross-archetype sounds retain their previous eligibility. Facade generation and
binding fences reject callbacks retired by reset, reconfiguration, sensor rebinding
or pause/resume, including ALWAYS-mode hosts through a PAUSABLE child observer.
Current public sensor receipts keep later genuine hearing usable after rebind.

## Route-observer correction and authored ladder limit

The changed physical encounter path exposed an existing route-bot graph error in
Quarantine Intake. Its ladder axis x1540 is exactly the edge of the solid block
(1300,230,240,70), so a 16px body on the floor correctly stops at x1548 and cannot
align to climb through that block. Identical ordinary Up/neutral physics fixtures
in the preserved counter copy and migrated copy identify the same layer1 block and
same collision travel. The successful historical route had never used that ladder.
No sentinel collider retirement regression or new world collision was found.

The test observer now rejects any ladder ascent corridor intersecting authored
solid terrain and admits supported intermediate boarding within the actual ladder
span, exiting only at its actual top. It reads configured PC body geometry and
ordinary room geometry. This is generic path planning, with no sector special
case, world/actor write, weakened success criterion or longer timeout. Full routes
still use actual inputs, combat, health, all objectives and the explicit sight
choice. Rejection/boarding decisions are recorded as auditable navigation events.

The authored visual-access issue remains: the ladder guide/sensor extends to the
floor despite its lowest70px meeting the solid block edge. A human must board from
the reachable block top or take the upper platforms. The planner correction does
not repair that potentially misleading drawing; no layout or controller change
is included. Initial failed route reports and physical baseline comparison remain
preserved alongside the corrected-route evidence.

## Gates and limits

`simulation/tests/sentinel_regression.gd` instantiates the real production scene
and the real mission factory at 60/120 Hz. It covers actual PC↔sentinel contact,
mission damage12, guard, timed/lethal counter, once-per-swing ownership,
Health-confirmed sound, real raw-sword-launched stock cargo, edge braking/support
loss, clear-sight/range negatives, ordinary evasion, explicit hearing peers,
defeat/reset and room-clear/retry. Lifecycle API probes are labelled separately
and never stand in for contact or route gameplay. Existing mission structure and
sound-integration probes now inspect actual architecture and ordinary input.

Both-rate foundations, stock combat/combo/shield/Health, legacy enemy/ranged/Warden,
gym lifecycle, historical aggregate, all four full retained/sacrificed-sight routes,
independent adversarial review and native mission review are recorded in
`VERIFICATION.md` and `evidence/sentinel_acceptance.json`.
Other actor types, cargo-source migration, navigation, physical corpses, acoustic
propagation and full asset extraction are future slices, not implied completion.
