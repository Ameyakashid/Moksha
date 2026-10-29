# Supplemental independent route-planner review

Decision: PASS for the bounded generic test-bot correction. This includes static/scope review and independent inspection of the diagnosis worker's final eight-route matrix, raw reports, clean logs and source hashes. The parent's final aggregate remains a separate gate.

Applied and reviewed bot SHA-256:
34dd74689b4f056be6fda72f7921400fbb06560b006876e56b4878e93b4e1570

The applied file exactly matches the reviewed candidate. Comparison against the immutable Shared-Counter archive confirms every byte outside `build_navigation` remains unchanged. The only behavior changes are ladder-link eligibility and diagnostic events.

## Why the correction is sound

- A possible boarding surface must lie within the actual ladder's vertical span. The destination remains its actual top; the previous horizontal span tolerances remain unchanged.
- The ascent corridor uses the current PC profile's body width, standing height and collision margin. Its lower edge ends just above the source support, so an actual supporting block is not mistaken for an obstruction above the feet.
- A solid intersecting that corridor rejects the ladder edge. Thin authored platforms are excluded because `mission_room.gd` actually creates them as one-way geometry. Freight and closed-shutter rectangles remain blockers regardless of thickness.
- There are no sector-specific, enemy-specific or coordinate-specific branches. No controller, collision, geometry, health, AI, gate, timing limit or pass criterion changes are present. Inputs still pass through the existing raw-input route and actual physics.
- Rejection and intermediate-boarding events retain the observed source/destination surfaces, corridor and blockers, making the planner decision inspectable.

This remains a layout-aware heuristic, not a complete navigation or swept-path proof. Physical alignment, support, climbing and collisions remain decisive.

## Unchanged geometry and controller

Independently compared byte-for-byte with the immutable Shared-Counter archive:

1. demo/mission_data.gd
2. demo/components/mission_room.gd
3. combat_pc/player.gd
4. combat_pc/player.tscn
5. combat_pc/components/climbable.gd
6. combat_pc/resources/air_response_agile.tres
7. combat_pc/resources/movement_profile.gd
8. combat_pc/resources/combat_profile.tres

All eight match. Exact hashes are in `planner_frozen_geometry.json`.

## Authored human-access limitation

The sector-2 ladder axis is x=1540, from floor y=300 to top y=0. The unchanged solid block occupies x=1300..1540, y=230..300. A standing PC centered on the ladder axis at floor height overlaps that block. Approaching from the right at floor level therefore stops at about x=1548 and cannot align to the ladder.

The diagnosis worker's explicitly labelled floor-start fixtures reproduce nine `alignment_blocked` events on both the immutable baseline and migrated version. Both identify the same layer-1 StaticBody2D rectangle, PC width 16, collision mask 1, collision travel/remainder, and final position (1548, 299.98). These are initial-placement diagnostic fixtures, not complete route evidence. Their logs include font-cache warnings; no visual/audio conclusions are drawn.

The reachable block top at y=230 provides valid intermediate boarding. Independently inspected exploratory actual-input evidence shows attachment at (1528.458, 229.98) followed by the real top exit at (1540, -0.02). The migrated 60 Hz retained-sight exploratory route completed all eight sectors in 174.53 simulated active seconds with zero deaths/retries; the unmodified baseline route completed in 150.02 seconds and did not use this ladder in sector 2.

The planner correction acknowledges the existing obstruction and chooses valid boarding. It does not make floor-level entry available, alter level geometry, claim improved human signposting, or establish a human completion duration. The lower drawn ladder segment may still suggest access from the floor; that pre-existing presentation issue is outside the authorized correction.

## Final corrected-planner route matrix

Independently inspected all eight final raw JSON reports and engine logs from `final-evidence`, rather than relying only on the worker's summary. All 27 entries in its SHA-256 manifest match. All routes completed eight sectors with zero deaths, retries, failures, engine errors or engine warnings. The per-route and cross-matrix source-change lists are empty. Current applied planner SHA-256 still matches the reviewed candidate.

| Version | Physics | Sight | Simulated active seconds |
| --- | ---: | --- | ---: |
| Migrated sentinel | 60 Hz | Retained | 174.56667 |
| Migrated sentinel | 60 Hz | Sacrificed | 162.78333 |
| Migrated sentinel | 120 Hz | Retained | 161.15000 |
| Migrated sentinel | 120 Hz | Sacrificed | 150.80000 |
| Shared-Counter baseline | 60 Hz | Retained | 170.03333 |
| Shared-Counter baseline | 60 Hz | Sacrificed | 160.10000 |
| Shared-Counter baseline | 120 Hz | Retained | 168.54167 |
| Shared-Counter baseline | 120 Hz | Sacrificed | 165.26667 |

Every final report includes the sector-2 floor corridor rejected against the unchanged block, the accepted intermediate block-top boarding edge, actual `climb_attached` around y=229.98, and actual `climb_detached` with `top_exit` at x=1540. This establishes that the chosen route works through ordinary production movement rather than a simulated navigation success alone. Both versions use the identical corrected generic planner. These timings are bot-active simulation measurements, not human-duration evidence.

The reviewer performed evidence inspection and exact hash/scope checks, not a second execution of those eight Godot runs. The earlier initial-placement floor fixtures and exploratory routes remain separately labelled diagnostic evidence.

## Evidence

- `planner_exact_delta.patch`: exact archive-to-applied bot delta.
- `planner_supplement.json`: review status, source identity and inspected runtime evidence.
- `planner_matrix_independent_check.json`: independently checked final matrix fields and actual ladder events.
- `verify_planner_matrix.py`: reproducible evidence-validation script.
- `planner_frozen_geometry.json`: eight frozen-asset hashes.
- Diagnosis worker artifacts: `/tmp/moksha-ladder-diagnosis/`, including the two floor fixtures, candidate and route comparison matrix.

No production source edits or new Godot runs were performed by this supplemental reviewer. The corrected eight-route matrix is now checked; the parent's source-stable full aggregate remains its separate acceptance gate. Exploratory results do not replace that gate.
