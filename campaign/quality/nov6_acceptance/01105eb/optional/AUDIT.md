# Optional campaign objective audit

**PASS on immutable production commit `01105eb5f5e683297366e2c1f37c891b207c511f`.** No production change was needed for the optional routes or reward lifecycle tested here.

## Verified coverage

- **24/24 district-start routes at 60 Hz, neutral lens, retained sight.** Every one of the 34 authored optional campaign objectives and all 31 augment receipts was collected. Across those districts, 111 required and optional objectives were observed, and each district exit was reached.
- **12/12 focused routes at 120 Hz.** City Records, Stamping Galleries, Waterline Clinic, Evacuation Spine, Listening Floor and Crown Ascent each passed with retained and traded sight.
- **40 real reward collections across 60/120 Hz.** All three physical crate plates and the Foundry agility recovery were collected initially, after two ordinary retries, after title Continue, and after a fresh host loaded the genuine saved checkpoint. Force remained +8% of base damage, agility remained +3% of base run speed, and vitality remained +5 capacity. Recollection did not stack. Live collection did not heal; ordinary checkpoint refill remained intact.
- **Six runner guard tests** passed, including rejection of an engine error with exit zero, missing or failed reports, nonzero exit, and source drift after report creation.
- The complete Evacuation Spine route recovered the keys and western refuge through actual inputs. Its sampled trace includes floor-level travel through the opened underpass in both directions.

## Source and execution identity

The project was created with `git archive` from the exact commit above. Only the new `campaign/quality/nov6_optional` QA directory was added. Post-suite verification found **all 2,538 archived files byte-identical**, including production code, assets and licenses. The suite uses Godot `4.6.3.stable.official.7d41c59c4`; executable and archive SHA-256 receipts are recorded.

All 40 final engine cases have clean exit, no engine errors, matching start/end source hashes, matching report hashes, and a second source verification after the whole suite. The initial editor import lacked isolated config/cache directories; that setup error is retained, and the corrected fully isolated import was clean. It did not modify tracked production files.

Primary records:

- `final_summary.json`: complete post-suite acceptance and case references.
- `baseline-final/summary.json`: 24 route cases plus four lifecycle cases.
- `focused-120-final/summary.json`: 12 high-rate/sight cases.
- `snapshot_provenance.json`: archived file hashes and exact commit.
- `engine_provenance_verified.json`: engine identity.
- `inventory.json`: independent production enumeration of the 34 optional objectives.

## Diagnostic history

The sibling `historical_index.json` preserves 81 earlier reports with hashes. Some initial observer routes made poor choices: they pushed spare cargo away before collecting a plate, oscillated on a low plinth, repeatedly attempted a long jump instead of using an existing ladder, or chose energized floor strips instead of the upper baffles. Only ordinary input planning was corrected. Other runs were correctly rejected when unrelated QA files or the final production cache-cleanup revision changed during measurement. None of those failures was silently converted to a pass or removed.

## Reproduction and limits

See the QA directory's README and `run.py`. Every run requires a new evidence directory and receives separate HOME/XDG storage. The baseline command is:

```sh
python3 campaign/quality/nov6_optional/run.py --kind all --workers 2 \
  --seconds 240 --output /absolute/path/to/NEW-baseline-directory
```

The focused command is:

```sh
python3 campaign/quality/nov6_optional/run.py --kind routes --workers 2 \
  --district city_records --district l2_stamping_galleries \
  --district l3_water_clinic --district city_evac_spine \
  --district works_baffle_hall --district crown_ascent \
  --hz 120 --sight both --seconds 240 \
  --output /absolute/path/to/NEW-focused-directory
```

Each route begins with an explicit district/lens/sight fixture. The lifecycle cases additionally use an initial pocket spawn. Measured play does not write player position, velocity, health, enemy state, collision, goals or gates. Initial local fixtures are not claims of reaching that pocket from the campaign title. This is not an uninterrupted all-collectibles campaign, exhaustive inherited field-cache/archive collection, native rendering/audio/hardware validation, or a human playtime estimate. The 15–20-minute-per-level target remains unvalidated human pacing.
