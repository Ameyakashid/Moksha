# Level 2 — Exchange / Foundry

Six independently checkpointed districts; design target **15–20 minutes, not validated playtime**. The approved actor controller, enemy profiles and original district sources are unchanged. Sector dictionaries separate world assembly from objective behavior and rendering. Original Exchange and Freight dictionaries are deep copies, never modified in place.

## Authored route and purpose

1. **Exchange** preserves the actual optional sight trade, two circuits, stairs/lift and return bridge. A civic access permit on the first gallery must be fitted at the exit. Sight sacrifice is not required for access. Waypoints: station `(430,300)` → permit `(1050,190)` → pressure `(1390,300)` → calibration `(1960,-40)` → permit reader `(2410,175)` → exit. Original relay topology and cargo-free passages are preserved.
2. **Capacitor Mill** turns a salvage visit into a maintenance rescue: ground the live bus (switch **2**), recover a coil above the floor, install it on the high control deck, then release the crew. A floor arc has a permanent overhead bypass. Physical door at x2450 opens with bus installation; final door needs crew rescue. Optional accident ledger sits on a high separate return pocket, rewarding vitality. Route: ground switch `(620,300)` → ladder1260 → coil `(1320,130)` → ladders1670/2140 → bus `(2260,10)` → crew `(2850,300)` → exit.
3. **Freight Transfer** retains the original real cargo cradle, transfer deck, receiver and freight shutter. Recover the civilian docket on the acquisition roof before authorizing passage on the far side. Actual cargo admission remains required; E is not substituted for its physics. Route: ladder400 → docket `(790,100)` → cradle `(1250,240)` → receiver `(2110,270)` → authorization `(2660,300)`. Use the original freight observer for cargo manipulation, not a waypoint teleport.
4. **Stamping Galleries** repurposes an industrial system instead of imposing a kill gate. Recover the seal, route press **1**, stamp papers, release transport crew. The press/certification doors have real blockers. Ground arcs contrast with two elevated gallery approaches. Optional cargo balance `(3600,300)` has a nearby spare crate and is never a progression dependency; undelivered notices above the central gallery are another optional discovery. Route: ladder1340 → seal `(1440,100)` → ladder1940 → press `(2080,10)` → certification `(3130,190)` → release `(3890,100)`.
5. **Thermal Foundry** has a genuine return loop: ceramic coupling on a high western shelf, return switch **2** centrally, feed switch **1** to the east, then return to the middle manifold. Its final pressure door is beyond the eastern switch, so it cannot trap the prerequisite. The route back can use the fixed galleries or ground recovery lane. No hazards are claimed to disappear when the coolant objective finishes. Route: ladder1330 → coupling `(1330,-70)` → return `(2040,60)` → feed `(3650,180)` → manifold `(3140,120)` → watch refuge `(4250,300)`. Insulated service harness on the eastern upper pocket is optional agility.
6. **Union Dispatch** closes the evacuation arc: recover the civilian manifest, tune public channel **2**, transmit it from the other gallery, release the pod, hand control to the crew. The transmission and final handoff operate physical locks. Route: upper manifest `(1550,-80)` → channel `(2110,40)` → broadcast `(2710,110)` → pod `(3300,180)` → handoff `(3740,300)`. Optional upper courier locker rewards agility.

## Recovery and layout rules

- Newly authored galleries have fixed ladders from the continuous ground plane; every hazard has an elevated, non-timed bypass. Dropping does not require restarting or transporting cargo uphill.
- Solid staging steps are over18px thick, while galleries are18px one-way supports. Enemy roles and existing stats are untouched; guards may survive district departure.
- Doors follow center-position semantics, matching existing shutter conventions. Objectives are on actual support surfaces, and mandatory keys are reachable before their door.
- Optional plate cannot softlock the main path when a crate breaks. No optional reward is a prerequisite for a mandatory objective.
- Environmental text establishes workers, residents and maintenance infrastructure, **not** a canon choice between the unresolved time-loop and immortality stories.

## Verification performed

Godot4.6.3 `--check-only` passes. A live GDScript data check instantiated all six dictionaries, confirmed all27 objective positions lie on authored supports/ground, local prerequisite references resolve, and objective IDs are unique. This is structural validation, **not** input-driven traversal, combat balance, sonar usability, rescue runtime verification, or human duration evidence. `route` arrays are supported waypoint hints, not autopilot acceptance. Further live testing must use ordinary inputs with both sight choices and inspect objective-door collisions, cargo delivery and return paths.

## Mechanics revision after first input routes

The final constructor intentionally overrides three rescue goals to **optional reward branches**, with the final physical lock depending on the completed machine rather than requiring another E stop: Mill `crew`→bus lock, Stamping `release`→certify lock, Foundry `evac`→coolant lock. Each rescue now rewards vitality. Earlier district descriptions describe their placement, not a mandatory progression chain.

Foundry `return` is now a **physical breaker** (welded coolant restraint), not a route switch. Actual J contact must break it; E cannot satisfy it. The far feed still uses route target1. Thus the closed coolant circuit combines salvage, weapon/physics contact, routing and a real return journey. The original player combat rules remain authoritative. This revision requires fresh input tests; pre-revision successful routes are not proof of breaker behavior.

### Reproduced dispatch correction
The original handoff at(3670,300) lay inside the final solid step(3540–3720, top245), so the character could not approach within its interaction radius. A real input run timed out after completing all earlier dispatch objectives. Moved only that terminal and its route hint to exposed ground at(3740,300), between the step and lock. No collision, character, objective range or completion logic was weakened. Retesting is required.

## District captain

Union Dispatch adds one **Keeper** at(3320,300), on the open floor below the dispatch gallery, separate from the pod and final terminal. Only the captain's survival holds the exit seal; ordinary guards need not all die. The encounter uses the shared actor/controller and actual damaging thrusts, with retreat/commitment/recovery behavior rather than another Warden clone. Face its committed thrust and parry or evade, then punish its recovery. Fixed ladders and the overhead gallery remain retreat routes. Fresh input testing is required after this addition; pre-captain dispatch reports are historical.
