# Static platform native review

Reviewed 2026-10-20, approximately 03:39–03:42 UTC, in the supported cloud Linux desktop using CUA/Sky and Godot 4.6.3. Scene: `res://simulation/static_platform_review.tscn`. No source edits, forced game states, or hidden-state manipulation were used. The broad headless suite was stopped during live review. F8 stopped the scene afterward; exclusive CUA access was released before the aggregate retry.

## Actual native observations

- Corrected 640×360 logical scene was fully framed in the visible 1280×720 game viewport. All four instruction lines were readable, including the distinction between upper transformed appearance views and lower actual PC/NPC supports.
- A/D moved the PC horizontally. A held Space jump reached and landed on the first raised support; a short tap returned to the floor.
- H hid the first raised platform's appearance. The PC remained standing at its top height across separate observations and could move across the invisible support. A second H restored the appearance under the PC.
- R restored the initial PC location and platform visibility after hiding. Another jump and horizontal movement verified reuse after reset.
- The autonomous NPC visibly changed position and gait on the right raised block.
- S+Space dropped the PC from the first one-way platform to the floor. The builder confirmed S and Down are both bound to the down action.
- Literal Down+Space through this CUA input route produced a jump rather than a drop in two attempts. The exact arrow-key chord is therefore not verified; the cause was not established. This does not override the successful S+Space observation.

## Captures

These are original, unaltered Sky screenshot bytes retained from the review, persisted after it ended. Each is a 1364×1024 desktop JPEG containing the actual game/editor pixels. They are not generated images or screenshots from a later rerun.

- `static_platform_live_initial.jpg`: full readable fixture, PC on floor, NPC on raised support.
- `static_platform_live_hidden_support.jpg`: PC remains supported while first platform paint is hidden.
- `static_platform_live_restored_support.jpg`: appearance restored under the standing PC after horizontal movement.
- `static_platform_live_reset.jpg`: reset restores initial PC location and platform appearance.
- `static_platform_live_reuse.jpg`: PC back on first support after another jump following reset.
- `static_platform_live_drop.jpg`: PC on floor following S+Space from the raised platform.
- `static_platform_live_diagnostics.jpg`: native editor diagnostics after stopping review.

## Diagnostics and limits

The native debugger displayed ten entries: one red audio initialization `ERR_CANT_OPEN`; warnings for unsupported V-Sync and audio-driver failure with dummy fallback; and seven script warnings concerning `owner` shadowing, `expected_action` and `expected_weapon` declared below the parent block, incompatible ternary values, `notification` shadowing, and `normal` and `obstacle` declared below the parent block. No gameplay crash or assertion was observed.

This is a qualitative native-input review, not a replacement for deterministic test results. Earlier frozen pixel presentation was already open when CUA recovered and visibly showed 100 comparisons and zero failures; it was not rerun here. Automated source hashes, six isolation checks, and aggregate-suite results remain the builder's separately recorded evidence.
