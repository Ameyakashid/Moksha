# Thermal Foundry: a changed return journey

Original, bounded Level2 layout work based on frozen fe9936a. No changes to the
delivered frozen source. No imported geometry, assets or controller code.

The existing east FEED panel now also releases a middle-height maintenance
shutter. Before FEED, the player can approach along the exposed ground aisle or
take the existing high service-harness branch. Afterwards, a short connector
makes the journey west to the coolant manifold safer and visually different.
The harness remains optional; the floor is still traversable without collecting it.

This uses the previously documented Dead Cells separation of pressure and relief,
and Hollow Knight's meaningful changed-return route principle, not their maps.
The reference sources remain linked in NOV12_OPENING_LAYOUT.md.

## Exact bounded change
- Add a160px one-way connector from(3240,120) to(3400,120).
- Add a24x180 shutter centered at(3340,90), requiring existing `feed`.
- Its bottom is y180: the floor remains open below; existing service roof at
  y-90 passes above its top at0. FEED opens the middle-height route.
- Add short floor/service/return direction signs.

Original platforms, fixed ladders, objectives, prerequisite graphs, guards,
hazards, props, optional rewards, actor physics and saves remain unchanged.
No traversal length or encounter count was added to inflate duration.

## Validation method
`nov12_thermal_layout_contract.gd` protects old geometry and a canonical hash of
other Level2 data. `nov12_thermal_route.gd` owns a bounded normal-title input loop,
using existing route logic. Neutral/retained and Strength/traded menu selections
are real keys. The route walks into the closed shutter, chooses one outbound
height, activates FEED using E, then physically returns through the open connector.
It checks that the exposed route finishes without the optional harness, whereas
the service-branch route actually recovers it. No actor position, health or goal
is assigned to force a result. Receipt destinations must be fresh and external.

Automated route timings are not human playtime. Optional refuge rescue, every
combat strategy and all movement profiles are not implied by a passing route.

Run one case with fresh external output:
`python3 campaign/quality/nov12_thermal_checks.py --case neutral-exposed --output /absolute/new-output`
Repeat for `neutral-service`, `strength-exposed`, `strength-service`.
The latter two genuinely select Strength at the title and trade sight in Exchange.
`nov12_thermal_observer_unit.gd` checks the waypoint-transition navigation schema;
a target-only negative control must fail rather than silently continuing.

Historical development attempts are not acceptance: an early waypoint array
assignment failed at runtime; a second attempt completed physical route assertions
but produced three missing-navigation-field errors. Both were observer faults,
not reasons to alter gameplay. Only a strict engine-error-free rerun counts.

A later Strength/exposed probe legitimately activated FEED but the route planner
kept attempting a short jump beneath the existing east gallery. That timed out
and was not accepted. The follow-up observer uses the existing east ladder via
ordinary movement and Up for this return recovery; no platform or movement rule
was changed to accommodate the bot.
