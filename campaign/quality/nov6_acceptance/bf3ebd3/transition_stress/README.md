# Exact bf3 transition acceptance

All eight default runs pass on exact Git archive `bf3ebd382eb9485eeaffcdff9fe9bfcfda8d3ad5`, without runtime or fixture overlays. Godot 4.6.3. 3,301 archived files match their Git blobs, with zero missing/extra paths or content differences. No engine/script errors or source/fixture drift. Six runner guard unit tests pass.

Positive evidence: 617,379 assertions, 76,554 measured event steps, and 1,404 cases, including explicit replay. Main 60 Hz, main 120 Hz and replay 60 Hz each run 444 cases and 202,265 assertions. Cumulative 60/120 Hz runs each include 36 cases and 5,292 assertions. Rollback/input negative controls fail their intended assertion, and the unsafe-save isolation control refuses before writing. The main seeded command/state digest is `efbc9043567d82c8a099eb510f98995ea324945c283cc411f73a06fb68b321b4` and matches the earlier b2 result.

The suite uses actual parsed keyboard/joy events and engine focus/disconnect signals with explicit modal/exit fixtures. Host ticks are controlled at 60/120 Hz; the unchanged archived runner uses fixed-fps 600 for deterministic accelerated execution while awaiting actual physics-frame boundaries. This is distinct from the separate native-input composition review, whose fixed and physics rates both match 60/120. No full-campaign traversal, hardware, rendered/audio or human-timing claim is made here. Read fixtures/README.md inside the evidence archive, or campaign/quality/nov6_transition_stress/README.md in the repository, for the controlled setup and limits.

Source provenance and all 3,301 blob hashes are in source_manifest.json and git_blob_verification.json. Exact commands and counts are in summary.json. The evidence archive includes raw engine diagnostics, JSON results, engine identity, frozen fixtures and runner unit output. No previous b2 or candidate evidence was replaced. Original actor/controller and demo runtime files, plus audio_director.gd, are byte-identical to pre-pass 9e. Two pre-existing demo evidence JSON receipts changed during the broader work; they are recorded separately and excluded from the runtime preservation comparison.

Reproduce with the source-provided runner:

```sh
python3 campaign/quality/nov6_transition_stress/run.py --source . --revision bf3ebd382eb9485eeaffcdff9fe9bfcfda8d3ad5 --output /tmp/moksha-bf3-transition-new
```

Use a new output directory. The source tree is read-only to the runner.
