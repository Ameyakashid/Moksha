# Placeable floor segment extraction

`simulation/world/floor_segment.tscn` is a center-origin **Node2D placement and
configuration root**, not a physics body. Its `Support` child is the existing
`static_platform.tscn` StaticBody2D, which owns the only RectangleShape2D. Its
separate optional `View` is the reusable `demo/views/floor_view.tscn`. Existing
platform paint is explicitly null. No collision implementation is duplicated.

Every production floor rectangle now instantiates this asset. Rectangles, gaps,
walls, platforms, signs, interactions, HUD and actor mechanics remain unchanged.
The old private floor canvas and repaint callback are removed from the mission.

## Configuration and ownership

- `segment_size` accepts finite positive dimensions and synchronizes support and
  paint. Resize dimensions rather than scaling physical bodies. Floors are solid
  even when thin: one-way behavior is false, margin 1, layer 1/mask 0.
- `physics_material` is optional and forwarded to the actual Support body. Null
  preserves the original default material. Intentionally sharing a material
  shares its changes; duplicate resources when independent material edits matter.
- `appearance` is paint-only: fill, top outline, hatch colors. Defaults are local
  to each scene instance. Null suppresses paint; replacing it disconnects the
  old redraw signal. Explicitly sharing a paint resource shares live changes.
- `hatch_reference_x` is a finite **authored reference**, not the asset's current
  world position. Production uses the original room-local rectangle's left x.
  The original range is preserved exactly: `range(int(x)+10,int(x+width),40)`.
  Godot int truncation (especially negative/fractional values), exclusive end,
  9px stroke width, top+4 to top+15 placement, and narrow-height overflow are
  retained. Moving/rotating/nesting instances never changes the authored phase.
- The optional floor view works without any physical or mission host. Native
  transforms, visibility and modulation work on views. Removing/hiding paint
  does not remove support or sonar. Remove the full asset to remove support.
- Root/Support/View transforms are identity relative to the centered asset.
  Nested physical translation/rotation preserves view/collider alignment; this
  does not certify arbitrary nonuniform physics scaling. Detached view transforms
  are independently covered. Live geometry edits during physics query flushing
  must be deferred, as for ordinary Godot shape updates.
- Exported size, phase, paint and material survive save/reload. Invalid sizes or
  references retain the previous valid configuration. Support owns a unique
  collision shape using the existing static-platform resource lifecycle.

## Production order and sonar

Composition marks floor branches behind their mission parent and inserts them
before platform branches. Backdrop -> ordered floors -> ordered platforms ->
signs/interaction foreground retains the original draw order. Nonphysical wrapper
nodes do not change collision-body/shape traversal. Shapes remain immediate
children of PhysicsBody2D; both sonar collectors use the real collider. No outline,
actor-role branch, support flag, motion or action outcome is fabricated.

## Acceptance matrix

`simulation/tests/floor_segment_regression.gd -- --hz=60` (also 120) checks all
8 archived room topologies, exact ordered sonar, floor rectangles, resource
isolation, runtime configuration, invalid inputs, save/reload, null/removed view,
nested physical transforms and sonar resize/removal/replacement. Real shared
PC raw-input and NPC-intent actors fall onto floors, resist down+jump passage,
walk off open gaps, strike solid undersides and lose support after deletion.
Only initial placement and inputs are assigned; motion is an actual physics result.

`simulation/floor_segment_review.tscn` is a standalone native scene without a
mission host, framed for the project's 640x360 logical viewport. A/D moves,
Space jumps, H hides left floor paint while leaving support, and R reloads.
Upper samples are transformed appearance views; lower supports are physical.

`simulation/floor_segment_pixels.tscn` requires native rendering and compares
108 exact frozen RGBA pairs: 96 complete-room states, two repeated nested-view
arrangements, two deliberate floor/platform/sign overlaps and eight fractional,
negative and narrow hatch-boundary configurations. Six independent-instance
pixel checks exercise paint changes, hiding, resizing, deletion and replacement.
These snapshots are presentation evidence, not gameplay or audible-mix review.
Renderer errors invalidate acceptance even when image counts otherwise pass.
Native diagnostics are a separate required CUA review with saved report/screenshots;
the aggregate runner checks pixel JSON and source identity, not editor log contents.

`simulation/tests/run_floor_segment_acceptance.py` retains all previous 19 gate
groups and adds floor focused checks at both rates, floor showcase boot, and
generic route-input recovery checks at both rates (24 groups total).
It preserves historical reports in a disk-backed backup, retains fresh regression
results separately, requires unchanged frozen source hashes and matches native
proof to those same source bytes. Old archives remain immutable. The completed
acceptance index, not this document, establishes which gates passed.

The immutable comparison archive is `MOKSHA-Placeable-Static-Platforms-2026-10-20.zip`,
SHA-256 `c64b68ed241eb58463c651895cb20a37fc5957b138cb31bf0353cb4435d4fb83`.
The original mission renderer and provenance are retained under this slice's
baseline evidence. Prior native guard/counter and audible-mix limitations remain.

## Route policy finding during preservation

The first full floor aggregate passed 21 of 22 groups but one randomized 120 Hz
sacrificed-sight route hung on the delivered cargo edge. The original failed
trace and aggregate are retained. Two controlled diagnostic seed pairs (205,
617) produced exactly matching baseline/candidate full-route times, launch
spins and latch poses; both pairs passed. A separate real-input authored-obstacle
fixture reproduced the same empty-input ledge dead zone in both compositions.
The bot's existing grounded-waypoint projection could not resolve an airborne
hang; cargo launch spin is randomized in unchanged production physics.

The existing route bot now has a generic input-only recovery: when actually
nongrounded in ledge/hang, stagnant beyond 0.45 seconds, and horizontally inside
the existing 8px waypoint dead zone, request ordinary down for a lower waypoint
or up otherwise. Combat and ladder steering are excluded. The real controller
still decides release/pull, collision and landing. This does not change authored
rooms, actor mechanics, support/goal completion, route timeouts or production
randomness. `floor_segment_route_regression.gd` checks actual catches, lower/upper
waypoints, repeated recovery and noninterference at 60/120 Hz. Isolated baseline
comparison and policy-only guard checks are identified separately in evidence.
The bot change requires fresh source-hash native pixels and the full aggregate;
prior native/live reports are retained with their original hash distinction.

Validation scope distinction: matched-seed full baseline/candidate routes were
run before the helper change. After the helper change, independent focused
actual recovery episodes ran on both compositions, and all four final full
randomized routes ran on the candidate. No post-helper full baseline route
was run; focused equivalence is not presented as full baseline-route proof.
