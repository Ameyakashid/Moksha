# Run the shared simulation checkpoint

1. Extract the ZIP and import `MOKSHA/project.godot` in Godot 4.6.3.
2. Press **F5** for the default First Ascent mission.
3. For reusable testing stages, open `simulation/gym.tscn` and press **F6**. Each stage shows its controls; R resets and Escape returns to the selector.
4. The common boundary demonstration is separately runnable at `simulation/boundary_review.tscn`. It is a clearly labelled review fixture, not campaign traversal.

5. The actual reusable backdrop showcase is `simulation/room_backdrop_review.tscn` (F6). Space freezes rain, H hides the first instance, and R resets clocks. `simulation/room_backdrop_pixels.tscn` runs native exact-image comparisons against the archived room renderer.

6. Open `simulation/static_platform_review.tscn` (F6) for the placeable physical support and optional view showcase. A/D moves, Space jumps, S+Space drops, R resets, and H hides/restores the first raised platform view without removing support. Upper examples are transformed appearance-only views. `simulation/static_platform_pixels.tscn` runs the native image matrix. Down is also configured for the down action, but its exact Down+Space native chord was not verified.

Read `simulation/MODULE_MAP.md` for the actual production architecture and remaining limits, `simulation/VERIFICATION.md` for evidence, and `simulation/evidence/floor_segment_acceptance.json` for the latest floor-segment acceptance index. The sealed boundary evidence remains in `simulation/evidence/boundary_acceptance.json`.

All four production NPC archetypes and the player share the actor controller and applicable contact/Health rules, with explicit capabilities. Cargo uses Godot rigid physics with authored impact/pressure rules. Sonar is a configured visualization of shared noise, not physical acoustic simulation. Background/skyline/windows/pipes/rain are now one reusable production backdrop. Every authored static platform now composes a reusable physical support and optional paint-only view. Every authored floor rectangle now composes the static support with an independent configurable floor view. World signs and interaction views now have independent scenes, and the HUD/body echo use explicit presentation inputs. `sandbox/assembly.tscn` (F6) is the current three-station assembly bench; see `simulation/ASSEMBLY_CHECKPOINT.md`. Native audio quality, precise timed counters and general game feel have not been certified.

This is a new tested checkpoint. The previously delivered v28 archive remains unchanged.

The floor segment checkpoint adds `simulation/floor_segment_review.tscn` (F6):
A/D move, Space jump, H hide/show left floor paint, R reset. The floor remains
solid when its paint is hidden. `simulation/floor_segment_pixels.tscn` runs the
native archived-renderer comparison. See `simulation/FLOOR_SEGMENT_CONTRACT.md`
and the final floor acceptance index for verified scope.

## Current content increment: Intake route choice

Open `demo/tests/intake_review.tscn` and press F6 for the same production Intake area with saves disabled. Choose ground combat or upper maintenance, activate the shared relay with E, then cross the opened physical shutter toward the upper exit. The floor beneath the shutter stays open for missed-jump recovery; return left to the ladder. Surviving enemies no longer keep the onward door sealed. F5 still begins the full campaign. See `demo/docs/INTAKE_CHOICE_REVISION.md`.
