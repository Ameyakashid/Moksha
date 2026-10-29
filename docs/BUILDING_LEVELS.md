# Add or change a MOKSHA room

Open either `.tscn` under `scenes/levels/` in Godot's 2D editor. These are saved
scene instances, not geometry/spawn lists hidden in a runtime generator.

## Room contract

Keep the root and Actors at identity transforms. The root uses
`scripts/world/level.gd` and exposes Level Title, Subtitle, Camera Bounds,
Next Level Path and Sensory Required. Required children:

- `Actors/Player`: instance of player.tscn; its position is the room spawn
- `Actors/Enemies` and `Actors/Props`: placed reusable actors
- `Terrain`: placed solid platform instances
- `GateAnchor`: the proximity point where E/Enter exits, normally just above feet
- `GateVisual`: a separate door-art instance

Optional: `ShrineAnchor` gives one full heal per room; `SacrificeAnchor`,
`SacrificeVisual` and `GateBarrier` form the first sight trade. A sensory room's
upper door requires that trade. The supplied station action is intentionally a
small explicit prototype rule; it is not a general progression system.

To copy a room, duplicate its scene file and change its content. Point another
room's Next Level Path to it. To test independently, duplicate arcology_run.tscn
and change its Starting Level. A blank Next Level Path is a terminal room.

## Place pieces

Drag scene files from FileSystem or duplicate existing instances. A platform root
is the top-left walkable surface; Width/Depth update art and collision in the
editor. Raised thin ledges can use the exposed one-way setting, while floors,
walls and the entry steps remain solid. Spawn resting rigid props at least 6px
above one-way surfaces so the first physics tick approaches from above. Art-only background/decor scenes contain
no gameplay collision. Physical props have a center-origin body and a separate
sprite, while characters use a foot origin.

Separate each decorative asset, interactable, actor and collision surface. Keep
shared resources read-only at runtime; use Make Unique before changing one placed
actor's tuning. No prefabs require the run controller for their basic movement or
combat. Noise emitters look up the optional NoiseBus and include the actor/prop as
the source, enabling the sensory view to reject events from another room.

## What affects sonar

The sensory system samples real enabled CollisionShape2D/CollisionPolygon2D
contours under the current room. Resizing, moving, disabling, deleting or adding a
body changes its contour; it is not a baked screenshot or hand-drawn reveal map.
Only current room actors should call `NoiseBus.emit_noise(origin, kind, loudness,
source)`. Weapon taps, real grounded steps and physical contacts are already wired.

No sound-rendering script chooses damage, movement, enemies or level transitions.
That keeps the sensory effect replaceable as the art direction evolves.

## Polish tuning

`First Ascent Landing Y` on a sensory level controls when the introductory
double-jump instruction is dismissed. It requires a grounded landing; crossing
the height while airborne does not dismiss the hint. Graphics exposes procedural
motion, roll and landing compression independently of collision and movement.
Sonar tuning exposes the short threat-marker lifetimes and length. These marks
are snapshots of an actual guard noise, not permanent enemy tracking.

## Replacing the attack art

On `scenes/actors/player.tscn`, select Graphics and replace or clear Attack Pose.
The profile holds its own SpriteFrames, source foot origin, normalization scale
and one hand anchor per frame. Contact Frame and Recovery Frame map these
drawings to the existing controller's startup, active and recovery windows.
Changing the art never changes physics timing. Clearing the profile restores the
original ready-pose fallback. `tests/attack_showroom.tscn` is a reusable F6 visual
fixture for checking the result before changing a level.
