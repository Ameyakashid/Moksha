# Warden two-loop arena candidate

This is a terrain-only revision, not a new boss mechanic. Width1,700, all three enemy kinds/spawn positions, enemy/PC stats, props and all-three-defeated exit requirement are unchanged. The original platforms remain. Two suspended full-solid baffles and two thin upper connectors create alternative approach/re-entry routes.

## Ground and upper routes

- Left baffle: Rect2(850,120,28,130), bottom250. Western crossover: Rect2(890,135,150,18).
- Right baffle: Rect2(1280,150,28,100), bottom250. Right shelf: Rect2(1250,190,130,18). This shelf is interrupted by the baffle: crossing requires going over its top, not walking through it.
- The continuous ground remains passable beneath both baffles. Warden intent has no jumping/climbing requests; no required survivor is marooned on an inaccessible island.
- The left loop lets the player remove the high sentry and cross above the living Warden. The right baffle protects the far-right flank from the lower sentry; it does NOT shelter the central floor from that gun.
- Alternatively, remain on the floor and fight the Warden before clearing the sentries. All three must still be defeated. No all-kills rule is added to other sectors.

## Verification boundary

`warden_geometry_probe.gd` uses labelled direct setup and real world body/ray queries. It verifies40px-tall terrain-only clearance below both baffles in both directions, high-lane physical obstruction, full-solid shapes and unembedded roster spawns. It excludes movable cargo from the clearance query; it does not claim live gameplay or projectile flight.

Independent actual emitter-authorized outbound/parried projectile checks are recorded by the physics stream under `campaign_warden_rules`. A dynamically restored baffle used to intercept an already reflected shot is an explicitly labelled fixture, not a claimed natural static-cover tactic.

`warden_order_route_bot.gd` submits raw PC controls against live actors. Defeat order is observed from real signals/Health receipts, never assigned. Sentries-first additionally traverses the western crossover while Warden survives and the far-right loop before defeating its sentry. Warden-first proves the opposite actual target order; its final right-loop visit is traversal coverage, not a claim it used that flank during combat. Reports require actual onward transition into the ending sector.

`warden_loop_recovery_bot.gd` performs actual falls from both loops after real combat, then climbs/jumps back to each and exits. `warden_displaced_route_bot.gd` explicitly starts PC and the original left sentry near its shelf edge before active play; a genuine player strike knocks the living one-health sentry to the floor, where it is pursued and defeated. No measured-play position, impulse, health or AI outcome writes occur.

Isolated traded-sight runs explicitly apply sight configuration before the active clock; retained runs do not trade. They are NOT evidence of choosing the Exchange offer. Full campaign integration must exercise the actual choice separately. The native clips must carry this fixture label.

## Scope and duration

No additional enemy waves, increased HP, new AI navigation, forced waiting, extra sense mechanics or shared-controller changes. Optimized simulated timing is diagnostic, not novice/human duration. This arena revision does not establish the requested30-minute campaign. Native presentation and complete campaign regression are separate gates owned by integration.
