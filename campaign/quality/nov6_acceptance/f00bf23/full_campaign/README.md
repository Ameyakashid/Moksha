# Full campaign evidence: f00bf23

Result: **5/6 passed; the retained Neutral/60-Hz cargo observer timeout is preserved**.

This is a compact evidence bundle, not a source clone. The summary, snapshot and
receipt inventory are plain JSON. Six original reports, six case engine logs,
import log and runner log are preserved byte-for-byte in
`raw_reports_and_logs.tar.gz`. `artifact_index.json` maps each case to its archive
members. Original paths inside recorded evidence are intentionally unchanged.

Verify integrity:

```sh
python3 verify_evidence.py
sha256sum -c SHA256SUMS
```

Inspect the original raw files:

```sh
tar -xzf raw_reports_and_logs.tar.gz
```

`SHA256SUMS` covers every included file except itself. The raw member index also
checks each uncompressed report/log. No caches, user directories, imported assets
or runtime source clone are included. The recorded runtime commit is
`f00bf23031cf7c74882d47a855ebafc701024634`. The snapshot identifies tested source and observer
hashes; source/observer drift is empty in the recorded matrix.

The four tiny observer overlay files are the exact modal-only revisions used
with this older f00 runtime. They are supplied for provenance, not as production
fixes. `run_matrix_recorded.py` is the original machine-specific runner, preserved
verbatim. Do not run it directly against a newer live checkout. This baseline
remains separate from the later b2e7f35 all-pass evidence.

These are headless input-only automated traversals, not validated human pacing,
Windows/native hardware performance or audible-mix acceptance. No final b2 run
needed the rare short-cargo follow-up; its positive evidence is the separately
labelled paired physical fixtures in `nov6_observer_evidence/cargo/`.
