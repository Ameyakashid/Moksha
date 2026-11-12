# Crown Continue proof (d807d68)

This is QA tooling and evidence, not game implementation. Tested source was d807d68ed6e4288bf45fbc320b420b12cfb7ae69. No production changes are included. Every accepted run preserved all 4,360 tracked source hashes.

Final footage: a fresh native Linux automated Continue run, 640x360, 60 Hz simulation, 1x playback, 30 fps delivery. Whole 16,171-frame raw movie is 269.5167 seconds; encoded 8,086-frame timeline is covered contiguously by three playable parts. Movie Maker stereo PCM was retained as AAC; signal and mux duration checked, no audible-mix claim. Seven new Crown district receipts plus natural public_record ending, zero deaths. The earlier 311.7667-second native attempt is incomplete and is not spliced into this video.

## Reproduce
Requires Git, Godot 4.6.3 (matching recorded environment), Python 3, ffmpeg/ffprobe, and a real native display for the movie. Verify your local Godot version. Paths below are examples: use absolute fresh output paths outside source. Do not use player save directories.

1. Make separate detached source worktrees at the exact tested commit for producer and native recording. Keep this evidence directory external to them. Import normally using the generated launcher.
2. `python3 tools/workflow.py prepare --mode producer --source /absolute/producer-source --commit d807d68ed6e4288bf45fbc320b420b12cfb7ae69 --output /absolute/fresh-producer`
3. `sh /absolute/fresh-producer/launch.sh`, then `python3 tools/workflow.py verify --output /absolute/fresh-producer`. A new full normal-title campaign generates its own checkpoint. Do not hand-edit it.
4. `python3 tools/workflow.py prepare --mode continue --source /absolute/native-source --commit d807d68ed6e4288bf45fbc320b420b12cfb7ae69 --output /absolute/fresh-native --producer /absolute/fresh-producer`
5. Launch that generated shell script from a native desktop Terminal; then run `python3 tools/workflow.py verify --output /absolute/fresh-native`.
6. `python3 tools/encode_full_crown.py /absolute/fresh-native`. This preserves full chronology and splits only for attachment size. No benchmark claim under shared CPU load.

Optionally add `--headless-check` at step4 with its own dedicated copy/output before the native run. Exact tools are archived unchanged; attempts index binds each receipt to its own observer/workflow bytes. Re-running producer with the final observer uses the corrected egress and is not represented as byte-identical historical producer02 automation.

## Checkpoint semantics and failed attempts
Production saves at natural district entry. Continue restores prior25 metrics, four level receipts/upgrades and normal saved progression, then builds Crown entry normally. The game does not serialize live room goals, current health or position. Normal Continue reconstruction is not an observer health reset.

Producer01 was stopped for a QA comparator bug: JSON integer/float shape broke exact nested equality. Producer02 uses strict structural comparison, exact integers and narrowly bounded 1e-9 float tolerance; ten negative/positive controls are archived. Native01 subsequently stalled because inherited goal navigation overwrote its basin approach target. Only the external observer was corrected: bounded ordinary inputs move to supported basin footing and jump to a grounded east exit. Corrected headless and native02 independently observed both. No position, health, goals, checkpoint or production geometry was edited to pass.

## Scope and limitations
This is automated Linux input proof, not manual play or Windows runtime proof. Sample frames from all seven districts, basin support, grounded exit and ending were visually reviewed; not every frame was human-inspected. Wide completion captions in d807 remain visible; later caption work is separate. No human difficulty/pacing or audible mix claim.

Historical JSON copies replace the machine-specific workspace root with `$EVIDENCE_ROOT`; originals remain preserved separately. `attempts.json` contains original and archived digests. Scripts are exact original bytes. Raw AVIs and movie files are retained outside Git; media hashes and frame intervals are archived. Receipt history contains 32 total districts but only seven new objective receipts in Continue, correctly distinguished from producer's32 new receipts.
