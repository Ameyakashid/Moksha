# Optional objective repeat acceptance

**PASS on exact committed runtime `b2e7f352b96b11e9a5137145416ddeaf4a974e27`.** No production edits, QA overlays or new blocking defect were needed.

## Results

- 24/24 baseline district routes passed at 60 Hz with neutral lens and retained sight. All 34 optional campaign objectives, all 31 reward IDs, and 111 total objectives across those districts were observed, followed by each district exit.
- 12/12 focused district routes passed at 120 Hz: City Records, Stamping Galleries, Waterline Clinic, Evacuation Spine, Listening Floor and Crown Ascent, each with retained and traded sight.
- All 40 real reward collections passed at 60/120 Hz. Three physical plates and the Foundry agility recovery were each collected initially, after two R retries, after title Continue, and after a fresh host loaded the real checkpoint. Bonuses remained exactly one-time: +8% base strike, +3% base run, or +5 capacity. Live pickup did not heal.
- Six runner guard tests passed. The clean import and all 40 engine cases reported no engine errors. Start/end source checks and final post-suite verification passed.

## Exact source verification

The project was extracted directly from `git archive` at the full commit above. Its QA observers were already committed; no files were overlaid.

All **2,724 archived files matched their exact Git blob IDs**, and every archived file remained byte-identical after execution. The protected actor, movement, simulation, demo-controller and campaign-layout paths also had no changes from the previous `01105eb` baseline. Engine version and executable SHA-256 are recorded in `engine_provenance_verified.json`.

The previous evidence archive remains unchanged, verified against its recorded SHA-256. Earlier reports are historical baseline evidence; they were not overwritten or substituted for this repeat.

## Records

- `final_summary.json`: final acceptance, exact commit, source checks and case references.
- `baseline-final/summary.json`: 24 routes and four lifecycle cases.
- `focused-120-final/summary.json`: 12 high-rate/sight cases.
- `git_blob_verification.json`: exact committed blob identities.
- `snapshot_provenance.json`: archive SHA-256 and tracked-file hashes.
- `delta_verification.json`: unchanged protected paths since the prior baseline.
- `inventory.json`: independent optional-objective inventory.

Reproduction is documented in the committed `campaign/quality/nov6_optional/README.md` and `run.py`. All output directories must be new; each case uses separate HOME/XDG storage.

## Limits

Routes use explicit initial district/lens/sight fixtures. Lifecycle cases additionally use an initial pocket spawn. All measured actions use normal production inputs; player position, velocity, health, enemies, collisions, objectives and gates are not written during measured play. This is not an uninterrupted all-collectibles campaign or exhaustive inherited field-cache/archive collection. Native rendering, audible output, controller/Windows hardware and first-play human duration remain separate validation. The requested human pacing target is not inferred from bot time.
