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

The initial presentation pass had no native display. That historical limitation
was subsequently resolved: native Godot screenshots and bounded manual review are
recorded in `campaign/evidence/native_visual/` and `campaign/docs/VERIFICATION.md`.
Headless contract checks below still establish state/geometry only, not pixels or
human readability. New changes require fresh native review rather than inheriting
those historical screenshots. See `NOV6_READABILITY.md` for the later campaign HUD
and objective-caption pass and its focused verification commands.

Actual campaign integration regression also passes:
`godot --headless --path . --script res://campaign/presentation/tests/runtime_sight_contract.gd`.
It starts the real campaign with saves disabled, checks art ordering/old-backdrop
replacement, performs the actual sight-choice flow, checks immediate hidden
architecture and terrain, reloads while blind, and starts a fresh sighted run.
This verifies runtime state, not rendered pixels or human visibility perception.

## Optional full-color actors (not a controller replacement)

`actor_presentation.gd` is an optional Node adapter. After creating the real player
and enemies, add the adapter and call `bind(player,enemies)`. On scene replacement
free/clear the old adapter. Call `set_sight_enabled(not blind)` at load and sight
changes. `set_debug_wireframe(true)` restores the approved original player paint
and removes all colored underlays; false restores colored presentation. `clear()`
restores the source Visual's prior visibility and removes its own children only.

The existing player `Visual` **keeps its instance, script, event subscriptions,
pose clocks and contact locking**. `operative_skin.gd` reads `get_pose()` every
frame; it never sends motor input, changes transforms, or substitutes poses. It
uses filled coat/limb shapes, copper reinforcements, grey hair/beard and an aged
face silhouette on those exact bones. Inherited `_draw_weapon()` and
`_draw_shield()` are unchanged. `body_echo.source_visual` remains the original
pose source; the new colored view is not used as sightless proprioception.

`security_skin.gd` adds filled armor *below* the original enemy Visual and its
warning arcs, health strips, weapons, locked aim, Warden and captain tells. Its
head/hand/feet formulas match the current sentinel/sentry views. It reads current
shared-controller state (including read-only `ai_state`), never assigns it. The
adapter fully hides these added fills when sight is sacrificed, even while the
original sensory renderer selectively reveals events.

The original generated character sheets were inspected. Their limited12-frame
pose inventory cannot faithfully represent the established connected locomotion,
wall/ladder support, rolls, charge, parry and chained attacks. They therefore remain
reference/showroom assets, not a misleading sprite swap. New wardrobe is original
code-native paint using their navy/copper/grey age cues, not commercial-game art.

`tests/actor_skin_contract.gd` passes743 checks:130 pose/facing/phase samples, exact
snapshot preservation including weapon/shield geometry, actual headless draw
lifecycle without triangulation errors, stable source identity/no extra motor
subscription, sight gating, debug toggles, enemy hand geometry and detach restore.
This is structural/geometry verification, **not native rendered visual approval**.

The campaign host now exposes **F8** to switch colored actors/original wireframe.
The integrated `runtime_sight_contract.gd` additionally passes actual adapter
attachment, debug switch, immediate colored-player/enemy concealment on trade,
blind district rebuild, old-adapter disposal, blind retry and fresh-run restoration.
District rebuild is tested through the host's loader; this is not a claim that the
test played through or validated the district's objective/combat progression.
