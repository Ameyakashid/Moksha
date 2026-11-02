# Asset and audio guards — November 2, 2026

## Adopted

`python3 campaign/quality/assets_audit.py --output /tmp/moksha-assets.json`
checks a conservative runtime/source inventory, its SHA-256 catalog, static
literal `load`/`preload` and serialized resource references, PNG header dimensions,
and PCM WAV structure/payload. It includes legacy runtime assets and excludes the
explicit development-directory list emitted in its report. It is **not** an exact
reachable-dependency export graph. Dynamic paths still need Godot import/smoke.
PNG header inspection is not full image decoding or visual approval.

At the preserved c6f1f92 baseline: 523 files, 10,659,790 source bytes; largest file
2,145,320 bytes; largest PNG 1,573,352 pixels; 611,446 PCM bytes. The 844 literal
resource references resolve. This is not a Windows ZIP/PCK download-size claim.
Reviewable budgets permit 10% total/count/PCM growth and 20% largest-file/image
pixel growth. They catch accidental growth relative to **this game**, not promise
a web-game target or any FPS. Budget changes require deliberate file review;
the audit never updates its own baseline.

`python3 campaign/quality/assets_audit_test.py -v` runs twelve mutation tests,
including deliberately missing resources, exceeded budgets, malformed media,
truncated PCM, and unsafe paths. Excluded evidence and dynamic path fragments
are tested so they do not create false positives.

`python3 campaign/quality/assets_audio_repro.py` runs the two existing original
procedural generators in a temporary directory. All nine resulting WAVs match
the committed bytes exactly with the current Python runtime. Production audio
is never overwritten. `tap.wav` and `step.wav` are not emitted by these generators
and are explicitly outside this regeneration claim. No sound was listened to in
this check; PCM integrity/reproducibility cannot establish mix quality.

## Already present, preserved

Five `campaign/assets/themes/*.tres` palettes share
`campaign/presentation/campaign_theme.gd`; scenery reuses the original atlas
textures instead of duplicating them per biome. The operative source sheet was
visually inspected during this pass: its 12 poses share the gray-haired character,
dark coat and orange shoulder treatment. This source inspection is not runtime
crop/animation acceptance; actual rendering and existing pose contracts remain
separate checks. No recoloring/repacking is justified by a measured defect.

Existing procedural WAV synthesis uses a fixed Python RNG seed and standard
library oscillators/envelopes. The scene sound director caches sounds and routes
spatial cues. The atmosphere is one loop, not adaptive biome scoring.

## Deferred with reasons

- Repacking all textures or imposing one tiny palette would risk approved
  detailed art/atlas coordinates without a measured bottleneck.
- Procedural biome music/crossfades need composition and real audible testing.
  They are not a safe silent improvement to combat cue clarity, especially for
  optional sight-trade play. Keep the current generated sounds until such a test
  is authorized/available rather than claim adaptive music already exists.
- GPU texture memory, frame-time/FPS, export download budgets and sound-device
  latency require the actual renderer/export/hardware. Source bytes and headless
  wall timing are not substitutes.
