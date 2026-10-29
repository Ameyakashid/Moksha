# Placeable static platform extraction

`simulation/world/static_platform.tscn` is a genuine center-origin StaticBody2D
with its own RectangleShape2D and optional `demo/views/platform_view.tscn` child.
It works independently of mission rooms. Every production `data.platforms`
rectangle now instantiates this asset. Floor and wall collision remain unchanged;
lifts, shutters, signs, interaction markers and HUD are outside this slice.
The older textured `scenes/environment/platform.tscn` remains unchanged.

## Configuration and ownership

- `platform_size` controls physical rectangle and view, with finite positive
  dimensions. Configure dimensions rather than scaling physics bodies.
- `one_way_collision` is explicit, independent of paint or dimensions. Production
  composition preserves its old height <=18 rule. Default margin is the original
  1 pixel; `one_way_collision_margin` accepts finite nonnegative values.
- Layer 1/mask 0, default physics material, centered shape, absence of extra
  groups, and ordered collision traversal all match the archived mission.
- Each instance owns a unique shape. Shape edits emit ordinary Resource changes,
  so existing sonar invalidation observes them. No fabricated sonar outlines,
  support flags, actor-role branches, motion or action outcomes are added.
- `appearance` is a Resource with fill, outline, highlight and brace colors.
  Scene defaults are local to each instance. Intentionally sharing a Resource
  shares paint changes; duplicate it for independent configuration. Replacing an
  appearance disconnects the previous redraw subscription. Null hides the paint.
- The optional center-origin view accepts its own `platform_size` and appearance.
  It has no physics or host lookup. Native transforms, visibility and modulation
  work on standalone views. Hiding or removing the view does not remove support
  or sonar; remove the physical asset when collision should disappear.
- Save/reload retains exported configuration. Invalid sizes/margins are rejected,
  retaining the last valid configuration. Shapes update synchronously outside a
  physics callback; callers must defer geometry changes requested during physics
  query flushing, as with ordinary Godot collision-shape changes.

## Production paint ordering

Mission composition alone marks platform branches behind their parent. A private
Node2D canvas invokes six floor-drawing lines still owned by `mission_room.gd`.
Backdrop -> floor -> ordered platforms -> room signs/interaction foreground ->
existing ladder/lift/shutter children therefore remains the authored order. This
private ordering adapter is not a reusable floor asset or an extracted sign/
interaction module. Full floor extraction remains future work.

## Acceptance evidence

`simulation/tests/static_platform_regression.gd -- --hz=60` (also 120) checks all
8 archived room topologies and ordered sonar contours; independent resources;
resize/appearance/null-host behavior; save/reload; nested transforms; sonar cache
resize/removal/replacement; real gravity landing, jump passage/solid underside,
down+jump drop, walk-off and support deletion with the same shared actor scene
and PC raw input versus NPC intent. Initial placement/input is fixture setup;
no motion/support outcome is assigned. Actual physics tick rate is set explicitly.

`simulation/static_platform_review.tscn` is a standalone native scene with real
supports and actors plus independently transformed appearance views. It contains
no mission host. A/D moves, Space jumps, Down+Space drops, R reloads, H hides the
first raised platform's view without changing support. Upper examples show view
transforms, not a promise of arbitrary nonuniform physics scaling.

`simulation/static_platform_pixels.tscn` performs 100 exact native RGBA pairs:
96 archived complete-room states (including hidden, quiet blackout and accepted
sonar pulse), 2 repeated nested-view configurations and 2 deliberately overlapping
floor/platform/sign/interaction arrangements. Six independent view pixel checks
cover edits, hiding, resizing, deletion and replacement. Headless rendering does
not count as this gate. These are frozen presentation snapshots, not gameplay or
an audible-mix review. Renderer diagnostics must be clean, not only image counts.

`simulation/tests/run_static_platform_acceptance.py` runs the full existing
foundation, prior backdrop focused checks, this slice's focused checks, stock,
held, Health/Defeat/shield, historical and four complete route gates. Prior reports
are restored, new copies retained separately, and full frozen source hashes must
match native evidence. Existing native guard/counter limitations remain unchanged.

The immutable comparison archive is
`MOKSHA-Reusable-Room-Backdrop-2026-10-20.zip`, SHA-256
`8bb0bbefcecd635fed7f0f235ab22ba429f9d8d83da210084dc59f57323fa5b8`.
Its unmodified room source is retained with provenance. Only the completed
acceptance index establishes which gates passed; this contract is not a preclaim.
