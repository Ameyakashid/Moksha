# Sonar subsystem verification

**Result:** 63 checks passed, 0 failed under Godot 4.6.3 stable official.
**Date:** 2026-10-02 UTC.
**Entry point:** `tests/sonar_regression.gd`.
**Machine-readable result:** `tests/sonar_report.json`.

## Coverage

- Invalid noise data is rejected and bounded histories retain total counts
- Two spaced origins retain independent ages, positions and arrival schedules
- Surfaces remain invisible until their noise arrives; empty space has no outline
- A white front reaches the near face, side and underside in sequence
- Initial contact reveals a fragment of a collider rather than its full outline
- Overlaps combine independently and clamp to white; silence fully expires them
- Rotated/scaled parent hierarchies preserve rectangle and capsule alignment
- Player geometry, disabled shapes, ignored subtrees and Area2D triggers are excluded
- Moving and rotating props carry highlights; old positions leave no outline
- Runtime shape edits rebuild contours; disabled/deleted props lose their tracks
- Foreign and null sources cannot reveal the current level
- Repeated mode toggles, idempotent mode calls, rebinding and freed levels stay clean
- Explicit simulation pause and SceneTree pause freeze ages and reject new events
- Geometry, pulse and history caps are enforced; resume expires noise normally
- Vertical Camera2D movement and zoom produce the expected world-to-screen transform
- The actual headless draw callback submits black cover, body cue and bounded fragments
- Quiet blind frames submit no world fragments; sighted frames submit no sonar commands
- Defaults retain a body cue, useful nearby tap range and short finite local trails
- Optimized render alpha matches independent per-pulse sampling through arrival and fade

## Measured behavior

| Measurement | Observed |
| --- | ---: |
| Near-origin arrival at test surface | 0.150 s |
| Spaced second-origin arrival at same surface | 0.612 s |
| Contact/top, side, underside arrival | 0.150 / 0.361 / 0.572 s |
| Longest segment under tested parent transforms | 5.816 world px |
| Camera vertical movement of -200 world px | +200 screen px |
| Tap range at actor loudness 1.1 | 426.865 world px |
| Enemy step range at actor loudness 0.8 | 251.513 world px |
| Prop break range at actor loudness 1.6 | 655.224 world px |
| Tap bright head plus local trail | 0.625 s |
| Maximum optimized/reference alpha difference | 0.000000147 |

The CPU stress fixture contains 1,680 geometry fragments and the full 18 pulse
budget. Its measured all-contour alpha evaluation fell from approximately
14.1 ms before hot-loop tuning to 2.5–2.9 ms after tuning in this environment.
Latest exact timings are in the JSON report; timings vary with machine load.
These are synthetic CPU measurements, not a promise of GPU frame rate.

## Limits of this report

The suite executes real Godot collision nodes, event delivery, canvas transforms
and draw callback branches, but headless rendering does not provide a visual
pixel inspection or human assessment of readability. Native visual testing,
two-level traversal, and real player/enemy/prop event generation are covered by
the broader gameplay/flow checks and manual integration verification. This
subsystem suite injects events through the production NoiseBus deliberately to
isolate timing and geometry correctness.

The effect is a distance-and-contour acoustic abstraction. It does not model
occlusion, reflection networks, diffraction or reverberation; see the sensory
README for the implementation's exact limits.
