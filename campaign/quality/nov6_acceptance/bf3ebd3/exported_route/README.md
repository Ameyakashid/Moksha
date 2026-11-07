# Exported continuous campaign evidence

**PASS:** one continuous neutral, sight-traded campaign at 60 Hz against the actual exported MOKSHA PCK.

- 32 ordered district completions and open-gate receipts; 89 required goals; 8 relays; 3 freight deliveries.
- Five level receipts and four ordinary upgrade choices; public-record ending; sight trade persisted.
- Zero deaths, route failures, engine errors, source/QA/PCK drift, or loose production resources.
- 817 production inputs matched both frozen commits; 275 packed script hashes, 228 packed resources and 238 route source hashes verified.
- Wall time: 622.567 seconds. Simulated active time: 1209.45 seconds. Neither measures human playtime or target-device performance.

## Exact tested identity

- Runtime: `bf3ebd382eb9485eeaffcdff9fe9bfcfda8d3ad5`.
- Packaged source/tools: `c489885befb2264bf2dc0afd2cac8e147d1c9730`.
- PCK SHA-256: `490c51da2cb17b2d026d55af6e1739914837ae5e2fcefa0aac9fc861c08b04fa`.
- Official Godot: `4.6.3.stable.official.7d41c59c4`.

## Evidence

`MOKSHA-exported-route-evidence-c489885.zip` contains 32 files: exact raw logs/receipts, packed identity checks, the portable runner, six frozen external QA scripts and their originals, full path-only diff, and checksums. The original evidence archive is preserved byte-for-byte. `provenance.json` summarizes the result; `verification_index.json` records archive/member integrity and local summary hashes.

Archive: 218,656 bytes; SHA-256 `a193a8e3a33b4b3377b371f0d1409e632a20edf062694e4c6e06f21e59095bc9`.

Only six QA dependency/output lines were adapted. Production references remain `res://`; the engine ran from an empty resource directory against the PCK with isolated HOME/XDG paths. Full actor physics, route assertions, ordinary key/input handling, accepted modal/freight observers, and the 480-second district limit were unchanged.

## Reproduction

Extract the archive **outside the active source/QA tree**, then run:

```sh
python3 run.py --godot /path/to/godot --pack /path/to/MOKSHA.pck --output /path/to/new-evidence
```

The source repository is not needed. The runner deliberately pins the exact identity above. A different PCK needs a separate identity-specific harness preparation and fresh run; this result does not cover later packages automatically. Preserve the archived evidence unchanged.

Scope: automated Linux/headless exported integration using a layout-aware raw-input/key dispatcher. Not human traversal, Windows execution, physical-controller testing, audible-output review, or target-hardware acceptance.
