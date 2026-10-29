# Placeable Exchange station presentation and contour

`simulation/world/exchange_station.tscn` is a bottom-center Node2D placement
root. Its separate view and appearance preserve the original outlined station,
eye symbol and caption. Its enabled StationContour is a 32 × 42 rectangle at
local (0, -21), collision layer 0/mask 0. It supplies actual collision-derived
sonar geometry without blocking actors or cargo, emitting noise or role checks.

This is **presentation plus contour**, not a reusable sight-trade mechanic.
Unchanged mission orchestration owns strict distance < 45, E eligibility,
paused choice, J acceptance/K or Escape refusal, health refill, speed/roll,
player-sourced noise and persistence. Authored station positions stay (430, 300)
and (1250, 300). No spent/active paint state existed, so none was invented.

## Inputs and ownership

Root transforms place view and contour together. Appearance configures outline,
eye/caption ink, caption, font and size. Defaults and shapes are local resources;
explicit shared assignment intentionally shares paint, while `duplicate(true)`
isolates it. Replacing resources disconnects retired redraw/font subscriptions.
`raster_reference` is a fixed original drawing origin. Each primitive preserves
authored p-plus-offset arithmetic under inverse draw translation. Movement does
not change raster phase. Visibility, null appearance and optional view removal
affect paint only, not the contour. Detach/delete retires the contour normally.
Standalone defaults require no mission or NoiseBus and use ordinary Node2D depth.

The room keeps station at the original contour traversal slot and onward last.
Only mission composition sets relative z depths: backdrop -5; floor/platform -4
(same-depth authored sibling order); signs -3; onward -2; station -1; original
relay/cache parent and dynamic children 0. Asset defaults stay unchanged. No
fake contour, sonar sorting or view reparenting is used. Standard room transforms
and nonzero room depth are tested; arbitrary caller top-level/nonrelative-z
changes do not promise preservation of earlier authored composition.

## Acceptance

- Focused 60/120 Hz checks: eight-room ordered physical/sonar topology, actual
  pulse alpha/timing/expiry, isolated configuration, transforms, lifecycle,
  serialization and real nonblocking shared-actor/rigid-cargo passage.
- Both-station direct-state mission contracts remain separate from full
  retained/sacrificed 60/120 Hz input-driven route gates.
- Native frozen image matrix: 96 full-room pairs, 4 station-focused pairs,
  8 layered overlaps, 24 fractional/negative anchor transformations,
  10 custom-style references and 4 nonzero-depth dynamic-child overlaps.
  Total 146 exact pairs plus 12 target/peer raster-isolation checks. Quiet
  blackout must be black; normal and pulse images must contain content.
- Generated archived/style oracles compile and instantiate before native work.
- Clean isolated project copies only four asset dependencies, without autoloads.
- Aggregate runner backs up/restores old evidence on workspace disk, reruns
  all prior broad suites and verifies the immutable onward archive union.

Native and aggregate acceptance are claimed only after execution against the
final source manifest. Sonar remains established stylized visualization, not
new acoustic occlusion/reflection or fully physical sensing.
