# Quality gates — November 2, 2026

Run from the project root with Python 3 and Godot 4.6.3:

```sh
python3 campaign/quality/run_quality.py
# Optional: GODOT_BIN=/path/to/godot; --output /new/evidence/directory
```

The command imports and smoke-loads all 32 districts, runs the new guards plus
existing real incoming-damage/save/retry/UI fixtures at 60/120 Hz, then records and
replays bounded seeded input runs. It uses fresh writable HOME/XDG directories,
rejects engine/script errors even with exit zero, requires completion markers,
records source hashes and detects edits during execution. Evidence is written to
a new directory; old acceptance receipts are never overwritten. Run negative
controls with `python3 campaign/quality/runner_unit.py`.

## Applied from the engineering inspiration

- **Bug → regression:** corrupt/truncated JSON and a wrong-type campaign version
  exposed error paths in `_read_checkpoint`. Reuse the existing quiet parser and
  integral-number validator; valid checkpoints retain their original semantics.
  The adversarial suite now guards rejected Continue/no live mutation, pending
  writes and all district roundtrips. See `state_checks.md`.
- **Bounded state exploration:** executable real objective interactions verify
  prerequisite/route/latched-goal invariants. Physical objective success is an
  explicit abstract edge, not a physics or TLA+ proof.
- **Reproducible diagnostics:** `replay_checks.py` records seeded raw controller
  inputs and compares each gameplay trace tick in a fresh second process, keeping
  the input, hashes, first divergence and measured action coverage. Three seeds,
  60/120 Hz and 12 seconds per case are the default. This is same-build bounded
  repeatability, not a cross-platform determinism or complete-campaign claim.
- **Reviewable budgets:** `assets_audit.py` checks missing literal resources,
  media structure and baseline-derived growth ceilings. `assets_audio_repro.py`
  verifies the existing nine generated WAVs reproduce byte-for-byte in temporary
  storage. See `assets_assessment.md`; no original audio/art is overwritten.

## What was deliberately not copied

This remains Godot, not TypeScript/WebGL. No speculative hot-loop rewrite,
zero-allocation claim, 124 KB download promise, 500-enemy or FPS claim. The source
inventory includes legacy assets and is not exported/download size. Wall timing
is runner duration, not renderer performance. Shared biome themes and atlas reuse
already exist. Adaptive music requires actual audible review; no silent rewrite.
Server anti-cheat and localized sharing cards are outside this offline campaign's
current request. Full-route bots already exist in `campaign/tests`; the new short
replays supplement rather than replace them.

## Acceptance limits and native check

This pass personally launched the real native Godot project, inspected title and
Rainline, sent movement/jump/attack input, checked the journal, retry and a fresh
process's Continue. Existing art is preserved. Native rendering used Mesa llvmpipe;
the output device failed and Godot selected its dummy audio driver. Thus visual
inspection is real, but **audible mix and target-hardware FPS are not verified**.
It is a bounded opening-district check, not another full native campaign.

The older six full-route receipts and 72-stage foundation results remain labelled
historical and hash-bound to the earlier source. This pass reruns affected focused
checks, not those entire suites. Human 15–20-minute level duration, Windows native
execution and full manual traversal remain open. The previous Windows EXE/PCK was
**not rebuilt** and does not contain this source-only corrupt-save fix.

See `results_summary.json` for the final measured result and exact tested hashes
in its referenced aggregate report. The full source baseline and original Git
history are preserved separately; this compact source update is not a new Windows
release.
