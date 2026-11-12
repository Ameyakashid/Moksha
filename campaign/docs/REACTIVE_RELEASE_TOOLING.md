# Reactive milestone release-tool audit

This tooling-only follow-up starts at source `75134662296145ace91d943d792c41670a08efa1`. All 864 runtime-selected files remain byte-identical to that source and runtime `565cf1ed049be2248e881cdc94c2893d05b60b28`. Footage recorded on 565 remains evidence of 565; this bridge does not relabel its build.

## Delivery plan

After a separately authorized freeze/export, deliver one complete Windows archive and one canonical source-and-full-history archive, with manifests, SHA-256 checksums and verified reassembly instructions. Split each into independently downloadable containers below 20 MiB if needed; determine counts from actual new archives. Avoid redundant editable-only/history-only downloads unless requested. The complete source/history variant must restore the frozen source through its self-contained Git bundle and `git fsck`; review all reachable history before sharing it. Existing source-only synthetic QA fixtures remain part of complete source, not player saves.

START_HERE is generated for the actual source commit and describes C/controller X as Continue for an active run or View last result for a completed run. It calls for a whole-user-data-folder backup before launch, explains the unchanged checkpoint filename with its new v2 envelope, exact legacy preservation, immutable completion records, single-writer restriction and older-build incompatibility. Never edit the version number to downgrade. Restore a separate legacy backup if using an old build.

Runtime guides now include RUN_HISTORY_BOUNDARY, REACTIVE_RUN_MILESTONE and the concise INTELLECT_SLICE guide. Runtime filtering explicitly excludes checkpoint/result filenames and the live history directory. This is not a claim that filtering alone substitutes for artifact and history inspection.

## Verification scope

The existing 31 packed/export gates are preserved. Five additional fixtures at both 60 and 120 Hz bring the intended packed gate count to 41: history store, lifecycle, companion director, companion adapter and reactive integration. Every invocation receives fresh HOME/XDG directories; fixtures needing writable roots receive distinct children of an owned temporary `/tmp` directory. Root validation handles the empty physical resource root of packed execution without allowing source paths or relative/scheme paths. Console receipts are parsed and required to pass, not accepted from a marker alone.

Before export, source-only verification passed all ten new fixture/rate combinations: store 72 checks, lifecycle 85, director 55, observer 29 and reactive integration 16 at each rate. Thirty-three pure path controls passed, including empty packed-root semantics, source and source-child rejection, sibling acceptance and traversal/scheme rejection. Existing audio output guards passed separately. Packaging units passed 21 tests; source splitting passed 11. Actual copying of all ten player guides passed link validation.

Reproduce the source-only matrix with:

```
python3 tools/package_reactive_fixture_tests.py --output /absolute/fresh/outside-source
python3 tools/package_nov6_audio_guard_test.py --output /absolute/another-fresh-output
python3 tools/package_nov6_tests.py
python3 tools/package_nov6_source_split_tests.py
```

One initial local matrix attempt exposed indentation inconsistency in the appended lifecycle QA helper. That failed attempt was retained, the QA-only indentation was corrected and the entire fresh matrix rerun cleanly. No gameplay change was made to satisfy a fixture.

**Not yet established by this audit:** the new 41-stage packed run, actual Windows execution, exported artifact sizes/counts, final secret scan, or uploaded delivery. No export/upload is performed by the source-only test tool. Native gameplay, full campaigns and save migrations have their own separately scoped evidence.
