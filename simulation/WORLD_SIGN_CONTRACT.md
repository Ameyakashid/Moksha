# Independently placeable decorative world sign

`simulation/world/world_sign.tscn` is a single baseline-anchored Node2D. It draws
text without a mission host, physics body, collider, sonar contour, interaction,
HUD or gameplay effect. Production instantiates all 14 existing decorative signs:
11 in Relay Works and 3 in Freight Lock. Other rooms remain sign-free. Gate,
station and relay captions are still their original mission-owned interaction
paint, outside this bounded slice.

## Configuration and ownership

- `text` is passed directly to CanvasItem.draw_string, retaining its single-line
  drawing semantics. This is not a Label, layout engine, wrapping or rich text.
- The root position places the sign; `baseline_offset` is a finite local baseline
  anchor, not a glyph top-left. Standard parent/root transforms, modulation and
  visibility apply. No coordinate is derived from a mission or global position.
- `raster_reference` is a finite authored draw-space origin reference, default
  ZERO. Drawing translates by -reference then submits reference+baseline_offset
  to draw_string, and resets the draw transform. Font rasterization depends on
  local command coordinates: mathematically equal root/offset decompositions are
  not inherently pixel-identical. Preserve the original authored draw-space origin
  reference when exact archived raster phase matters. Production sets reference
  to each original sign position. Mixed offsets use the authored root position,
  so reference+baseline_offset reproduces the original text anchor. Reference
  remains fixed when moving, rotating, scaling or nesting, never follows global
  position and has no host lookup. Changing it may change paint without changing
  the logical baseline. It survives save/reload and is per-instance.
- `appearance` is a local-to-scene SignAppearance resource. Null hides paint.
  Replacement disconnects old redraw signals. Defaults are independent between
  scene instances. Explicitly sharing a resource deliberately shares live edits;
  duplicate it deeply to isolate custom font resources too.
- Defaults exactly match archived decorative rendering: null font selects
  ThemeDB.fallback_font, size 9, color 89b2b6, LEFT alignment, width -1.
- Optional `font` is a Font resource. The sign never mutates it. Font changes
  forward redraw notifications through the appearance. Replacing a font removes
  the old subscription. Explicitly shared fonts remain intentionally shared.
- `font_size` is positive; `width` is -1 or finite nonnegative; alignment uses
  Godot HorizontalAlignment. Alignment is within the draw width, not a new
  center/right positional anchor. Invalid numeric inputs retain valid values.
- Exports survive scene save/reload. Empty text and null appearance are safe.
  Decorative scaling is native CanvasItem scaling, with no physical claim.

## Composition and rendering order

Production roots are positioned at each original authored baseline with local
baseline_offset zero. They retain authored array order, use show_behind_parent,
and are inserted after floor/platform branches. Backdrop -> ordered floors ->
ordered platforms -> ordered signs -> mission interaction foreground remains
unchanged. No geometry is added solely to make signs appear in sonar.

## Acceptance and evidence

`simulation/tests/world_sign_regression.gd` at 60 and 120 Hz checks all eight
room topologies and ordered collision-derived sonar against the sealed floor
renderer, all fourteen positions/strings/defaults, absent physical geometry,
default and explicit resource ownership, custom font subscriptions, nested
anchors, visibility, invalid values, removal/replacement and scene save/reload.

`simulation/world_sign_pixels.tscn` requires native rendering. It compares 134
exact RGBA pairs: 96 complete-room states, two repeated/nested standalone sign
arrangements, two deliberate city/interior platform/sign/sign/marker overlaps,
eight fractional/negative authored-anchor decomposition pairs (including mixed
root placement/local offsets under nested transforms), eight fixed-reference translations and eight root rotation/scale cases, and ten
custom-style references. Default artwork uses the archive-backed sign
loop; custom alignment/font/width configurations compare against a direct
CanvasItem.draw_string reference, not purported archived custom artwork. Fourteen
independent-instance pixel checks cover fixed raster-reference mutation/restoration, text, local baseline, color, font,
alignment/width, resource replacement, null, hide, delete and recreate.

`simulation/world_sign_review.tscn` is a standalone native 640x360 review. It
shows original defaults, custom font/alignment and repeated nested transforms.
H hides the first sample, C recolors it, R reloads. These are review controls,
not world-sign interactions. Native diagnostics and screenshots are required;
headless scene boot is not a native visual review.

`simulation/tests/run_world_sign_acceptance.py` retains every prior 24 gate
group, adds sign 60/120 Hz and standalone boot, backs up historical reports on
workspace disk, keeps new results separately, and restores old reports exactly.
It requires a complete native matrix and identical native/aggregate source hashes.
The completed acceptance index, not this document, establishes passed stages.

## Immutable comparison baseline

The floor checkpoint is split across Project and Verification ZIPs. The Project
contains runnable sources; Verification carries historical evidence. Preservation
must compare their union, recorded in the pair manifest, rather than treating the
lightweight Project ZIP as the entire earlier checkpoint.

- MOKSHA-Placeable-Floors-2026-10-20-Project.zip SHA-256:
  3094a9008aa9ebfa993197152b5d85ec8ae51ba296ef22fea2f25fce5cb34c8e
- MOKSHA-Placeable-Floors-2026-10-20-Verification.zip SHA-256:
  b8c1e0a07286416cd628c2e204bffd7ee5d249a695c6fe8e551a9cb4ba91164b
- Archived mission renderer SHA-256:
  bfc6abed4094ee4ea17f22824529d4585bbe80bc1dfef9d2af722a664e10012f

Historical failed route attempts and diagnostic comparisons remain preserved.
Prior native guard/counter and audible-mix limitations remain unchanged.

The first 118-pair native attempt found seven fractional-anchor decomposition
failures. It is explicitly superseded, not accepted or erased; its report, images,
source snapshots and hash manifest remain in world_sign_failed_anchor_attempt.
The explicit fixed raster-reference design addresses that observed renderer
behavior without tolerances, deleted cases or a room-origin placement workaround.
