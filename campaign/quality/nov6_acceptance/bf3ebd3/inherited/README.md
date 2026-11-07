# bf3ebd3 inherited acceptance evidence

This is a portable evidence record of the completed run for commit bf3ebd382eb9485eeaffcdff9fe9bfcfda8d3ad5. It is not a source checkout or a new test run.

Result: **125/125 stages passed**: foundation 72, original 19, campaign audit 14 and quality 20. The independent scan of all 137 indexed raw stage/engine logs found no errors or warnings. Read REPORT.md and summary.json for coverage and limits.

## Original run paths

The tests ran in /workspace/scratch/fd16273ade4b/moksha-nov6-inherited-final-bf3ebd3/project. Their outer evidence directory was /workspace/scratch/fd16273ade4b/moksha-nov6-inherited-final-bf3ebd3.

All retained originals are copied byte-for-byte, including their absolute command, report and source paths. Those paths record where the original run happened; they do not refer to this repository copy. For a retained artifact under that outer directory, remove the original directory prefix to obtain its path here. The partial project/ directory here contains evidence only, not runnable game source. The execution-plan.json records the original commands and isolated user-data paths.

candidate-manifest.json, candidate-code-manifest.json, committed-blob-manifest.json and verified-code-and-assets-manifest.json describe the entire tested checkout. They are preserved source-identity records, not file inventories for this evidence-only directory. copy-receipt.json records the original exact git-archive verification. COPY_RECEIPT.json records this later evidence copy. No live repository state was tested during this copy.

## Contents and integrity

- All 137 raw logs listed in the original evidence-sha256.json retain their original relative paths and bytes. The bootstrap import log, four outer runner logs and exit codes are also retained.
- The four suite summaries, preservation and sonar reports, asset report, full exact manifests, replay comparison and prior-baseline integrity records are included.
- The six input schedules and twelve full record/replay JSON traces are stored losslessly in replay-traces.zip to keep this record compact. ZIP member paths match their original quality-results/replay/... paths. replay-trace-members.json records the SHA-256 and length of every member. The twelve individual raw replay logs remain uncompressed at their original paths.
- baseline-replay-comparison.json contains the independent comparison against b2e7f352. prior-baseline-integrity.json records checks of the earlier saved evidence; those complete older bundles remain in their separate baseline directories and are not duplicated here.
- SHA256SUMS covers every regular file in this evidence record except SHA256SUMS itself. verify_evidence.py checks that inventory, all 137 original log digests, every copied-file receipt and all 18 ZIP members without writing files or launching Godot.

Run `python3 verify_evidence.py` from this directory. Alternatively, `sha256sum -c SHA256SUMS` checks the retained files. To inspect the full traces, extract replay-traces.zip into a separate temporary directory; its members will appear under quality-results/replay/.

The source clone, source TAR, disposable caches and unrelated historical outputs are excluded. The source commit and archive digest remain recorded. This evidence does not establish native rendered appearance, audible playback, Windows hardware behavior or human first-play duration.

No files were staged or committed by this copy operation. Existing repository ignore rules may omit *.log from a normal add, so all listed logs must be included deliberately if this record is committed.

## Additional final-freeze verification

post-run-blob-verification.json rechecks every archived file against Git after all suites complete. It also checks every archived working-copy file; the working copy has exactly seven individually documented generated-report changes, with no runtime/test-source changes. The pristine TAR matches all 3,301 Git blobs. Full before/after bytes, writers, the initial audit and the untracked-file inventory are retained. environment-isolation.json records fresh HOME and test-owned XDG isolation. No source overlays were applied.
