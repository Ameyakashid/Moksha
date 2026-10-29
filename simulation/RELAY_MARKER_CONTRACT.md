# Placeable relay presentation and contour

`simulation/world/relay_marker.tscn` is a bottom-center Node2D placement root.
Its separate view and appearance preserve the outlined rectangle, filled circle
and caption. Its enabled RelayContour is 22 × 31 at local (0, -15.5), collision
layer 0/mask 0, with no groups. It supplies actual collision-derived sonar geometry
without blocking actors/cargo, emitting noise or choosing a mission outcome.

This is presentation plus contour, not a reusable relay interaction mechanic.
Unchanged mission orchestration owns strict E distance < 45, first inactive
point, exact room-sourced prop_impact at authored point - (0, 20), loudness 1.4,
matching shutters, global relay completion, gate eligibility and retry reset.
Production has eight relay placements. No new level, object or outcome is added.

## Inputs and ownership

- Root `is_active` changes paint only. Appearance configures inactive/active ink,
  caption, font and size; local appearance/shape resources isolate instances.
  Explicit shared assignment intentionally shares paint; deep copies isolate it.
- Replacing appearance/font resources disconnects retired redraw subscriptions.
- Fixed `raster_reference` preserves authored p-plus-offset drawing arithmetic
  through inverse draw translation. Fractional/negative anchors, subsequent
  movement, nested and root transforms do not recompute the original raster phase.
- Hidden markers, null appearance and removed optional View retain the contour.
  Normal removal/deletion retires it. No mission or NoiseBus is required standalone.
- Root insertion retains station → singular relay → cache → plural relays → onward
  traversal. Paint-index order remains plural relays followed by singular relay.
  The two are deliberately distinct; production keys do not mix, but fixtures do.
- Mission-only relative depths are backdrop -7; floor/platform -6; signs -5;
  onward -4; station -3; plural relay -2; singular relay -1; parent cache and
  dynamic children 0. Standalone assets retain their ordinary zero-depth default.
  No sonar sorting, copied fake geometry or view reparenting is introduced.
- Room state is `relay_on OR activated_relays.has(paint_index)`. Setters forward
  assignments; each process tick and manual queued redraw also synchronize
  in-place append/erase/clear and aliased edits. Frozen snapshots can explicitly
  call room `_process(0)` or queue a redraw. The marker owns no activation array.
- Mission `_relay_points` still prefers the plural key exclusively when present,
  even though mixed-key paint draws both. This pre-existing distinction is kept.

## Verification boundary

Focused 60/120 Hz checks exercise all production placements and mixed keys,
ordered physical/sonar topology, production pulse timing/alpha/expiry, mutable
state, isolated styles, resources/fonts, transforms, lifecycle, serialization,
removed optional views and actual shared-actor/production-shared-cargo nonblocking passage (gravity-free
configured cargo fixture, real solver).
Direct-state mission checks cover activation, noise, shutters, enemy lock, retry,
first-inactive priority and mixed-key objective selection. They are separate
from the unchanged full retained/traded 60/120 Hz input-driven route gate.

Native frozen matrix: 96 full-room pairs, 16 relay-focused pairs, eight layered
mixed-key overlaps, ten aliased-state snapshots, 24 authored-anchor transforms,
ten style references and four nonzero-depth dynamic-child overlaps: 168 exact
pairs plus 14 peer/isolation checks. Quiet blackout must be black; ordinary and
pulse images must contain content. Archive/runtime-generated oracles compile
in headless preflight before native use. A clean isolated project copies only
four dependencies with no autoload. Native results do not claim a full human
campaign playthrough or new acoustic physics.

The aggregate runner preserves/restores historical evidence on workspace disk,
retains all earlier suites and route timeout/outcome requirements, then verifies
the complete immutable Exchange split archive union against a narrow allowlist.
Success is claimed only after native and aggregate execution on frozen sources.

## Preserved route-planner failure and bounded recovery

The first full aggregate passed 34 of 35 groups. Its unseeded 60 Hz retained
Freight route stopped at an existing neutral steering dead zone. The delivered
cargo had a tiny rotation: the actual floor sweep stopped the actor at a corner,
but its support-anchor ray saw the steep side face, so the motor correctly did
not admit grounding. This sector has no relay markers. Diagnostic copies of the
immutable Exchange baseline and candidate produced identical 121 core trace
samples, including the same stall, when the observed launch-spin scalar was
configured before a genuine strike. Ordinary seeded runs also matched.

A separate generic testbot contact helper now requires prolonged stagnation,
stationary nongrounded locomotion, a lower waypoint within the existing
horizontal dead zone, and a live walkable off-center physical down-probe hit.
It requests ordinary lateral input away from that contact. It changes no
production motor, support or completion policy, collision, timeout, route,
launch, damage, or receiver outcome. The existing ledge helper and waypoint
predicates remain unchanged. The helper is consulted only outside combat and
ladder navigation. Matched baseline/candidate diagnostic routes then finish
Freight in 16.55 seconds under the same 60-second limit.

The focused contact regression uses a generic initially rotated static obstacle
and the actual shared actor. Ordinary gravity reproduces the stationary contact;
helper-selected raw inputs reach the real lower floor at 60 and 120 Hz. Negative
controls cover short stagnation, absent/central contact, moving/grounded/other
action, and above/near/far waypoints. Predicate-only state probes are explicitly
labelled, restored before physics, and separate from physical escape results.
The first mirror fixture failed because its contact was actually grounded;
that failed harness and all first-aggregate/native evidence remain archived.
