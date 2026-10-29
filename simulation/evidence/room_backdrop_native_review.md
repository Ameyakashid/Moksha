# Native room-backdrop review

The supported existing Godot 4.6.3 editor/X11 GL Compatibility route ran the
corrected paired-SubViewport scene on the frozen 602-source candidate. The fresh
`room_backdrop_native_pixels.json` records 98/98 exact RGBA comparisons, zero
pixel/channel differences, valid expected content, frozen presentation clocks,
and six passing rendered isolation checks. Its source manifest exactly matches
`room_backdrop_frozen_sources.json`, including corrected pixel-harness SHA-256
79b1583ba3cfaf4623552468519716b26d559ef60cdcde928d412979eedbc7e8.

The matrix covers all eight actual room compositions at representative fixed
times, both initial/activated marker display states, before/after city rain
wrapping, inherited hiding, quiet opaque blackout, white sonar contour pulses,
and standalone repeated nested transformed views. The pulse calls are explicit
presentation fixtures using the production sonar API; they are not gameplay
noise-generation evidence. These snapshots prove presentation parity, not
physics simulation, campaign traversal, audio or frame-rate performance.

The live standalone scene visibly contains four labelled actual city/interior
instances, including rotated/scaled parents and translated bounds. All panels
and controls fit without clipping. The operator used H to hide/restore only the
first instance and used Space/R; changed rain snapshots were visible. Continuous
freeze timing was visually subtle because the fixture has no numeric clock
indicator, so precise clock-freeze/resume behavior is established by automated
lifecycle/pixel checks rather than claimed from the still images.

Expanded inspection of the corrected pixel run's ten debugger entries found no
remaining canvas-map renderer diagnostics. Entries were environment audio/VSync
messages and seven lint warnings. The live run's four inspected entries likewise
contained environment audio/VSync/dummy-driver messages and integer-division
lint. This is not a claim of a zero-warning editor or certified native audio.

The earlier 98-match run did contain genuine canvas-map renderer errors from
assigning a SubViewport canvas transform before tree registration. Its report,
source manifest and diagnostic screenshot remain explicitly superseded evidence;
see `room_backdrop_iteration_notes.md`. The corrected run was executed fresh,
with its own inspected completion and diagnostic captures. Production art code
was unchanged by that test-harness lifecycle correction.
