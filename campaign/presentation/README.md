# Optional campaign presentation

This is paint, not game logic. The five-level runtime may delete this tree without
changing movement, collision, enemy intent, objectives, sound or saves.

## Integration

Instance `campaign_scenery.tscn` as room child at `(0,0)`; its root z is -5.
Call `configure_sector(sector_dictionary)` (alias `configure`) after building the
room. `level` 1–5 selects the independent theme resource. Hide the room's previous
`backdrop` so two architectures do not compete. New architecture is world z=-8;
precise floor/platform skins world z=-5 overlay the existing -7 base paint but stay
behind actors, relay markers and attack telegraphs. `set_sight_enabled(not blind)`
hides **both** architecture and terrain, including all descendants. Existing
sonar remains authoritative. `update_view(center,size)` is a stable optional API;
static art currently needs no camera update. Never attach the tree to HUD/sonar.

Geometry comes only from `width`, `top`, `gaps`, `platforms`. Floor baseline is300,
matching the physical mission-room contract. Gap skins are excluded. Final atlas
tiles are cropped, not allowed to overrun support ends. Props drawn in the backdrop
are wall-mounted decoration; no decorative freestanding crates imply fake cover.
Moving lifts, shutters, interactables and characters remain runtime-owned.

## Independent modules

- `campaign_theme.gd` + `campaign/assets/themes/*.tres`: replaceable color/motif data.
- `scenery_backdrop.gd`: skyline, bays, conduits, high practical lights, interior
  foundry slots, submerged-window rhythms and server racks. No fake supports.
- `terrain_skin.gd`: exact surface overlay using original atlas texture resources.
- `showroom.tscn`: isolated comparison at gameplay scale. Keys1–5, B, arrows, F12.
  The B check hides scenery only; static showcase actors intentionally remain.

## Reuse and provenance

The original 2026 MOKSHA city plate, urban atlas and aged-operative/guard study
pixels were inspected directly before reuse. This layer references existing
`res://assets/environment` and `res://assets/decor` resources, avoiding duplicate
textures. The existing characters appear only as scale references in the showroom;
no controller or animation replacement occurs. Atlas is detailed original generated
raster, not ripped or decompiled commercial game material. Original generation
provenance and prompts are copied into `campaign/assets/`; hashes are unchanged.
The palette/composition code is original and under the project LICENSE.txt terms.
Third-party fonts retain existing notices. No external stock asset is claimed as
integrated by this layer at this stage.

Five distinct art directions: oil-blue rainline/amber city; warm steel foundry;
petrol-green submerged residences; violet memory racks; pale steel crown skyline.
This restores textured cyberpunk presentation rather than treating the historical
wireframe checkpoint as final art. It is not a claim of AAA illustration polish.

## Verification

`godot --headless --path . --script res://campaign/presentation/tests/presentation_contract.gd`
passes five motifs, exact surfaces, preserved gap, reconfiguration, whole-tree sight
hiding and no physics children. `--headless --path . --quit-after 5
res://campaign/presentation/showroom.tscn` checks scene instantiation.

Native rendered screenshot review is **not completed** here: the local Godot build
advertises headless **dummy-only** rendering, and the executor has no DISPLAY,
Xvfb, GPU device or Vulkan ICD. The separate cloud browser cannot supply a display
to this filesystem. No emulated image is presented as a native game screenshot.
Use the actual showroom on a supported Godot display for visual QA and F12 output.
