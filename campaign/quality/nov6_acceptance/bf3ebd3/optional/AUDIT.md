# Optional reward acceptance: bf3ebd3

**PASS on exact commit `bf3ebd382eb9485eeaffcdff9fe9bfcfda8d3ad5`.** The project was extracted directly with `git archive`, with no overlays or runtime edits.

- 24/24 baseline district routes passed at 60 Hz, using neutral lens and retained sight. All 34 optional campaign goals, 31 reward IDs and 111 total goals were observed before the district exits.
- 12/12 focused routes passed at 120 Hz: City Records, Stamping Galleries, Waterline Clinic, Evacuation Spine, Listening Floor and Crown Ascent, each with retained/traded sight.
- 40 real reward collections passed at 60/120 Hz. Three crate-plate rewards and Foundry agility recovery were each collected initially, after two ordinary R retries, after title Continue and after a fresh host loaded the saved checkpoint. Repeated recovery did not stack rewards; live pickups did not heal. Exact +8% strike, +3% run and +5 capacity quantities were checked.
- Six runner guards passed, including rejecting engine errors with a zero exit, a nonzero exit, missing/failed reports and source drift.
- Clean import and all 40 engine cases had no engine errors or source drift. Every one of the 3,301 archived files was reverified against its exact Git blob after all tests and remained byte-identical to the initial snapshot.

## Source and records

`final_summary.json` records case receipts and hashes. `snapshot_provenance.json` records the source archive and every initial file SHA-256. `git_blob_verification.json` records the post-test Git identities. `inventory.json` independently enumerates the production optional goals. `delta_verification.json` confirms the protected actor, movement, simulation, demo-controller and campaign-layout paths are unchanged from b2e7f35. The accepted QA observer and runner are unchanged. Engine provenance is included.

`optional-audit-bf3ebd3.tar.gz` contains per-case reports, receipts, logs, QA sources and an embedded size/SHA-256 manifest. `archive_verification.json` records an independent reread of every archive payload member. `SHA256SUMS` indexes this compact directory. Prior 01105eb and b2e7f35 evidence is preserved unchanged.

## Scope limits

Routes use explicit initial district/lens/sight fixtures. Lifecycle checks additionally use an initial local spawn fixture. Measured traversal uses normal production movement/combat inputs and E/Q/menu events, with live damage, enemies and collisions; no measured position, velocity, health, enemy, objective or gate writes occur. These isolated routes do not prove an uninterrupted all-collectibles campaign, exhaustive inherited caches/archives, a preceding Exchange traversal, physical controller hardware, native rendering/audio, Windows hardware or first-play human duration. Default-controller behavior is not inferred from these input-override route tests.
