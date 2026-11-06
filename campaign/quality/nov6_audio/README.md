# Reproducible campaign audio QA

Use Godot 4.6.3 from the project root. Tests disable checkpoint saving and never write runtime or source files. Reports default to `user://nov6_audio/`; `--output` may name a user-data path or an absolute file path outside the project. Source-tree destinations and relative paths are rejected.

## Headless acceptance

Run both scripts at both physics rates:

```sh
godot --headless --path . --fixed-fps 60 --script res://campaign/quality/nov6_audio/contract.gd -- --hz=60 --output=/tmp/moksha-audio-contract-60.json
godot --headless --path . --fixed-fps 120 --script res://campaign/quality/nov6_audio/contract.gd -- --hz=120 --output=/tmp/moksha-audio-contract-120.json
godot --headless --path . --fixed-fps 60 --script res://campaign/quality/nov6_audio/event_routing.gd -- --hz=60 --output=/tmp/moksha-audio-routing-60.json
godot --headless --path . --fixed-fps 120 --script res://campaign/quality/nov6_audio/event_routing.gd -- --hz=120 --output=/tmp/moksha-audio-routing-120.json
```

Each successful process exits 0 and emits exactly one machine result line:

- `NOV6_AUDIO_CONTRACT_RESULT {JSON}`: 67 checks for modal mute, echo/release handling, focus/pending state, selective cue promotion, same-frame hurt freshness, stale zero-position rejection, room retirement and ambience preservation. Audio players are deliberately constructed contract fixtures, not audible playback evidence.
- `NOV6_AUDIO_ROUTING_RESULT {JSON}`: 23 checks for cue/origin mapping and rejection of unrelated, absent and old-room sources. NoiseBus requests are explicitly injected schema cases, not physical gameplay.

JSON includes a positive numeric `checks`, boolean `passed`, `failures` array, `physics_hz` and detailed `rows`. The acceptance runner should require one marker, `passed=true`, empty failures, exit 0 and no Godot script/error diagnostics. An output-write error also fails the result.

## Native lifecycle

Run from a native display session, without `--headless`:

```sh
godot --path . --script res://campaign/quality/nov6_audio/native_probe.gd -- --hz=120 --output=/tmp/moksha-audio-native-fixed.json
```

The default is fixed-runtime expectations. `--expect-baseline` selects original expectations when running the same QA script in an archived original `f00bf23031cf7c74882d47a855ebafc701024634` project. It does not modify or roll back runtime code. `--expect-fixed` is also accepted for compatibility with the original audit launcher.

The probe emits one `NOV6_AUDIO_NATIVE_RESULT {JSON}` and checks eight native conditions: original audio branch, ordinary spatial pause/resume, victory playback, archive tap completion during the modal, all 11 mute modes, lethal hurt playback during death and no old hurt on retry. Archive pickup invokes the original interaction; lethal damage uses the actor's public damage-admission boundary, not a natural-contact playthrough. It also records input-driven jump/noise observations without changing their behavior. Fixed archive completion is checked while the modal remains open, with up to one additional second after the 250 ms snapshot to allow native scheduling latency.

**Dummy audio is not listening verification.** The available native environment reports X11 rendering but has no soundcard; playback positions and lifecycle are measurable, speaker output and audible mix are not. The script explicitly fails under a headless display rather than claiming to exercise the skipped audio branch. It waits 250 ms after host teardown so the audio thread can retire its resources.

## Preserved before/after evidence

`evidence/native_baseline.json` and `native_fixed.json` are byte-for-byte copies of the original isolated audit observations. The baseline archive tap and lethal hurt stay at playback position 0 for 250 ms and start on close/retry. Fixed archive feedback finishes in the modal; fixed hurt reaches approximately 0.192 seconds during death, with no old hurt on retry. Existing spatial pause/resume and nonspatial victory remain correct. Baseline M misses journal/upgrade/final_choice; fixed M works in all 11 modes.

`evidence/source_manifest.json` identifies the isolated candidate and preserved original audio/demo/player files. These are historical audit hashes, not a claim that the later combined production campaign file has that exact hash. `SHA256.json` authenticates the copied historical evidence. `qa_verification.json` records checks of the adapted QA files against the combined runtime. `native_portable_first.json` preserves a strict-timing false failure: the tap had advanced to 0.0987 seconds at the 250 ms snapshot but had not yet retired. The portable probe now requires bounded completion before modal close instead of assuming render and audio clocks advance identically; its observation arrays are also copied so later events cannot alter earlier snapshots. Historical jump/noise arrays are not acceptance evidence because the old fixture retained live array references. `native_portable_final.json` records the corrected portable probe passing 8/8 on the combined runtime.

`teardown_summary.json` records 24 controlled Dummy-driver trials: three frames alone produced shutdown resource diagnostics in 11/12; adding 250 ms produced 0/12. This supports fixture teardown waiting, not a gameplay leak claim or an original audio rewrite.

`wav_stats.json` records no full-scale samples in the 11 original WAVs. Raw peaks range from approximately -20 to -2.384 dBFS before runtime attenuation. Overlapping-mix clipping, soundcard output and a full human playthrough are not verified. A synthetic 512-request burst demonstrated no hard voice cap, not a normal-play overload; no cap, prioritization, jump or noise changes were made.
