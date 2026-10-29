# M18 ground response: independent physical verification

PASS at 60 and 120 Hz using the final `ground_response_agile.tres` resource. The candidate reaches the same 218 px/s cap sooner, stops in roughly one-third less distance, and completes a full reversal in 83 ms instead of 133 ms. Left and right measurements agree.

## Measured response

| Measurement | Baseline 60 Hz | Candidate 60 Hz | Baseline 120 Hz | Candidate 120 Hz |
|---|---:|---:|---:|---:|
| Start to 218 px/s | 83.33 ms | 50.00 ms | 75.00 ms | 50.00 ms |
| Release to zero | 133.33 ms | 83.33 ms | 125.00 ms | 83.33 ms |
| Stopping distance | 11.04 px | 7.03 px | 11.94 px | 7.91 px |
| Reverse: first sample at/past zero | 66.67 ms | 50.00 ms | 66.67 ms | 41.67 ms |
| Reverse: reach opposite cap | 133.33 ms | 83.33 ms | 133.33 ms | 83.33 ms |

Times start at the first supplied input callback. Zero-crossing is the first sampled velocity at or past zero, so the exact crossing is within the preceding callback. Distances are actual engine world positions, not a formula. The small cross-rate distance differences are normal discrete integration; every measured timing differs by at most one 60 Hz callback.

## Coverage and scope

- 134 real-physics scenarios at each rate, consisting of paired baseline/candidate fixtures; zero failures
- Six repeated taps, analog strength changes, opposing inputs, rapid reversals, and parsed physical keyboard press/release in both directions
- Continuous half/one-gradient slopes, crests, valleys, separate-body seams, terminal-speed floor contact, exact full-body clearance, 4 px walls, low ceilings, and translating supports
- Run into jump, roll, and attack; slope actions; real one-way transitions; moving-support hitpause
- Candidate and baseline position/velocity/ownership traces match exactly in both directions for crouch, shield, attack, hurt, roll, and air. Attack comparison covers windup, active, and recovery. Roll comparison covers start, travel, and recovery. These intervals include direction changes and neutral input
- All unchanged health scenarios (25), defeat scenarios (23), and noise scenarios (28) pass with the candidate at each rate. New wrappers change output destinations and inject the candidate on actor construction; original assertions and helpers are reused
- 38 external report-to-report behavioral comparisons pass, including left/right symmetry, preserved cap, responsiveness improvement at each rate, bounded cross-rate variance, and retained integration

No assertions are multiplied per physics frame for a headline count. Every frame is observed for geometry and callback correctness, then summarized into behavior-level assertions. Original tests and reports were not edited.

## Baseline and source evidence

- The preserved v21 archive matches the SHA-256 pinned from the accepted delivery manifest (the manifest file is not required to run verification): `c93e187cdbf1a449227ae7d647ee84ead71e5d76f627a6b84ee43a91f8837d1f`
- 308 of 312 original code/resource/scene sources remain byte-identical, including the original movement profile resource, all old test scripts, health, defeat, noise, contact, NPC motor and surface sources
- The four authorized original source changes are three integration points (`combat_pc/player.gd`, `combat_pc/resources/movement_profile.gd`, and `combat_pc/visuals/wireframe.gd`) plus `combat_pc/reference/generate_parameter_ledger.py`, which includes the two new profile classes in the generated provenance ledger
- Per-source original and final SHA-256 values are in `ground_response_baseline_hashes.json`. All runtime hashes in the finished physical runs remained stable during the run

## Reproduce

The retained, unmodified v21 `MOKSHA-Two-Level-Project.zip` is required for archive/source verification. It is not duplicated inside this new project package. Any copy with the pinned v21 SHA-256 above is accepted; a newer project archive is not an interchangeable baseline.

From the project root, run:

`python3 combat_pc/tests/ground_response_run.py --baseline-zip /path/to/retained-v21/MOKSHA-Two-Level-Project.zip --godot-bin /path/to/godot`

Use Godot 4.6.3. Alternatively set `GODOT_BIN` to its executable path; if neither is supplied, the runner uses `godot` on PATH. The working environment's existing relative backup path remains the default for `--baseline-zip`.

To refresh only the source proof and cross-rate summary from the included physical reports:

`python3 combat_pc/tests/ground_response_run.py --evidence-only --baseline-zip /path/to/retained-v21/MOKSHA-Two-Level-Project.zip`

The verifier can also run independently: `python3 combat_pc/tests/ground_response_verify_baseline.py --baseline-zip /path/to/retained-v21/MOKSHA-Two-Level-Project.zip`

The runner invokes Godot 4.6.3 in real engine callbacks using `--fixed-fps` equal to the requested physics rate. It places Godot user/cache/config data in writable directories under the operating system temporary directory, writes only `ground_response_*` reports, checks diagnostics and source stability, then validates the frozen archive and cross-rate results.

Primary evidence: `ground_response_results_60hz.json`, `ground_response_results_120hz.json`, `ground_response_rate_comparison.json`, and the six `ground_response_{health,defeat,noise}_results_*hz.json` files. `ground_response_run.log` records the clean physical execution. `ground_response_portability.log` records the final archive and cross-rate refresh after the provenance-generator update; its 308/312 source count supersedes the earlier 309/312 count in the physical-run log. The physical suites were not rerun for this documentation/provenance change.

## Limits

This is headless physical acceptance, not a visual or subjective feel verdict. The review scene and native capture are reviewed separately. This work makes no exact numerical or executable parity claim to another game, and does not add mechanics. The baseline row uses the unchanged base profile through the current optional-resource integration; archive identity separately protects the accepted v21 source.
