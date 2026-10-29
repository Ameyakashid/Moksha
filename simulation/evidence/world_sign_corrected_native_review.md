# Corrected world sign native verification

Fresh review on 2026-10-20, approximately 05:32–05:35 UTC, using supported cloud CUA/Sky and Godot 4.6.3. Both scenes launched with F6 and stopped with F8. No source edits or forced states/outcomes. Broad tests were held; CUA was released after stopping the live fixture.

## Source identity and exact renderer results

Manifest `world_sign_pre_native_frozen_sources.json` SHA-256: `add39628134052fb2f6e264bcb7e245d14943782f29d492910a17fb54d95435e`.

All 638 current source hashes independently matched before and after review. The fresh `world_sign_native_pixels.json` contains 638 tested hashes matching the manifest after `res://` prefix normalization, and reports `sources_unchanged: true`.

The actual native completion screen showed **134 comparisons, zero failures**. Independent primary-report reading confirmed all 134 records passed with zero differing pixels and zero maximum channel error, all 14 reuse checks passed, and failures was empty.

This includes every original `anchor_decomposition_00` through `_07` case, plus `anchor_moved_00` through `_07` and `anchor_root_transform_00` through `_07`. Thus the previously failing anchor cases were freshly tested under the corrected draw path; acceptance is not inferred from canonical room pairs or prior reuse passes. Earlier red evidence remains separate.

## Fresh decorative live observations

`world_sign_review.tscn` was briefly rerun under the changed drawing path. At the visible 1280×720 viewport, all labels and samples were readable and unclipped: fallback-font SERVICE/HUB and DISPATCH RECOVERY, custom-font LEFT/CENTER/RIGHT alignment, and three transformed LIFT CONTROL samples.

Ordinary C input recolored only the first SERVICE/HUB sign; H hid only it; R restored visibility and original color. Other samples remained visually unchanged. This is qualitative native observation, distinct from the exact pixel/reuse checks. The fixture is decorative-only, so no physical behavior was expected or tested.

## Complete diagnostics

Pixel scene contained nine entries:

1. V-Sync mode change unsupported by graphics driver.
2. Red audio `init_output_device` error, `status < 0`, returning `ERR_CANT_OPEN`.
3. All audio drivers failed; dummy-driver fallback.
4. `owner` parameter shadows Node property.
5. `transform` variable shadows CanvasLayer property.
6. Ternary operator values not mutually compatible.
7. `kind` parameter shadows a variable at line 16.
8. `material` variable shadows CanvasItem property.
9. `scale` variable shadows Node2D property.

Live scene contained only the three environment entries above, with no script warnings listed. Both complete lists were visually inspected. Passing pixel checks do not imply warning-free execution.

## Original actual screenshot evidence

All seven files are unaltered Sky screenshot bytes, independently verified as JPEG 1364×1024:

- `world_sign_corrected_pixels_complete.jpg`
- `world_sign_corrected_pixels_diagnostics.jpg`
- `world_sign_corrected_live_initial.jpg`
- `world_sign_corrected_live_recolor.jpg`
- `world_sign_corrected_live_hidden.jpg`
- `world_sign_corrected_live_reset.jpg`
- `world_sign_corrected_live_diagnostics.jpg`
