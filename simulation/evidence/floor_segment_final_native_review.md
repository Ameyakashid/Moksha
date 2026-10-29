# Final-source floor native renderer verification

Fresh native run on 2026-10-20 at approximately 05:02–05:03 UTC, using supported cloud CUA/Sky, Godot 4.6.3, and `res://simulation/floor_segment_pixels.tscn`. Broad tests were held. No source edits or forced outcomes. The editor launched the scene with F6; F8 stopped it, and CUA was released at approximately 05:03 UTC.

## Fresh results

The actual completion screen displayed 108 comparisons and zero failures. The newly written `floor_segment_native_pixels.json` had modification time `2026-10-20T05:02:46.644651+00:00`. Independent reading confirmed:

- 108 records, all passed, each with zero differing pixels and zero maximum channel error.
- Six reuse checks, all passed.
- Empty failures array and `sources_unchanged: true`.
- All 627 tested source hashes match the frozen manifest after removing report keys' `res://` prefix.
- All 627 current files independently match the frozen manifest.

Manifest: `floor_segment_pre_native_frozen_sources.json`.
SHA-256: `c5e50887e23958de9ba361504d21ed65fca728b491c466dca0520d3a4b117957`.

This run follows the test-bot-only correction. Its results are freshly observed and not inferred from the prior run. The unchanged standalone live mechanics were not repeated; their earlier observations remain in `floor_segment_native_review.md` and the preserved prior evidence.

## Complete diagnostics

All nine entries were visible and inspected:

1. V-Sync mode change unsupported by graphics driver.
2. Audio `init_output_device` error: `status < 0`, returning `ERR_CANT_OPEN`.
3. All audio drivers failed, falling back to dummy driver.
4. Function parameter `owner` shadows Node property.
5. Local variable `transform` shadows CanvasLayer property.
6. Ternary operator values are not mutually compatible.
7. Function parameter `kind` shadows variable declared at line 16.
8. Local variable `material` shadows CanvasItem property.
9. Local variable `scale` shadows Node2D property.

The renderer comparison passed despite these disclosed environment/static warnings; no warning-free claim is made.

## Original screenshot files

- `floor_segment_final_pixels_complete.jpg`
- `floor_segment_final_pixels_diagnostics.jpg`

Both are original, unaltered Sky screenshot bytes from this fresh run, showing the actual native desktop and renderer/editor pixels.
