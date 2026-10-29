# Field Cache corrected native retry

2026-10-20 09:22–09:24 UTC. Supported CUA/Sky cloud Linux desktop, normal Godot 4.6.3 editor, X11/OpenGL compatibility. Fresh F6 launch of `res://simulation/field_cache_pixels.tscn`; F8 stopped execution. No source edits or forced outcomes. CUA released before aggregate tests.

## Fresh result

Actual completion screen: 152 comparisons, zero failures. Fresh `field_cache_native_pixels.json`: all 152 exact pair records pass with zero different pixels and zero maximum channel error; all 14 reuse checks pass; failures empty; sources_unchanged true. All 695 tested hashes match freeze after stripping res://, and all current sources match before and after review.

Freeze `field_cache_pre_native_source_freeze.json` SHA-256: `c4c6fdb44766cec92cacbeb7b2c6264b9d9baf80a06d02622183ded93125b3c9`.

Corrected reuse assertion: `fractional line reference matches direct draw without moving target or peer`. All eight separately recorded facts are true:
- matches_direct_draw_oracle
- peer_raster_unchanged
- peer_root_reference_unchanged
- peer_view_reference_unchanged
- target_raster_unchanged
- target_root_reference_updated
- target_transform_unchanged
- target_view_reference_updated

The failed initial assertion and its evidence are preserved in `field_cache_failed_native_attempt01/`. This result is a fresh corrected-harness run, not a reinterpretation of the earlier failure.

## Complete debugger inspection

All 10 entries visible together and inspected:
1. Driver cannot change VSync mode.
2. Audio output initialization status < 0, ERR_CANT_OPEN (red error).
3. All audio drivers failed; dummy fallback.
4. reference variable shadows RefCounted method.
5. owner parameter shadows Node property.
6. transform variable shadows CanvasLayer property.
7. Ternary values are not mutually compatible.
8. kind parameter shadows current-class variable at line 16.
9. material variable shadows CanvasItem property.
10. scale variable shadows Node2D property.

No parser halt. Pixel success does not imply empty diagnostics or working audio.

## Prior live correspondence

Compared new freeze against retained failed-native tested map. Only `simulation/tests/field_cache_pixel_regression.gd` changed; no entries removed. Production and live fixture are unchanged, so prior observed C/H/F/R isolation, scaled/rotated/coral variants and readable HUD remain applicable. Live was not repeated. HUD sonar_ignore and shape_enabled values remain observed diagnostics rather than proof of actual sonar/solver behavior. No mission collection, healing, archive or save claim is made.

## Distinct original captures

- field_cache_final_native_complete.jpg
- field_cache_final_native_diagnostics.jpg
- field_cache_final_native_stopped.jpg

Original Sky screenshot bytes, verified JPEG 1364×1024. Prior failed report and live captures left intact.
