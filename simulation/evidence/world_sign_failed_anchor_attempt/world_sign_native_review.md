# World sign native review — failed extraction gate

Reviewed 2026-10-20 at approximately 05:27–05:30 UTC on the supported cloud Linux desktop using CUA/Sky and Godot 4.6.3. Broad tests were held. No source edits or forced states/outcomes. Both scenes launched using F6 and stopped using F8. CUA was released at approximately 05:30 UTC for correction work.

## Frozen source identity

Manifest `world_sign_pre_native_frozen_sources.json`, SHA-256 `9260a0af5d82071369ce1372cf1d895fb4c5d817ae766ca2f0c2e3ee0633c611`, covers 638 source files. Current files matched before and immediately after review. The native report's 638 tested hashes also match after normalizing its `res://` prefixes.

## Renderer result: NOT ACCEPTED

Fresh native `world_sign_pixels.tscn` completion visibly reported 118 comparisons and seven failures. The primary `world_sign_native_pixels.json` confirms seven failing authored-anchor decomposition comparisons. All twelve reuse checks passed; those passes do not override the transform failures.

Failing labels, differing pixel count, maximum channel error:

- `anchor_decomposition_00`: 365, 164
- `anchor_decomposition_01`: 302, 85
- `anchor_decomposition_02`: 318, 163
- `anchor_decomposition_03`: 294, 149
- `anchor_decomposition_04`: 288, 150
- `anchor_decomposition_06`: 75, 153
- `anchor_decomposition_07`: 316, 157

Each failing comparison is 500×240, reports valid content and frozen clocks, and has unequal legacy/current RGBA hashes. No tolerance was applied or outcome forced. The extraction requires correction and fresh verification.

## Bounded decorative live review

`world_sign_review.tscn` was readable and unclipped at the visible 1280×720 viewport. Native text samples included the original fallback-font SERVICE/HUB and DISPATCH RECOVERY signs, visibly distinct custom-font LEFT/CENTER/RIGHT alignment examples, and repeated LIFT CONTROL signs with differing rotations and colors.

Ordinary C input recolored only the first SERVICE/HUB sign. H hid only that sign. R restored its visibility and original color. Other samples remained visually unchanged through those actions. These are qualitative visible observations, not exact peer-pixel comparisons. No physics was expected or tested in this explicitly decorative fixture.

## Complete diagnostics

Pixel scene: nine entries. Three environment entries: unsupported V-Sync mode change; red audio initialization `ERR_CANT_OPEN` (`status < 0`); all audio drivers failed with dummy-driver fallback. Six script warnings: `owner` shadows Node property; `transform` shadows CanvasLayer property; incompatible ternary values; `kind` shadows variable at line 16; `material` shadows CanvasItem property; `scale` shadows Node2D property.

Live decorative scene: only the same three environment entries. No script warning was listed in its complete visible diagnostic list.

## Actual screenshots

Original unaltered Sky screenshot bytes, all independently verified as JPEG 1364×1024:

- `world_sign_pixels_failed.jpg`
- `world_sign_pixels_diagnostics.jpg`
- `world_sign_live_initial.jpg`
- `world_sign_live_recolor.jpg`
- `world_sign_live_hidden.jpg`
- `world_sign_live_reset.jpg`
- `world_sign_live_diagnostics.jpg`
