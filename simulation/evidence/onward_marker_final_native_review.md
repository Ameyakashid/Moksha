# Onward marker final native refreeze review

2026-10-20 06:32–06:34 UTC. Supported cloud Linux CUA/Sky; Godot 4.6.3, X11, OpenGL compatibility renderer. Fresh editor F6 launch of `res://simulation/onward_marker_pixels.tscn`, followed by F8 stop. No source edits or forced outcomes. CUA released at 06:33 UTC.

## Result and frozen identity

- Actual native completion screen showed 150 comparisons and zero failures.
- Fresh `onward_marker_native_pixels.json` contains 150 passing records, all with zero different pixels and zero maximum channel error, and 12 passing rendered reuse checks.
- Failures array is empty; sources_unchanged is true.
- All 652 tested source hashes exactly match `onward_marker_frozen_sources.json` after stripping res://. All current source files matched before and after execution.
- Manifest SHA-256: `f2ca758ddc0fc6cf5eccdd285a9e23dfeb0ddb48310a6f090a3073a18ec9251e`.

## Full native diagnostics

All 10 debugger entries were visible together and inspected:

1. Graphics driver cannot change VSync mode.
2. Audio output initialization: status < 0, ERR_CANT_OPEN (red error).
3. All audio drivers failed; dummy driver fallback.
4. Local reference shadows RefCounted method.
5. owner parameter shadows Node property.
6. transform variable shadows CanvasLayer property.
7. Ternary values are not mutually compatible.
8. kind parameter shadows current-class variable at line 16.
9. material variable shadows CanvasItem property.
10. scale variable shadows Node2D property.

These match the prior accepted pixel run. No parser halt occurred. Passing pixel comparisons do not imply an empty debugger or functioning audio.

## Correspondence to prior live proof

Compared this freeze directly with tested hashes in `onward_marker_prior_native/onward_marker_native_pixels.json`. Only `simulation/tests/onward_marker_preservation.py` and `demo/tests/review_mission_integration.gd` differ. Production and live fixture files therefore retain the exact hashes of the prior observed O/L/C/H/R isolation review. Live controls were not repeated in this final test-only refreeze. The prior report and original captures remain under `onward_marker_prior_native/`.

Presentation proof remains scoped to rendering and reuse. It does not independently establish collision, sonar physics, completion, or relay/freight shutter semantics.

## Original native screenshots

- `onward_marker_final_native_complete.jpg`: actual 150/0 completion screen.
- `onward_marker_final_native_diagnostics.jpg`: complete 10-entry debugger list.
- `onward_marker_final_native_stopped.jpg`: completion log and debugging process stopped.

All are original Sky screenshot bytes, verified JPEG, 1364×1024. No generated or reconstructed imagery.
