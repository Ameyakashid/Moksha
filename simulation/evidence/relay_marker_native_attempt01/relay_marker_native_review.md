# Relay marker native review

2026-10-20 08:01–08:04 UTC. Supported CUA/Sky cloud Linux desktop, normal Godot 4.6.3 editor, X11, OpenGL compatibility renderer (Mesa llvmpipe). F6 launches and F8 stops. No source edits or forced state. CUA released after the live run stopped, before broad tests.

## Fresh pixel result

`res://simulation/relay_marker_pixels.tscn` visibly completed 168 comparisons with zero failures. Independently checked `relay_marker_native_pixels.json`: all 168 records pass, each with zero different pixels and zero maximum channel error; all 14 rendered reuse checks pass; failures empty; sources_unchanged true. All 680 tested hashes match the freeze after stripping res://. All current sources match before and after review.

Manifest `relay_marker_native_freeze.json` SHA-256: `e64d23ccb1f461555a69f8466568dba94a93dd0087c9e359f9ee427f1afea936`.

## Complete diagnostic inspection

The pixel debugger displayed all 10 entries together:
1. Graphics driver cannot change VSync mode.
2. Audio output initialization status < 0, ERR_CANT_OPEN (red error).
3. All audio drivers failed; dummy fallback.
4. Local reference shadows RefCounted method.
5. owner parameter shadows Node property.
6. transform variable shadows CanvasLayer property.
7. Ternary values are not mutually compatible.
8. kind parameter shadows current-class variable at line 16.
9. material variable shadows CanvasItem property.
10. scale variable shadows Node2D property.

No parser halt. Standalone live diagnostics contained only entries 1–3. Passing comparisons do not imply empty diagnostics or working audio. No import-path error was observed during these normal editor scene runs.

## Actual standalone live observations

`res://simulation/relay_marker_review.tscn` showed a 1280×720 game area. Header, mission-ownership text, H/C/A/R instructions, and all four samples were readable and unclipped. Initial samples were amber RELAY, mint RELAY, amber CALIBRATION, and coral RELAY.

- A turned only the first sample from amber to mint.
- C recolored only the first label, outline, and circular icon red.
- H hid only the first sample and label.
- R restored the original four-sample state, including the first amber RELAY.
- The other three samples remained unchanged through these controls.
- F8 stopped execution, with editor output confirming the debugging process stopped.

This proves ordinary-input presentation isolation. The fixture explicitly assigns activation, noise, shutters and progression to the mission. No mission interaction or physics claim follows from these decorative controls; no E interaction was attempted. Rendered comparison and reuse checks are separate automated evidence.

## Original native captures

- relay_marker_pixels_complete.jpg
- relay_marker_pixels_diagnostics.jpg
- relay_marker_live_initial.jpg
- relay_marker_live_active.jpg
- relay_marker_live_color.jpg
- relay_marker_live_hidden.jpg
- relay_marker_live_reset.jpg
- relay_marker_live_diagnostics.jpg
- relay_marker_stopped.jpg

All are original Sky screenshot bytes, verified JPEG 1364×1024, without generated or reconstructed imagery.
