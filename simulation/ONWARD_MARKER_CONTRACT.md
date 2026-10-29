# Placeable onward / LIFT marker

`simulation/world/onward_marker.tscn` is a bottom-center Node2D placement root.
It composes separate paint (`demo/views/onward_marker_view.gd`), an isolated
appearance resource, and the existing enabled `GateContour` StaticBody2D.
The authored 40 × 76 rectangle is centered at local (0, -38), layer 0/mask 0.
It contributes real collision-derived sonar geometry but never blocks an actor.
It is not a relay/freight shutter and has no trigger or completion authority.

## Explicit inputs and ownership

- `position` / ordinary Node2D transforms place the marker.
- `is_open` changes only paint between closed and open ink.
- `ending` selects ONWARD or LIFT (both labels configurable in appearance).
- `appearance` configures fill, ink, labels, font and font size. Scene defaults
  are local resources. Explicit assignment of the same resource intentionally
  shares paint; `duplicate(true)` isolates caller-supplied resources.
- `raster_reference` is the fixed authored draw-space origin. Production sets
  it once to the original gate position. Moving/reparenting the marker does
  not update it. This preserves original draw arithmetic, including font
  rasterization; geometric equivalence alone is not a pixel-parity proof.
- Hidden or null paint does not remove the sonar contour. This is the original
  geometry collector's behavior, not a physical-acoustics visibility model.

The root forwards state to the view synchronously. No mission reference,
autoload, actor lookup, noise emission, input handling or clock is required.
The contour shape is local to each scene instance; its fixed authored size is
not an exposed gameplay/appearance size control in this bounded extraction.

`mission_room.gd` owns placement and publishes `gate_open` presentation input.
The marker is appended where the old gate contour was visited and drawn behind
the parent after backdrop/floor/platform/sign children. Existing parent paint
for Exchange, relays and caches stays above it. Mission orchestration remains
byte-identical: gate predicate, strict distance < 65 E check, relay/freight/enemy
requirements, notices, sector transitions, metrics and final completion.

## Verification

- `onward_marker_regression.gd`: all eight production rooms, ordered physics and
  actual sonar geometry; real pulse timing/alpha/expiry; resource isolation,
  parent transforms, detach/readd, save/reload, true nonblocking actor passage,
  strict E boundaries and mission ending integration fixtures, at 60/120 Hz.
- `onward_marker_pixels.tscn`: native renderer only, frozen full-room and focused
  crops against archived signs-baseline room, real gate-local sonar pulses,
  overlap ordering, authored raster references, live paint independence.
- `onward_marker_isolation.py`: fresh minimal project, only four production
  asset dependencies, no mission or NoiseBus/autoload.
- `onward_marker_preservation.py`: complete accepted signs archive union;
  baseline ZIP hashes and all prior files/evidence remain protected.
- `run_onward_marker_acceptance.py`: new evidence namespace, prior reports
  backed up on workspace disk and restored, all prior broad regressions,
  frozen source and native-pixel manifest agreement.

Direct-state fixtures and frozen images are not gameplay routes. Full retained
and sacrificed-sight routes remain separate end-to-end gates. Native results,
aggregate status and packaging are reported only after execution.
