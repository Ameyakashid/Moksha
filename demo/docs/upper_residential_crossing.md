# Upper Residential Crossing

New stable chapter `upper_residential_crossing` follows Cistern and precedes Relay Works. The 5,200 px neighbourhood connects spillway court, stacked homes, transit roofs, and Works approach. Existing independent favela presentation, static platforms, ladders, cargo, guards and field cache are composed without changing simulation, actor statistics, or NPC policies.

## Choices and recovery

The service route crosses three genuinely solid retaining systems: main surfaces x1100–1260/y190, x2280–2450/y135, and x3640–3790/y120. Fixed approach and return steps connect both sides; the continuous ground alone cannot pass through them. The high route climbs from y245 through190/135/80/25 into a separate roof chain reaching y−85. Six floor-to-roof ladders permit switching and fall recovery. The cache at2940/300 is optional. Nine ordinary guards occupy supported street and roof positions; none must be defeated to leave. There is no relay, delivery, timed wait, or kill gate. The exit is on the final roof at y−85, not at floor level.

## Accepted input-driven evidence

`residential_crossing_route.gd` uses ordinary production button dictionaries and proximity interaction, with a clearly labelled sector-start/pre-clock sight fixture. It neither repositions the player nor modifies AI/health/kills/gates during traversal. At matched60/60 and120/120 engine/physics rates, retained and traded sight:

- Four street runs prove sustained contact with all three exact static retaining surfaces, not merely proximity.
- Four roof runs prove sustained elevated travel and actual supported access steps.
- Four mixed runs cross two retaining systems, visit the lower cache and switch to the roof chain.
- Four roof/fall/return runs physically reach the lower floor, return using the fixed cross-connection, and continue onward.
- All16 transition into Relay Works with3–7 guards alive and zero deaths/retries. Roof cases skip the cache; street/mixed cases collect it. Optimized route times23.32–58.87 active seconds are **not human completion estimates**.

The geometry-only `residential_hold_right_control.gd` removes guards and movable cargo before measured input. Four rate/sight cases hold Right for12seconds without jump/climb/attack, stop at x≈952, and confirm the actual player shape contacts the first solid step. This isolates authored geometry, not full production interactions. Initial guard-only controls instead pushed a crate into the wall; their failed exact-wall-contact assertions are preserved externally, not silently replaced.

An additional isolated threshold-return observer checks actual right-floor→reverse supported crossing→left-floor→forward continuation for all three walls. All four rate/sight cases pass all31 supported waypoints, at least142px actual reverse support on each wall, and onward transition with zero deaths/retries. This is separate from the16-route claim above.

## Reproduction

Run Godot with `--headless --fixed-fps 60 --path . --script res://demo/tests/residential_crossing_route.gd -- --scene=res://demo/tests/residential_crossing_review.tscn --approach=street --hz=60`. Alternatives are `roof` or `mixed`; add `--sacrifice` for the traded-sight fixture, or `--fall-return` to `roof`. Match `--fixed-fps` and `--hz` at120 for120Hz coverage. Reports are `demo/evidence/residential_*.json`.

Independent lifecycle/save/HUD compatibility and native capture are coordinated separately. Route bots know layout and AI and are not unfamiliar-human usability validation. This chapter adds a connected decision space; it does not establish the requested roughly30-minute campaign target.
