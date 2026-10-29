# Field Cache initial native review — NOT ACCEPTED

2026-10-20 09:16–09:20 UTC. Supported CUA/Sky cloud Linux desktop; normal Godot 4.6.3 editor, X11/OpenGL compatibility renderer. No source edits or forced outcomes. Both scenes launched with F6 and stopped with F8. CUA released after live diagnostics, before writer changes.

## Failed native result

Actual completion screen: 152 comparisons, 1 failure. `field_cache_native_pixels.json` has 152 passing exact pixel records and 14 reuse checks, of which 13 pass and one fails:

`fractional reference affects target raster only`

No pixel pair record fails. The failed reuse assertion still prevents native acceptance; its cause was not diagnosed or waived by this review. The report has sources_unchanged=true. All 695 tested source hashes match the freeze after stripping res://; all current sources match both before and after review.

Freeze `field_cache_pre_native_source_freeze.json` SHA-256: `0378b1c541f2df579d0acfad660a323464e532e4dcc7b18c3419fc234b6cb590`.

## Complete diagnostics

All 10 pixel debugger entries inspected together:
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

No parser halt. Standalone live diagnostics contained only the first three environment entries.

## Bounded live observations

`field_cache_review.tscn` displayed four clear separated samples: ordinary, enlarged, rotated, and coral. Header, controls, mission-ownership explanation and status text were readable and unclipped in the 1280×720 game area.

- C recolored only the first cache red; peers stayed unchanged.
- H removed only the first paint; HUD showed visible=false, found=false, sonar_ignore=false, shape_enabled=true.
- A second H restored root visibility, then F removed the first paint through found state. HUD showed visible=true, found=true, sonar_ignore=true, shape_enabled=true. Peers remained unchanged.
- R restored the initial paint, color and status: visible=true, found=false, sonar_ignore=false, shape_enabled=true.
- F8 stopped execution, confirmed by editor output.

These are observed presentation and HUD values, not proof of actual sonar exclusion, solver behavior, mission collection, healing, archive, or save behavior. Successful bounded live controls do not override the failed native reuse check.

## Original captures

field_cache_pixels_complete.jpg; field_cache_pixels_diagnostics.jpg; field_cache_live_initial.jpg; field_cache_live_color.jpg; field_cache_live_hidden.jpg; field_cache_live_found.jpg; field_cache_live_reset.jpg; field_cache_live_diagnostics.jpg; field_cache_stopped.jpg.

All are original Sky screenshot bytes, verified JPEG 1364×1024. No generated or reconstructed images.
