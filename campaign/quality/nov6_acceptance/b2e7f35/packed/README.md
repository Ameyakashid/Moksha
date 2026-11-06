# b2 packed continued rehearsal evidence

Runtime freeze: b2e7f352b96b11e9a5137145416ddeaf4a974e27.
The actual tested PCK was 8,563,072 bytes, SHA-256
262f3685fa8c1ec4c34c363de77e1b6ed8a3023971a908e66556d01ad2467282.
PCK and engine binaries, export/import caches, isolated user data, and disposable
working trees are deliberately excluded. This is a self-contained evidence copy,
not a playable package or an exact final-source packaging pass.

## What passed

CONTINUED_REHEARSAL_REPORT.json records 28 accepted stages: import/export,
packed title and resource audit, wrapper smoke, focused damage/save/journal,
controller/input/release/lifecycle checks at 60 and 120 Hz, six corrected audio
checks, and focus/upgrade. Runtime resources came from the PCK in an empty resource
working directory. The suite is not a full campaign route or Windows test.
The physical-source output-guard negative test passed 37 checks. Packaging safety
unit tests passed 13 tests; their duplicate-member warning is intentional.

## The fixture-only correction and failed attempts

The first frozen audio-contract attempt failed report-output validation despite
passing its 67 gameplay assertions. In the exported PCK, globalized res:// was an
empty string, so the old guard mistakenly classified every absolute path as a
source-tree path. The fail-closed runner correctly stopped. Its original failed
JSON and raw log remain unchanged at verification/packed_audio_contract_60.*.

Three test-only fixture guards were corrected after the runtime freeze:
contract.gd, event_routing.gd, and rejected_noise.gd. No production game resource
changed. Their original and corrected bytes, diffs, and SHA-256 values are kept in
frozen-fixtures/, corrected-fixtures/, and AUDIO_FIXTURE_OVERRIDE_MANIFEST.json.
The source-root-negative/ evidence confirms real source-root paths and res://
remain rejected. Six corrected checks passed on the same PCK, with positive
integer check counts, passed:true, failures:[], and saved JSON matching stdout.
Thus this is a continued rehearsal with explicit fixture overrides, not a claim
that every fixture equals the original b2 commit.

aborted-r2/ preserves a separate interrupted retry and every log it had written.
It did not complete and is not counted as a passing run. Neither the initial
failed attempt nor the aborted retry has been overwritten or silently promoted.

## Reading this portable copy

Raw reports and logs are byte-for-byte copies. Original absolute command paths
are historical provenance, not required local locations. COPY_RECEIPT.json maps
each original file to its portable path. References to external-fixtures map to
frozen-fixtures; external-fixture-overrides map to corrected-fixtures; external
output JSON maps to audio-json-receipts; native-review maps to ../native.
BUILD_PROVENANCE.json retains all frozen production-input hashes. The original
PCK is identified by hash but intentionally not embedded here. Tool snapshots are
recorded for audit, not standalone replacements for the repository tools.

The adjacent native/ folder contains the 31 controlled native captures. Its clean
capture log does not establish that ordinary manual Alt-F4 shutdown is clean.
That separate shutdown warning is being classified outside this evidence set.
Native Windows, audible output, target hardware performance, physical controller
hardware, and human campaign traversal/duration remain outside these claims.

Run `python3 verify_evidence.py` here to check both evidence folders, immutable
copy hashes, result receipts, failure preservation, and all captured PNG hashes.
EVIDENCE_INDEX.json hashes each included file except itself and SHA256SUMS.
SHA256SUMS additionally hashes the index, and omits only itself.
