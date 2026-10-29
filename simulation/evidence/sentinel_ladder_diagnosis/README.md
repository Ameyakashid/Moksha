# Sector 2 ladder route diagnosis

Result: all eight full mission routes pass with the same generic corrected planner across the migrated sentinel implementation and the immutable shared-counter baseline copy, at 60/120 Hz and both sight choices. All eight have zero deaths/retries, no reported or logged errors, and no source mutation during their run or matrix.

## Root cause

The authored ladder at x1540 spans floor y300 to top y0. Its lower 70 px overlaps the right boundary of solid terrain Rect2(1300,230,240,70) for a 16 px-wide standing player. The old planner connected only exact-bottom to exact-top, ignored this ascent obstruction, and routed a player already standing on the block top back down to the invalid floor entry. Changed combat trajectories exposed this pre-existing bad link.

An explicit floor-position diagnostic reproduced the same blocked physical collider, nine alignment_blocked events, and final position (1548,299.98) in both baseline and migrated versions. This diagnostic is distinct from full-route acceptance and is labeled accordingly. All AI remained active. The nine listed movement/controller/geometry/climb sources match the immutable archive byte for byte.

## Bounded correction

Only demo/tests/expanded_mission_route_bot.gd ladder-link generation and its evidence events change. Intermediate supported source heights within the actual ladder span may connect to its true top. A full standing-body ascent corridor, sized from the live movement profile, must clear solids. Authored one-way platforms retain their genuine upward pass behavior, while freight/shutter solids remain blockers. No game geometry, collision solver, combat, AI, timeouts, objectives, or pass conditions change.

## Measured full routes

- migrated_60hz_retained: 174.57s simulated active time; 8 sectors; 37 kills; zero deaths/retries/errors
- migrated_60hz_sacrificed: 162.78s simulated active time; 8 sectors; 38 kills; zero deaths/retries/errors
- migrated_120hz_retained: 161.15s simulated active time; 8 sectors; 38 kills; zero deaths/retries/errors
- migrated_120hz_sacrificed: 150.80s simulated active time; 8 sectors; 38 kills; zero deaths/retries/errors
- counter_baseline_60hz_retained: 170.03s simulated active time; 8 sectors; 41 kills; zero deaths/retries/errors
- counter_baseline_60hz_sacrificed: 160.10s simulated active time; 8 sectors; 41 kills; zero deaths/retries/errors
- counter_baseline_120hz_retained: 168.54s simulated active time; 8 sectors; 41 kills; zero deaths/retries/errors
- counter_baseline_120hz_sacrificed: 165.27s simulated active time; 8 sectors; 41 kills; zero deaths/retries/errors

All full reports record the rejected floor corridor and accepted block-top boarding edge. Real climb_attached/top_exit events establish ordinary input-driven use of the alternative path.

## Remaining authored-layout caveat

The visible ladder guide and sensor still reach the floor even though the lowest 70 px cannot be boarded from there. A human must board from the block top or use the alternative upper-platform route. This is an existing layout/affordance issue, left unchanged in this scoped planner correction.

## Provenance

matrix-summary.json records the exact planner SHA, all final outcomes, critical sector 2 events, and source stability. matrix-source-hashes.json contains both isolated snapshots. diagnosis.json records archive SHA, preserved-source comparisons, exact physical blocker evidence, and the remaining layout issue. The baseline copy differs from the archive in exactly the corrected planner source. The migrated snapshot differs from the parent’s later production source only in additional sentinel regression test coverage, not runtime code.

baseline-route-60.log is the successful unmodified baseline reproduction before planner correction; its resulting full report was subsequently replaced by the corrected matrix, so the immutable archive remains the original stored report source.

Exploratory first-pass logs with invalid-rectangle diagnostic warnings are deliberately excluded; all eight final matrix logs are clean.

The explicit-placement diagnostic source is retained as ladder_floor_fixture.gd.txt to avoid adding an executable project source. corrected_bot.gd.txt is the exact planner candidate used for all eight runs; planner.patch is its bounded delta.
