# Rejected-noise audio hardening

Status: **PASS, 13 checks at both 60 and 120 Hz.** Adjacent audio and input-guidance suites also pass: **306 checks total**, no engine errors or source drift in the reviewed snapshot. Evidence: `evidence/rejected_noise_review.json`.

This is synthetic hardening, not an authored gameplay bug. The fixture admits a genuine lethal `player.receive_hit`, injects an unrelated-room noise after the real host accepts its hurt cue, then lets real Health and defeat routing complete in the same physics frame. The rejected noise must not erase the pending genuine cue. Null sources are also covered.

The test uses actual NoiseBus/host admission and a headless-only AudioDirector subclass to allocate explicit voices. It makes no audible-output or physical-controller claim. It verifies that accepted requests with identical values replace pending identity and that accepted muted or missing-cache requests still clear pending state.

The unguarded host failed exactly the two rejected-source checks at both rates. The proposed guard passed in an isolated in-memory candidate; the integrated host passes without replacing its script. No original actor, demo, or AudioDirector changes were needed.

Run from an imported project with an isolated `HOME` and `XDG_*` directories:

```sh
godot --headless --path . --script res://campaign/quality/nov6_audio/rejected_noise.gd -- --hz=60
godot --headless --path . --script res://campaign/quality/nov6_audio/rejected_noise.gd -- --hz=120
```

Each run emits one `NOV6_AUDIO_REJECTED_NOISE_RESULT` JSON marker with numeric `checks`, boolean `passed`, and `failures`. Reports default to `user://nov6_audio/`; `--output=/absolute/path/outside/the/project.json` is optional. Invalid rates and project-local report destinations fail. Preserve historical receipts when rerunning.
