# Favela decorative asset kit

Optional, presentation-only Brazilian hillside / techno-cyberpunk dressing. Stacked rectangular homes, roof parapets, balcony rails, air-conditioning units, water tanks / antennae, drooping cables and sparse restrained neon retain the game's wireframe vocabulary. There is no raster artwork, collision, sonar contour, noise, navigation, trigger, actor, health or progression logic here.

## Generic assembly interface

Instantiate `res://demo/views/favela_backdrop.tscn` wherever the existing backdrop is composed. It implements the same small presentation seam:

- `profile`: existing `room_backdrop_profile.gd` resource (`room_bounds`, `theme`, `visual_seed`). Bounds are local coordinates; bottom edge corresponds to the level's floor baseline. `theme` remains accepted but this explicitly selected scene always paints its favela treatment.
- `automatic_animation`: optional internal clock flag; default false.
- `set_animation_time(seconds)`: accepts/stores a finite absolute time. Artwork is deliberately static, so gameplay clocks cause no whole-map redraw.
- `animation_time`: last accepted absolute time (or internal clock when enabled).
- `style`: local `favela_profile.gd` resource containing `block_spacing`, `neon_amount`, sky and `favela_appearance.gd` paint. Assigning shared resources intentionally shares style; duplicate a resource for independent edits. Scene defaults are local to each scene instance.

The parent owns the optional `backdrop_scene` selection in room assembly. Nothing in these files selects itself, changes the old backdrop scene/profile or changes a campaign level. Root `z_index` is zero, `show_behind_parent` true; a host can retain its existing -8 backdrop layer.

Bounds/seed/style edits rebuild only this decorative assembly. Rebuild is deferred and coalesced. Hiding, removing or reparenting the root has no physical effect. Config changes made while detached apply after reentry. Invalid bounds or a null style/profile safely remove artwork; a null palette leaves sky only. Drawing intentionally overscans bounds slightly at edges/roofs, as the old backdrop does.

## Separate placeable pieces

| Scene | Local origin | Configuration |
|---|---|---|
| `favela_building.tscn` | bottom-left | `dimensions`, deterministic integer `variant`, `appearance`, `neon_amount` |
| `favela_cable.tscn` | first cable endpoint | `cable_end` relative endpoint, `cable_sag`, `variant`, `appearance` |
| `favela_rooftop.tscn` | roof anchor/bottom-center | `dimensions`, `variant` (tank or antenna), `appearance`, `neon_amount` |

Each is a Node2D with its own local default appearance and normal position/rotation/scale/visibility. The shared script draws only its selected visual kind. There is no connection to a mission or required autoload. A null appearance hides the piece. Building/roof dimensions below 16 or nonfinite values draw nothing; visual dimensions are capped at 600. Cables use a bounded 25-point curve.

## Large exterior bounds

The assembly composes three muted depth bands. Each band builds deterministic individually replaceable building/cable/roof nodes, using no global random state. Width 6,200 with default spacing produces roughly 280 pieces. The count is capped at 256 columns per band; for environments wider than approximately 29,000 units, use multiple translated backdrop chunks or wider spacing rather than expecting one unlimited scene. This is decorative chunking, not collision or streaming authority.

## Verification and preview

Run `res://simulation/tests/favela_regression.gd` headlessly for standalone no-NoiseBus, instance ownership, deterministic rebuild, transforms, detached edits, invalid config and real unrelated collision-sweep invariance. It is not a gameplay/full-route test or performance guarantee.

Run `res://demo/views/favela_review.tscn` for a native visual overview. Its 1,280 × 680 sample is scaled into the existing 640 × 360 viewport; it is a presentation fixture, not a gameplay route. Native screenshots and level integration are separate acceptance work. No smooth-frame-rate or human-playtime claim follows from these tests.
