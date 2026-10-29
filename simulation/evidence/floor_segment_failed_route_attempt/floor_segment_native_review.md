# Floor segment native review

Reviewed 2026-10-20, approximately 04:28–04:32 UTC, on the supported cloud Linux desktop using CUA/Sky and Godot 4.6.3. Broad headless tests were held during review. No source edits, forced states, or unsupported display access were used. Both scenes were launched through the editor with F6 and stopped with F8. CUA was released before broad tests resumed.

## Native renderer comparison

Scene: `res://simulation/floor_segment_pixels.tscn`.

The native completion screen reported 108 comparisons and zero failures. The produced `floor_segment_native_pixels.json` was independently read: all 108 records passed with zero differing pixels and zero maximum channel error; failures was empty; all six reuse checks passed:

1. Independent defaults render identical nonblank content.
2. Resource edits affect only their own view.
3. Hiding clears target paint and preserves peer pixels.
4. Resizing changes target paint and preserves peer pixels.
5. Removing clears target paint and preserves peer pixels.
6. A new instance reproduces original pixels.

The report says sources were unchanged. All 626 tested source hashes match `floor_segment_pre_native_frozen_sources.json` after normalizing the report's `res://` path prefixes. All current source files independently matched the manifest before and after live review. Manifest SHA-256: `4a8d96d9ee3b6bd88c0f13391bccea89ed735b4ec180d32484c37c070d6b62eb`.

These exact-pixel results are instrumented evidence from the native renderer, distinct from the qualitative live observations below.

## Actual native-input observations

Scene: `res://simulation/floor_segment_review.tscn`.

- The 640×360 logical fixture was fully framed in a visible 1280×720 viewport. All four instruction lines were readable. Three transformed appearance examples were above the actual PC/NPC supports and open gap.
- D moved the PC right; A moved it left after reset. Space visibly raised the PC into the air, followed by landing at the floor height.
- H removed the left floor paint. The PC could walk and jump, then land and remain standing at the invisible floor height across separate observations.
- S+Space held for 600 ms did not let the PC pass through the solid invisible floor. S was the alternate down-action key used successfully for one-way drop-through in the preceding platform review. Literal Down+Space was not separately tested here.
- R restored the left floor paint and initial PC position.
- Ordinary D movement took the PC into the open gap. A screenshot captured its feet below floor height in the gap; a later screenshot showed the PC offscreen. R recovered the scene and subsequent A movement worked. No hidden-state reset was used.
- The autonomous NPC visibly changed position and gait while supported by the raised right floor segment.
- No gameplay assertion or crash was observed.

## Complete native diagnostics

Pixel scene: nine entries.

- One red error: audio `init_output_device`, condition `status < 0`, returning `ERR_CANT_OPEN`.
- Warning: graphics driver does not support changing V-Sync mode.
- Warning: all audio drivers failed, falling back to dummy driver.
- Six script warnings: `owner` shadows Node property; `transform` shadows CanvasLayer property; ternary values are not mutually compatible; `kind` shadows a variable declared at line 16; `material` shadows CanvasItem property; `scale` shadows Node2D property.

Live scene: ten entries.

- Same three audio/V-Sync entries.
- Seven script warnings: `owner` shadows Node property; `expected_action` and `expected_weapon` are declared below in the parent block; ternary values are not mutually compatible; `notification` shadows an Object method; `normal` and `obstacle` are declared below in the parent block.

Both full diagnostic lists were visible and captured. Warnings are disclosed separately from passing renderer checks; this review does not claim a warning-free run.

## Original screenshot evidence

All files below contain original, unaltered Sky screenshot bytes, independently verified as JPEG, 1364×1024. They are full desktop captures containing actual native viewport/editor pixels.

- `floor_segment_pixels_complete.jpg`
- `floor_segment_pixels_diagnostics.jpg`
- `floor_segment_live_initial.jpg`
- `floor_segment_live_hidden_support.jpg`
- `floor_segment_live_jump.jpg`
- `floor_segment_live_landed_hidden.jpg`
- `floor_segment_live_solid_drop_blocked.jpg`
- `floor_segment_live_reset.jpg`
- `floor_segment_live_gap_fall.jpg`
- `floor_segment_live_after_fall.jpg`
- `floor_segment_live_reuse.jpg`
- `floor_segment_live_diagnostics.jpg`
