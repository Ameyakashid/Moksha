# Onward marker native review

Reviewed 2026-10-20, approximately 06:06–06:11 UTC, using supported CUA/Sky on the cloud Linux desktop. Godot 4.6.3 stable, X11, OpenGL compatibility renderer (Mesa llvmpipe). No source edits or forced game state. Scenes launched from the editor with F6 and stopped with F8. Exclusive CUA was released at 06:11 UTC.

## Fresh corrected native pixel run

Scene: `res://simulation/onward_marker_pixels.tscn`.

- Native completion screen: 150 comparisons, zero failures.
- `onward_marker_native_pixels.json`: all 150 records passed, each with zero different pixels and zero maximum channel error; all 12 rendered reuse checks passed; empty failures array; sources_unchanged true.
- All 652 tested source hashes match `onward_marker_frozen_sources.json` after normalizing the res:// prefix. The manifest SHA-256 is `727e84d60e3c324596605fc5e9b2bd68c0cbe6b31eb7289bae250c7ff5849210`.
- Current files matched the manifest before and after the review. These are fresh corrected results, not inferred from the earlier parser-blocked attempt. Earlier failure evidence remains preserved separately.

## Diagnostics, inspected separately from pixel success

The full pixel debugger list contained 10 entries:

1. Graphics driver cannot change VSync mode.
2. Audio init_output_device: condition status < 0; ERR_CANT_OPEN (red error).
3. All audio drivers failed; dummy driver fallback.
4. Local reference shadows a RefCounted method.
5. owner shadows a Node property.
6. transform shadows a CanvasLayer property.
7. Incompatible ternary expression types.
8. kind shadows a current-class variable (line 16).
9. material shadows a CanvasItem property.
10. scale shadows a Node2D property.

The corrected run had no parser halt. The standalone live scene contained only the three environment entries above. Pixel success is not a claim of an empty debugger or functioning audio.

## Actual standalone observations

Scene: `res://simulation/onward_marker_review.tscn`, visible game area 1280×720.

- Title, explanatory text, four markers, and all controls were readable and unclipped.
- Initial presentation: amber ONWARD, mint ONWARD, amber LIFT, mint LIFT.
- O made the first marker mint; the other three remained unchanged.
- L changed only the first label to LIFT.
- O returned the first to closed amber. C changed that first closed marker to red; a second C restored amber. Peers remained unchanged.
- H hid only the first marker and label; the other three and instructions remained visible.
- R restored the initial amber ONWARD first marker and original four-sample presentation.
- F8 stopped execution; the editor visibly reported that the debugging process stopped.

This verifies presentation and ordinary-input isolation. The fixture explicitly describes a nonblocking marker and sonar contour supplied by host state. These observations do not independently prove collision, contour physics, route completion, or actual relay/freight shutter semantics.

## Original native capture files

All files below are original Sky screenshot bytes, verified as JPEG, 1364×1024; no generated or reconstructed images:

- onward_marker_pixels_complete.jpg
- onward_marker_pixels_diagnostics.jpg
- onward_marker_live_initial.jpg
- onward_marker_live_open.jpg
- onward_marker_live_label.jpg
- onward_marker_live_red.jpg
- onward_marker_live_amber.jpg
- onward_marker_live_hidden.jpg
- onward_marker_live_reset.jpg
- onward_marker_live_diagnostics.jpg
- onward_marker_stopped.jpg

All paths are relative to this evidence directory.
