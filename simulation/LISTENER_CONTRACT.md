# Production listener: configuration of the existing shared melee actor

This describes that immutable checkpoint. The later charged-cargo integration
adds shared production source/receiver composition and two narrow controller
contact-admission corrections; see `MISSION_CARGO_CONTRACT.md`. Actor policy
and motor logic from this checkpoint remain unchanged.

## One composition, authored differences

All thirteen authored listener placements now instantiate the same
`demo/components/shared_sentinel.tscn` used by ordinary sentinels. The mission
factory assigns `demo/resources/listener_archetype.tres` before the actor enters
the tree. `melee_archetype.gd` is data only. The original scene, facade, intention
policy, view, shared controller, IntentDriver, Health, DefeatResponse, incoming
melee/counter receivers and committed-noise relay are reused. No listener motor,
attack clock, damage store, hearing subscriber or facade is added.

The optional archetype profile defaults to the existing sentinel values. Each
actor privately duplicates it, just as the shared driver already duplicates the
movement/combat/shield resources and the facade duplicates melee/hearing/terrain
resources. Listener data supplies capacity2, speed112, windup0.46, recovery0.68,
strict horizontal sight distance<86, hearing memory3.2, lavender `c6b5e9` and the
ear marker. Sentinel defaults remain capacity3/speed82/windup0.56/recovery0.72,
no extra sight cap, memory1.8 and tan. Both retain the same active0.14, strike
geometry, body geometry, default damage1 and capability/contact profiles.

Existing positive `max_health`, `movement_speed`, `windup_override` and
`attack_damage_override` take precedence after profile application. The mission
still supplies damage12 for both. `kind` remains the mission diagnostic identity;
it does not silently choose physical rules. A standalone listener must explicitly
assign the listener profile as the real factory does. Tuning is applied during
ready; reset restores that actor's composed Health/controller life rather than
re-reading or mutating the shared source resource.

## Intent and senses

Sight still requires a live same-world target, vertical difference<58, the
existing inclusive `detection_range`, and a clear real terrain ray. A positive
profile sight cap is an additional exclusive horizontal bound. Thus exactly86
is not visible to a listener, and a lower custom detection range still wins.
Sight retains priority over remembered noise. Hearing admits the real origin
through the unchanged HearingQuery/Sensor; policy remembers it for the configured
duration and requests ordinary movement. Controller support, braking, gravity
and collision decide whether that request succeeds.

The explicit `mission_melee_hearing` peer group remains shared by ordinary
sentinels/listeners, including legacy fixtures. Ranged and Warden peer partitions
remain separate. This preserves the earlier authored source filtering and is
not a new faction system. Existing generation/binding/pause/sensor-rebinding
fences apply unchanged to listeners.

Production hearing retains range340, foot-origin ear and attenuation disabled.
The existing optional profile can reduce range through one real terrain ray;
tests exercise that configuration with an actual wall and its removal. This is
not acoustic propagation, diffraction, reflection, travel time or material
absorption. Boundary bus probes explicitly test event admission. A separate
gravity-driven crate contact proves real sound production, unchanged source
identity and listener investigation without assigning an AI outcome.

## Physical contact, sound and lifecycle

Body32/mask9, incoming hurtbox4, outgoing target64 and obstruction1 are unchanged.
The mission PC receives the same existing bridge. A listener can hit the PC
through physical overlap but cannot newly damage an overlapping melee peer.
Guard, directional rear bypass, roll escape, timed counter, lethal counter,
one-use damage, Health-confirmed HIT/DOWN and reset use the already accepted
shared contracts. External strike recoil can push a listener beyond an edge;
AI observations never clamp the resulting velocity or invent support.

The view reads profile tint/ear styling and actual controller phase/Health.
Warning rings, active reach, damage flash, blind reveal and defeat fade remain
the same observers. Semantic committed sounds remain unchanged. A listener's
lower capacity makes the same three-point confirmed counter lethal in its
default life; no listener-only damage or counter exception is introduced.

Stock-prop contact still uses the explicitly documented legacy `take_hit`
compatibility boundary; cargo-source authentication is not migrated here.
The inherited controller/DefeatResponse owns death, and the facade retires
collision/scheduling after the synchronous terminal receipt. No physical corpse
capability is added. Ranged/Warden controllers, world layout, mission objectives,
route-planner behavior and all other physical sources are unchanged.

## Verification boundary

`listener_regression.gd` extends the existing production regression harness, so
the same actual contact/counter/lifecycle cases run through listener configuration
without copying a second suite implementation. Listener-specific cases add
profile isolation/override precedence, strict sight boundaries, real wall sight,
sight/noise priority, memory expiry, hearing range and optional attenuation,
real falling-crate sound, overlapping peer non-damage, real strike-induced fall,
all thirteen factory placements and actual mission listener HIT/DOWN accounting.
Direct lifecycle/accounting and bus-admission probes are explicitly labelled;
they do not stand in for real contact or full gameplay routes.

Run `python3 simulation/tests/run_listener_acceptance.py` for both-rate foundation,
stock compatibility, historical aggregate and all four real-input mission routes.
The runner restores historical non-simulation reports and verifies source
stability. Native observations and independent review are separate gates and
must be reported with their actual limits in `VERIFICATION.md`.

The sentinel checkpoint remains immutable. Its documented Quarantine Intake
floor-level ladder obstruction and generic test-planner correction remain as
before; this configuration migration does not repair the misleading lowest70px
of ladder drawing or change navigation/geometry.
