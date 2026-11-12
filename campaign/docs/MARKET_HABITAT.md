# Inundated Market habitat slice

## Reference inspected before implementation (12 November 2026)

- Sebastien Bénard, [Dead Cells development diary](https://www.gamedeveloper.com/design/building-the-level-design-of-a-procedurally-generated-metroidvania-a-hybrid-approach-), 29 March 2017: purpose-specific rooms and biome identity. Applied here as a visually distinct market, not imported procedural generation or room geometry.
- [Team Cherry interview](https://www.pcgamer.com/how-to-design-a-great-metroidvania-map/), original 2017 interview resurfaced in 2025: coherent world locations, unique sights/characters and developing blockouts into places. Applied here as shuttered trade, a raised awning and a refuge frontage that explain existing objectives. The article does not prescribe our landmark algorithm or architecture.

Both pages were reopened and their relevant text inspected. These are design references, not recovered commercial source. No third-party art, map or code is copied. Current evidence: the retained-sight c977 native Market frames show generic waterworks and cargo beneath prose about stalls, awnings and families; this is a visual-fiction gap, not proof of a balance defect.

## Ownership and mapping

`CampaignScenery` composes the optional `MarketHabitat` under the existing waterworks backdrop only for `l3_inundated_market`. It uses the established explicit configure/view and inherited sight/lifetime boundary of `ArcologyAtmosphere`, not a new global scenery framework. The existing Cistern plate remains unchanged.

Three world-space clusters have fixed, bounded authored bounds: shuttered entrance stalls; fabric, rear shop and supports beneath the existing key platform; and a recessed family gallery over the existing refuge platform. Residents are decorative silhouettes behind a railing, not live actors or new rescue targets. They do not change on objective completion. Muted cyan/magenta, flood stains and bundled possessions distinguish habitation without introducing bright false traversal edges. All drawing stays below terrain and actors, is culled by the view rectangle and disappears with sight loss. No simulation input, RNG, collision, objective, enemy, save or audio ownership is introduced.

The upper awning cloth is below the real platform edge, not a new ledge. Existing ladder positions and every catalog byte remain authoritative. This slice must be visually reviewed in motion, including blind traversal, before acceptance; a static contract alone does not establish readability or player discovery.

## Material-cohesion revision

The first native 9d04657 images verified the landmarks but exposed flat, pasted-on window/wall fills and regular bunting against the richer waterworks painting. The isolated polish child retains that evidence and replaces those broad fills with one original generated four-material atlas: wet metal shutters, recessed glazing, folded canvas and stained wall. Cloth is mapped onto the existing irregular silhouettes instead of repeated colored stripes. All three cluster bounds, resident count, glyph/interaction ownership and gameplay data remain unchanged. The existing project metal kit was inspected; it lacks suitable glazing/fabric, so no interactive locker/crate art was repurposed as misleading decoration. Native appearance of this child still requires a new review; previous 9d frames are not evidence for the polish.
