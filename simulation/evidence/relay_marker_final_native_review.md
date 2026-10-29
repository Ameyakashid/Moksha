# Relay marker final native recapture

2026-10-20 08:41–08:43 UTC. Supported CUA/Sky cloud Linux desktop, normal Godot 4.6.3 editor, X11/OpenGL compatibility. Fresh F6 launch of `res://simulation/relay_marker_pixels.tscn`; F8 stopped it. No source edits or forced state. CUA released before full rerun.

## Fresh results

Actual completion screen: 168 comparisons, zero failures. Fresh `relay_marker_native_pixels.json`: all 168 records pass with zero different pixels and zero maximum channel error; all 14 rendered reuse checks pass; failures empty; sources_unchanged true. All 681 tested hashes match `relay_marker_native_freeze.json` after stripping res://. All current sources matched before and after execution.

Freeze SHA-256: `f9c3dc0b1042897cf00f23662c11f0e694799481091a93054f0c510543bb2abd`.

## Complete debugger

All 10 entries visible together and inspected:
1. Driver cannot change VSync mode.
2. Audio output initialization status < 0, ERR_CANT_OPEN (red error).
3. All audio drivers failed; dummy fallback.
4. reference local variable shadows RefCounted method.
5. owner parameter shadows Node property.
6. transform variable shadows CanvasLayer property.
7. Ternary values are not mutually compatible.
8. kind parameter shadows current-class variable at line 16.
9. material variable shadows CanvasItem property.
10. scale variable shadows Node2D property.

No parser halt. These match the initial accepted native run. Passing pixel comparisons do not mean empty diagnostics or functioning audio.

## Prior live correspondence

Compared new freeze directly against the retained `relay_marker_native_attempt01/relay_marker_native_pixels.json` tested map. Changes/additions are limited to:
- simulation/tests/relay_marker_route_regression.gd
- simulation/tests/relay_marker_preservation.py
- simulation/tests/run_relay_marker_acceptance.py
- demo/tests/expanded_mission_route_bot.gd

No previous source entries were removed. Production and live fixture hashes are unchanged, so prior observed A/C/H/R isolation and readable configured samples remain applicable. Live was not repeated. Initial native and failed route/aggregate packets remain untouched. This recapture does not establish mission activation, route recovery, physics, or completion semantics.

## Actual final captures

- relay_marker_final_native_complete.jpg
- relay_marker_final_native_diagnostics.jpg
- relay_marker_final_native_stopped.jpg

Original Sky screenshot bytes, verified JPEG 1364×1024. No generated or reconstructed images.
