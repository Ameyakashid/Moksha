# Checkpoint identity and compatibility

The current checkpoint schema is **version 4**. The existing `user://first_ascent_expanded_checkpoint.json` filename remains in use. `sector_id`, `cache_ids` and history `area_id` values identify authored areas; runtime traversal still uses the current ordered sector list. Stable IDs do not by themselves update hard-coded test/navigation indices when a future chapter is inserted.

## Legacy and invalid saves

Version 3 is decoded against its immutable eight-area order, not whichever order a later campaign happens to use. Its sector, collected archives and history are mapped to stable IDs, then resolved against the current campaign. Version 4 resolves IDs directly. The current campaign actually inserts `upper_residential_crossing` between Cistern and Relay Works: eight gameplay areas plus the ending. The historical v3 mapping remains the original eight total areas; v4 IDs resolve against the new nine-area list, preserving old Relay Works/Warden/ending meanings rather than treating shifted indices as identity.

Unknown/duplicate IDs, unsupported versions, malformed JSON or malformed progress values are rejected. Reading/validating a save does not rewrite it. An explicit successful Continue restores the decoded sector/sight/archive/progress state; normal sector construction then writes the current schema. Per-sector relay/shutter/enemy state is reconstructed, not restored mid-combat. Collected caches and the sight choice persist according to existing mission rules.

Before replacing a legacy or invalid active file, the host preserves its exact bytes as `.preserved-<SHA-256>.json` and checks the backup hash. It writes the new data to `.pending`, flushes/closes, then renames it into place. A failed preservation or write/commit reports that the checkpoint was not updated. A previously valid checkpoint remains offered when the implemented failure path confirms it remains usable. Explicit New Mission may replace an invalid active file only after preservation succeeds.

Previous project ZIPs remain rollback. Older builds may not understand schema 4; retain preserved v3 files and do not treat schema migration as guaranteed backward compatibility. User saves live in Godot's user-data directory, not inside the source ZIP.

## Verification and limits

The migration fixture covers legacy identities under synthetic insertion/reordering, malformed rejection, serialized round trips, actual mission Continue/new-run/retry, byte-preserving backups and selected failure branches. Cistern lifecycle additionally checks fresh-host Continue with retained/traded sight and exactly one collected Cistern archive. The prior merged Cistern acceptance is preserved in `CISTERN_VERIFICATION.md`. Current real-nine-area identity fixtures exercise old v3/current v4 area/cache/history meanings, actual host Continue/retry, and the new chapter cache with retained/traded sight. Final current acceptance is recorded separately in `RESIDENTIAL_VERIFICATION.md`; historical original-eight fixtures remain explicitly historical.

This is not a guarantee against power loss, storage hardware failure, disk exhaustion, OS-specific rename behavior, cloud-sync conflicts, concurrent processes writing the same save, externally changed permissions, or an adversarial filesystem race. No process-kill/power-failure durability campaign or cross-platform storage qualification has been performed. `flush()` plus rename is not claimed as a proven fsync/directory-durability transaction. Selected simulated/constructed I/O-failure checks do not establish every real-world failure mode.
