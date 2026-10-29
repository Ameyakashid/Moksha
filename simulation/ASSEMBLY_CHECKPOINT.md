# MOKSHA — reusable pieces checkpoint

## What to open

- `project.godot`, F5: the existing First Ascent campaign.
- `sandbox/assembly.tscn`, F6: the new small assembly bench. **1** traversal, **2** combat, **3** freight; **R** reloads the selected station.
- Each `sandbox/stations/*.tscn`, F6: that station by itself. Geometry and assets are scene instances placed in the editor, not a monolithic generated level.

## The pieces and their connections

| Piece | Independently reusable boundary |
|---|---|
| Shared actor | `actors/shared_actor.tscn`: one controller/Health/Defeat/contact foundation. Keyboard or AI supplies intent; contact profiles define role configuration. |
| Floors/platforms | `world/floor_segment.tscn`, `world/static_platform.tscn`: independent physical support and configurable presentation. |
| Lift/ladder | `world/moving_lift.tscn`, `world/mission_ladder.tscn`: existing motion/climb rules; the ladder now owns its own sonar rails. Lift audio is optional. |
| Cargo | `world/mission_cargo.tscn`: actual production crate configuration, using ordinary solver movement and shared impact rules. |
| Freight cradle | `world/freight_cradle.tscn`: owns replacement/spawn admission; binds a receiver through an explicit interface. |
| Receiver | `world/freight_receiver.tscn`: decides success from its bound crate's real stable contact and emits `latched`. It does not own a door or mission. |
| Shutter | `world/relay_shutter.tscn`: owns collision/open state. The sandbox connects receiver success to `set_open(true)`. |
| Markers/signs | `world/world_sign.tscn`, `onward_marker.tscn`, `exchange_station.tscn`, `relay_marker.tscn`, `field_cache.tscn`: placeable presentation/contour assets. Mission decisions remain outside. |
| Backdrop | `demo/views/room_backdrop.tscn`: replaceable room presentation, not a second physical level. |
| HUD | `ui/mission_hud.tscn`: receives a copied scalar snapshot. No player, room, input or save authority inside it. Removing it does not stop mission input. |
| Body echo | `ui/body_echo.tscn`: explicit source Visual and enabled flag. Copies the real pose without advancing an actor or revealing enemies. |

Paths in this table are relative to `simulation/` unless stated otherwise.
The production mission uses the same physical scene packages; it still owns placement, progression, checkpoints and decisions. Those are legitimate assembly responsibilities.

## What “Lego” means here

Each listed asset has an independently instantiable scene, a defined configuration/connection boundary, and isolated tests. The three bench scenes show how to connect them. Hiding artwork does not disable physical support or receiving rules. Some bodies draw their own art internally; every decorative line/window is **not** a separate scene. This is not a Godot EditorPlugin and does not claim every historical/archived prototype was refactored.

The shared cargo now wakes when an observed physical support disappears or changes; the solver decides the resulting motion. The original failure and corrected behavior have separate controlled evidence. No position or velocity is assigned to manufacture falling.

Actor-to-actor body blocking remains intentionally disabled by current contact profiles. Actors block terrain/cargo in production, and combat hurtboxes remain separate. The initial showcase clips used a simpler terrain-only actor fixture; they are not evidence that its profile equals the production profile.

## Evidence and limits

Read the final aggregate and native comparison reports supplied with this checkpoint. Focused/headless tests, frozen visual comparisons, actual rendered showcase videos and full-route bot checks establish different things; none substitutes for all the others. Earlier failed fixture attempts remain preserved and are not counted as passes.

The campaign has not been expanded in this checkpoint. The roughly 30-minute target is still unmet. Human pacing, audible sound mix and performance/feel on the user's hardware remain unverified. The videos are real Godot renders with labelled deterministic input or setup, not cinematic animations.
