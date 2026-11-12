# Extended November 12 acceptance receipts

Runtime freeze: `45a6c2b2d1502f6a8d045ae33c1bcb1f6e020917`.
This follow-up adds evidence only. It does not alter that frozen source, its
packages or uploads. **These runs do not cover subsequent caption changes.**

## What passed

- `source-gate.json`: all 11 combined outer stages passed, including the 16-stage
  domain and 20-stage broader quality suites. All 4,299 tracked files unchanged.
- `neutral-retained-public/`: continuous normal-title automated 60 Hz run,
  neutral lens, retained sight, public-record ending. All 32 districts and five
  level receipts, zero deaths/failures; active time 1,350.58 seconds.
- `strength-traded-local/`: complementary Strength run, actual optional sight
  trade and local-custody ending. All 32 districts and five level receipts,
  zero deaths/failures; active time 1,195.40 seconds.
- Both full-run logs were clean, exit codes zero, tracked source and observer
  hashes unchanged. Routes use normal input and real physics, not injected
  position/health/objective completion. They are automated, not human play.
- `package-gate.json`: all 31 export/packed-runtime gates passed. Full-history
  bundle cloned independently, passed fsck and reproduced all 4,299 source files.
  Windows EXE matches the prior official runtime; the game PCK is freshly exported.
- `portable-metadata-receipt.json`: final Windows copy changes only BUILD_REPORT
  paths and its checksum entry. Every other member, including EXE/PCK, is identical.
  Its extracted PCK passed another Linux/headless audit: 32 districts, five levels,
  284 script hashes and 228 loaded resources. Three Windows parts and seven
  combined source/history parts reconstruct their complete archives exactly.
  `delivery-inventory.json` records filenames, sizes and hashes, not upload status.

The package report's `complete_campaign_playthrough: false` describes packaging
scope. Separate full-run receipts supply the later campaign evidence without
rewriting the original report. Windows itself was not executed.

## Native evidence has narrower and different revision coverage

`native/thermal-2355f46.json` describes a 19.97-second native Linux excerpt at
`2355f460aaa80cc4b3485899f80e89afcb612f39`, not the 45a freeze or a full Thermal
playthrough. It uses automated ordinary inputs. New signs were readable, but
an optional service-objective world tooltip was partly behind the HUD at frame
30975. The bottom E prompt was seen in live review, not in that exact exported
frame. Audible mix was not validated. The clip's SHA-256 is retained; no media
or access identifier is embedded here. It is not evidence that the later caption
fix passed.

`native/homes-review.json` identifies the visually checked final 45a Homes shelter
fixture screenshot by filename and hash. The filename's `7afe629` prefix is not
its reviewed runtime revision. That fixture has a one-resource teardown warning;
readable labels do not prove clean native shutdown or natural full-level play.

## Reproduction and receipt provenance

Keep `runner/run_full.py` and `runner/full_campaign_observer.gd` together. With
Godot 4.6.3 and Python available, use an exact clean checkout and fresh output:

```sh
python3 runner/run_full.py --source /path/to/frozen-checkout \
  --commit 45a6c2b2d1502f6a8d045ae33c1bcb1f6e020917 \
  --output /path/to/new-output --lens neutral --sight retained --ending public_record
```

For the complementary route use `--lens strength --sight traded --ending
local_custody`. Outputs and user-data directories are isolated from the checkout.

`MANIFEST.json` records original and normalized receipt hashes. Local command/path
strings use `$WORKSPACE`, `$GODOT` and `$PYTHON`; these are explanatory placeholders,
not ready-to-run commands. Large per-file hash maps, archive-member inventories,
event streams and last-trace dumps are explicitly omitted where listed. District,
objective, damage and five-level outcomes remain available. Log summaries retain
original hashes and checked diagnostic lines. No AVI/MP4 or giant replay is added.

## Limits

`secret-pattern-scan.json` found zero pattern candidates in 4,139 scanned text
files; that is not proof that secrets are absent. These receipts do not establish
human pacing, every optional branch, physical controller hardware, audible mix,
native Windows execution or target frame rate. The desired 15–20 minutes per level
is not a measured result. This is a playable five-level prototype, not a claim of
finished commercial polish or completion of the broader story/sense-trade vision.
