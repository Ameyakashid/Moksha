# Placeable Field Cache presentation and contour

`simulation/world/field_cache.tscn` is an independently placeable bottom-center
Node2D. Its optional View draws the original 16 × 18 outline at (-8, -18) and
horizontal line from (-4, -9) to (4, -9), ink `b1c9d1`, width 1. Appearance may
change ink only. A separate CacheContour stays enabled at (0, -9), rectangle
16 × 18, collision layer 0 and mask 0. It has no actor, trigger or interaction
role and never blocks PC, shared NPC or production cargo.

This extraction adds no campaign placement, level, balance rule or interaction.
The unchanged mission owns E with strict distance < 45 in playing state, the
existing station-before-cache priority, single collection, Health reset, saving,
archive text and pause, retry/continue persistence, and the room-sourced
`weapon_tap` at authored cache point minus (0, 10), loudness 0.8.

## Configuration and lifecycle

- `is_found` hides paint and adds `sonar_ignore` to the contour. Returning false
  restores paint and removes that group. The collision shape remains enabled.
- Ordinary root/View hiding, null appearance or removed View affects paint only;
  an unfound contour still participates in sonar. Found state is therefore not a
  synonym for visibility. A removed View cannot own or prevent the found update.
- Changed found state emits `geometry_invalidated` after the group is synchronized.
  A standalone host may connect that signal to its cached sonar refresh method.
  Geometry consumers must also explicitly refresh after removal/reattachment or
  other tree edits. This asset does not discover or own a sonar service. Mission
  retains its original explicit `sonar.refresh_geometry()` after collection.
- Detached state edits are applied to its extant children; reattachment retains
  them. Deletion/removal plus an explicit host refresh leaves no ghost geometry.
- Each scene instance has local appearance and shape resources. Deliberately
  assigning a shared appearance shares paint; duplicating it isolates changes.
  Replacing appearance disconnects the retired redraw subscription.
- `raster_reference` is fixed authored-coordinate arithmetic, independent of
  subsequent placement, parent/root transform and reparenting. Its inverse draw
  translation preserves exact fractional/negative raster phase. Nonfinite values
  are rejected. The ordinary standalone default is zero depth, with no host rule.

## Production composition

Five authored caches now instantiate this scene. Root insertion retains station
→ singular relay → cache → plural relays → onward, preserving ordered actual
body/shape traversal and sonar sampling. Painting uses mission-local relative
levels: backdrop -8; floor/platform -7; signs -6; onward -5; station -4; plural
relays -3; singular relay -2; cache -1; ordinary dynamic children 0. This keeps the
former parent-drawn cache last among foreground assets and before ordinary room
children even for mixed keys and nonzero transformed room depth. No view
reparenting, sonar sorting or copied geometry is used.

## Verification boundary

Focused 60/120 Hz fixtures cover all five authored caches, mixed keys, exact
ordered topology and actual collision-derived sonar, found/restore pulse-track
invalidation, propagation delay/illumination/expiry, lifecycle, serialization,
optional paint and isolated styles. Shared PC/NPC bodies cross the enabled shape
using real collision sweeps with their schedulers stopped; production shared
cargo crosses through the real solver with explicitly gravity-free test tuning.
These passage fixtures make no claim about autonomous NPC decisions or mission
physics progression. Mission collection checks use genuine key dispatch and
labelled position/state setup; the unchanged four full input-driven route gate
remains separate.

The finite native matrix contains 96 full-room pairs, ten cache-focused crops,
eight layered mixed-key overlaps, 24 fractional/transformed anchors, four
nonzero-depth dynamic overlaps and ten configured-ink references: 152 exact
pairs plus 14 reuse checks. Quiet blackout must be black; ordinary/pulse images
must contain content. Archived/runtime-generated oracle scripts compile before
native use. The isolated project contains only the four runtime dependencies,
with no mission or autoload. Native controls separately review H hide, C color,
F found and R reload. None of this claims a native full-campaign playthrough.

Acceptance requires the unchanged 37 preceding aggregate groups plus five new
cache gates, all four full routes, exact frozen-source native evidence and a
complete immutable Relay split-archive union check. Historical reports are
backed up and restored from workspace disk; fresh rerun reports are retained
under `field_cache_gates`. First failed harness attempts remain preserved.
The early fixture mistakes were six instead of five authored caches, eight
instead of twelve fragments at production spacing 6, a still-running shared NPC
scheduler during a direct sweep, and incorrect Health test API access. They do
not establish a production failure and were corrected without changing gameplay.
