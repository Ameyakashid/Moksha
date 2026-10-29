# Surface Pulse — one optional review piece

M15 connects the approved PC noise route to the existing collision-contour solver.
It adds a small, independently placeable view, rather than changing the PC.
Open `combat_pc/surface_review.tscn` (the current F5 entry) to inspect it.

## What to inspect

Press **J once**. The floor receives a nearby contact first; white fragments then
travel away along its edge. The raised block receives its own later contact, with
fronts travelling around its corners. Wait: every surface fragment fades away.
Walk with **A/D**, jump onto the block with **Space**, and compare those genuine
footstep/landing origins with the weapon's origin. There is no periodic scan.

**E** disconnects/reconnects only the surface view. Noise count and PC movement
continue while its accepted-pulse count stops. Reconnection starts with fresh
events. **G** toggles clearly labelled static collision guides for comparison;
guides start off. **R** resets the review and its subscriptions; **Esc** freezes
the PC, pulse ages and pulse intake. Health and defeat remain separate children.

## Place it in another scene

Instance `components/surface_pulse.tscn` alongside the PC and a scene-local
`scripts/sensory/noise_bus.gd` node. Set Geometry Root Path to the host Node2D,
Excluded Actor Path to the PC inside that root, and Event Bus Path to that bus.
Point the independent NoiseRelay at the same bus. No autoload is required.

The public adapter operations are `bind_surface(world, actor, bus) -> bool`,
`unbind_surface()`, `enabled`, and `simulation_enabled`. A failed bind leaves
it unbound. Unbinding or disabling clears live traces and disconnects the exact
subscription. Rebinding resets event history/counts and invalidates callbacks
from earlier bindings. The host owns coordinated reset of actor, bus and view;
the four-argument bus does not transmit actor-reset generations.

The adapter consumes each valid delivery independently. It copies the supplied
world origin; it never polls the PC to invent noise or move its origin. Sources
must be live and inside the selected geometry root. Null, detached, queued and
foreign sources are rejected. Scene pause or simulation disable freezes ages
and rejects fresh events; paused events are not replayed. A source disappearing
after a real event does not undo the sound on surviving terrain.

`surface_pulse_default.tres` selects full-opacity surfaces using the existing
SonarTuning resource. It leaves the existing 550 px/s contact flight, 650 px/s
contour travel, finite semantic ranges, 0.095 s bright head and 0.53 s base trail
unchanged. These values are authored MOKSHA tuning, not recovered Dead Cells
constants. The base renderer, geometry extractor and tuning script remain
byte-identical to v18. The adapter deliberately skips their old autoload hookup
and suppresses blackout, body cues, origin marks, threat markers and labels.

## Scope and limits

Only sampled enabled collision edges are drawn. The PC subtree, Area2D triggers,
disabled colliders and `sonar_ignore` subtrees are excluded. Supported shapes,
transforms, moving-geometry schedules and finite caps are inherited from the
[existing sensory contract](../../scripts/sensory/README.md).

This is stylized distance plus contour travel. Separate colliders receive their
own nearest contact; they do not form a connected surface graph. Nearby geometry
behind another collider can receive a pulse. There is no acoustic occlusion,
reflection, diffraction or material simulation. Queued geometry disappears when
deferred deletion completes; disabling or detaching it removes it immediately.
Arbitrary runtime skew is outside this checkpoint's transform coverage.

The review's dark background and visible wireframe do not apply a blindness
state, sight sacrifice, audio playback, NPC sensing or progression. Those are
separate pieces. The previous noise, health and defeat reviews remain runnable.

Validation results are in `../tests/surface_report.md`; native evidence is in
`../NATIVE_CHECKPOINT.md` and the small companion verification archive.
