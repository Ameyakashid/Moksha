# Exchange station final native refreeze review

2026-10-20 07:25–07:27 UTC. Supported CUA/Sky cloud Linux desktop; Godot 4.6.3, X11, OpenGL compatibility renderer. Fresh F6 run of `res://simulation/exchange_station_pixels.tscn`, followed by F8 stop. No source edits or forced state. CUA released before the broad rerun.

## Fresh result

Native completion screen: 146 comparisons, zero failures. Fresh `exchange_station_native_pixels.json`: all 146 records pass with zero different pixels and zero maximum channel error; all 12 rendered reuse checks pass; empty failures array; sources_unchanged true. All 666 report hashes match the freeze after stripping res://. All current sources match before and after execution.

Manifest: `exchange_station_pre_native_sources.json`; SHA-256 `2ee456f5fe3c0232c836531570fe2be3c594da94245c47440b44c60d1c6e9632`.

## Full debugger inspection

All 10 entries were visible together and read:
1. Graphics driver cannot change VSync mode.
2. Audio output initialization status < 0, ERR_CANT_OPEN (red error).
3. All audio drivers failed; dummy fallback.
4. reference local variable shadows RefCounted method.
5. owner parameter shadows Node property.
6. transform variable shadows CanvasLayer property.
7. Ternary values are not mutually compatible.
8. kind parameter shadows current-class variable at line 16.
9. material variable shadows CanvasItem property.
10. scale variable shadows Node2D property.

No parser halt. Diagnostics match the previous accepted native run; passing comparisons do not imply an empty debugger or functioning audio.

## Prior live correspondence

Before overwriting the native JSON, compared its previous tested source hashes with the new manifest. Only `simulation/tests/room_backdrop_regression.gd` and `simulation/tests/exchange_station_preservation.py` changed. Production and live fixture hashes are unchanged. The earlier ordinary-input H/C/R isolation, custom sample and readable layout observations remain applicable; live controls were not repeated. See `exchange_station_native_review.md` and its original live captures. No collision, sight-trade, or completion claim is inferred from presentation proof.

## Distinct actual captures

- exchange_station_final_native_complete.jpg
- exchange_station_final_native_diagnostics.jpg
- exchange_station_final_native_stopped.jpg

Original Sky screenshot bytes, verified JPEG 1364×1024. Earlier captures/review and `exchange_station_failed_depth_attempt/` were left intact.
