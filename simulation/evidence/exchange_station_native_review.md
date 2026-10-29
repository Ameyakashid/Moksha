# Exchange station native review

2026-10-20 07:00–07:03 UTC. Supported CUA/Sky cloud Linux desktop, Godot 4.6.3, X11, OpenGL compatibility renderer, Mesa llvmpipe. Editor F6 launches; F8 stops. No source edits or forced state. Exclusive CUA released after the live run stopped.

## Pixel result

Fresh `res://simulation/exchange_station_pixels.tscn` completed visibly with 146 comparisons and zero failures. `exchange_station_native_pixels.json` independently checked: 146 passing records, each zero different pixels and zero maximum channel error; all 12 rendered reuse checks pass; failures empty; sources_unchanged true. All 666 tested hashes match the freeze after normalizing res:// prefixes. All current source files also match before and after review.

Manifest: `exchange_station_pre_native_sources.json`, SHA-256 `f885fdf6484e867a4c575456049aabf9812ae24bdf79a1772e38c1b1a1eeb429`.

## Full diagnostics

The native pixel debugger showed all 10 entries, inspected together:
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

No parser halt. Live debugger contained only the three environment entries. Pixel success does not imply empty diagnostics or functioning audio.

## Standalone actual observations

`res://simulation/exchange_station_review.tscn` displayed a 1280×720 game area. Header, mission-ownership explanation, H/C/R instructions and all four station samples were readable and unclipped. Repeated default samples, CALIBRATION custom label, and orange custom label/icon sample were clear. C changed only the first label and circular icon to red; its outline and the three peer stations remained unchanged. H removed only the first station paint and label. R restored the original complete presentation. F8 stopped execution, confirmed by editor output.

This is presentation and ordinary-input reuse proof. The fixture labels the contour nonblocking and assigns trade/choice/health/speed/noise to the mission. No sight-trade action was attempted or expected; this live inspection does not independently prove contour physics, trade semantics, or completion. Transformed/decomposed raster cases are covered by the exact native comparison records, not inferred from the four static live samples.

## Original native captures

- exchange_station_pixels_complete.jpg
- exchange_station_pixels_diagnostics.jpg
- exchange_station_live_initial.jpg
- exchange_station_live_color.jpg
- exchange_station_live_hidden.jpg
- exchange_station_live_reset.jpg
- exchange_station_live_diagnostics.jpg
- exchange_station_stopped.jpg

All are original Sky screenshot bytes, verified JPEG 1364×1024. No generated or reconstructed imagery.
