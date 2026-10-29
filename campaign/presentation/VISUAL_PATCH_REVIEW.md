# Native-frame follow-up: modular object and interior paint

This patch was developed in a separate staging project after inspecting actual
native Godot frames, not by treating a schematic/preview as a screenshot.
The original simulation and actor pose controllers are unchanged.

## Observations and scope

- Before: detailed city/platform art competed with white-X cargo and hairline
  blueprint ladders. After: the existing original cargo sprite is visible and
  ladders have restrained steel/copper material at the same exact rail/rung
  coordinates. `l1-jump.png` / `after-l1-jump.png` provide before/after evidence.
- Actual `after-blind-idle.png` shows no city/cargo/ladder material leak after
  the sight trade; permitted sound contours and original body echo remain.
- Interior details had been anchored to a ceiling above the ground camera;
  only a repeated wall appliance grid showed. The staged correction uses sparse
  large bays and floor-relative260px vertical bands, with furnace/pipe, cistern
  window/tank, and server-rack motifs. Both ground and upper-route frames require
  review before accepting this part.
- Security paint remains beneath the untouched original view. Brighter layered
  vest/shoulder/leg fills strengthen the silhouette. Original attack outlines,
  warning arcs, health feedback, captain chevrons and Warden markers remain.
  Body outlines are intentionally not independently dimmed because the old view
  does not safely expose a separate body/telegraph paint toggle.
- Exchange terminal uses the original cabinet texture inside its existing32x42
  contour and preserves the exact label, appearance font and interaction host.

## Adapter API

Add `object_presentation.gd` as a room-owned Node and call `bind(room)` after room
construction. Sync `set_sight_enabled(not blind)` and
`set_debug_wireframe(debug_wireframe)` alongside actor presentation. Dynamic
replacement cargo is registered automatically after its own readiness. Do not
attach this adapter to sonar/HUD layers. `clear()` restores original visible
settings; freeing the room frees the adapter and all its paint descendants.

Cargo uses its original Sprite and transform: charge tint, rotation, root death
visibility and physics continue to belong to the original physical cargo. Only
root `self_modulate` suppresses its debug drawing, not child modulation or
collision. Ladders preserve SensorShape, SonarRails, height/width and rung phase.
StationContour stays exactly the original shape/resource; only View is replaced.

## Structural acceptance

`tests/object_skin_contract.gd`:19 checks pass in isolated staging: exact collider
resources and alignment, climb/rung coordinates, original charge tint, replacement
cargo lifecycle, station bounds, sight concealment, F8 and complete detach restore.
Existing five-theme scenery contracts and743 actor pose/render-data/draw-callback
checks remain green. These checks do not substitute for native visual readability.

No production gameplay file is edited by this patch directory. Host integration,
final native capture review, refreeze and export remain separate release steps.
