# Five Ascents delivery

## Playable Windows package

`MOKSHA-Windows-x64-4ea2c11.zip` contains a real64-bit Windows release export from gameplay/source commit `4ea2c1102466aabd9d8cf93a01be24139970363d`. Extract the whole archive and run `MOKSHA-Windows/Run-MOKSHA.cmd` or `MOKSHA.exe`; keep the PCK beside it. Engine templates were verified against official release hashes; engine/project/font/Beehave licenses are included. Exported-pack smoke passed on Linux/headless. Native Windows execution/pixels were not verified.

Later source commits may add final reports and documentation; gameplay bytes must remain identical to the Windows build commit. Exact archive hashes live in the final delivery manifest, not this descriptive file.

## Source project

The source ZIP contains the editable Godot4.6.3 project,32 districts across five levels, separate gameplay/art/layout modules, reusable scenes and editor workbench, original preserved demo, tests, current verification evidence, licenses and a compact git history bundle. It excludes `.godot`, the live `.git` directory, temporary caches and the large export-template downloads.

- Root `README.md`: controls, levels, builds, checkpoint semantics.
- `campaign/docs/EDITOR_WORKFLOW.md`: modular scene/layout authoring.
- `campaign/docs/LOCAL_PLAYTEST.md`: local launch, save folder and honest real pacing notes.
- `campaign/docs/VERIFICATION.md`: exact acceptance categories and limits.
- `campaign/docs/REUSE.md`: actual external code reuse and licensing, distinguished from researched-only tools.
- `campaign/tests/`, `campaign/qa_audit/`, `campaign/enemy_tests/`, `campaign/route_tests/final/`, `campaign/route_tests_45/final/`: focused and input-route evidence. Historical failures remain labelled separately.
- `simulation/evidence/foundation_report.json`: corrected72-stage inherited aggregate.

Requested15–20minutes per level remains **unverified human duration**. Bot times are reported without a multiplier. No result claims native visual/game-feel or audible-mix approval.

The original Oct23 delivery notes are preserved in `docs/OCT23_DELIVERY_CONTENTS.md`; they describe the older demo, not this entry scene.
