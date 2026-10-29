# Verification data

The runnable project contains the executable regression scripts and acceptance reports. Generated test JSON, per-tick traces and code-drawn pose previews are separate downloads:

- `MOKSHA-PC-Verification-Traces.zip`: the movement, combat, drop/dive, climb and wall checkpoints through M5
- `MOKSHA-PC-Landing-Verification.zip`: the M6 landing tests, current compatibility runs, native captures and landing pose previews

Extract the evidence archive's `MOKSHA` folder beside the project so its files merge into `combat_pc/tests/` and `combat_pc/visuals/tests/`. The linked traces and preview images then resolve. The archives are optional for playing the project. Running the Godot harnesses regenerates current traces and pose samples; the rendering scripts remain in the project.

The report builders also check historical preservation. A complete archival re-audit needs the corresponding earlier datasets and original milestone/provisional snapshots. This is separate from running the portable actor's physics regressions. The delivered acceptance reports record the historical hashes already checked, including explicitly identified documentation-only updates.
