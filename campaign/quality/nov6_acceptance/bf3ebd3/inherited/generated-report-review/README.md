# Generated report changes after execution

The pristine source TAR still matches all 3,301 Git blobs. The executed working copy has seven tracked generated-report changes, with no runtime/test-source changes. The remaining 3,294 archived working-copy files are byte-identical.

Every before/after report is preserved in full under before/ and after/, retaining its original relative path. generated-report-inventory.json identifies all seven exact writers, hashes and byte counts. These are tracked historical output files, not untracked additions.

The initial conservative post-run audit is retained under initial-post-run-audit/. Its only unclassified change was warden_factory_60.json. The unchanged test writes that file at simulation/tests/warden_factory_regression.gd:73. It passed 1,012 checks. The 26 semantic differences are exclusively process-local instance IDs and those same IDs in attack-key prefixes; all other JSON data matches exactly. See warden-generated-report-classification.json and warden-generated-report-diff.json. No test was rerun and neither observed report was changed.

The complete new-file inventory, including ordinary logs and engine-generated import metadata, remains in both post-run audit records.
