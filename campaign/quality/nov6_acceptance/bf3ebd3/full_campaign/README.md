# Full campaign evidence: bf3ebd3

Result: **6/6 passed; all 32 districts, five level receipts, four real upgrades and zero deaths in every run**.

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
`bf3ebd382eb9485eeaffcdff9fe9bfcfda8d3ad5`. The snapshot identifies tested source and observer
hashes; source/observer drift is empty in the recorded matrix.

The final run used the exact committed archive, including all five observer
files, with no overlays. All 3,301 archived original blobs were unchanged at the
end. Historical reports copied from that archive were preserved separately while
new reports were written, as recorded in the snapshot's redirects.

Reproduce in a fresh directory from a Git repository containing this commit:

```sh
python3 rerun_matrix.py --repo /path/to/moksha-campaign --output /new/evidence/path
```

Requires Python 3, Godot 4.6.3 on PATH, Git and tar. `rerun_matrix.py` imports the
unchanged recorded runner and substitutes only repository/output paths. It refuses
an existing output directory. The six cases and their commands remain identical;
three run concurrently, with isolated user directories. A failed matrix returns a
nonzero exit status. The preserved baseline is at
`../../f00bf23/full_campaign/`.

These are headless input-only automated traversals, not validated human pacing,
Windows/native hardware performance or audible-mix acceptance. No final bf3ebd3 run
needed the rare short-cargo follow-up; its positive evidence is the separately
labelled paired physical fixtures in `nov6_observer_evidence/cargo/`.

Earlier all-pass b2e7f35 evidence remains separate at
`../../b2e7f35/full_campaign/`. No earlier evidence was replaced.
