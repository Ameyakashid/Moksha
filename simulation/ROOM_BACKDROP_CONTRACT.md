# Reusable room backdrop: first decorative extraction

`demo/views/room_backdrop.tscn` is the actual optional view composed by every
production mission room. It contains only the existing background fill,
skyline, windows, vertical/horizontal pipes and rain. Floor/platform/sign,
gate/Exchange/relay/cache and HUD drawing remain with their existing owners.
There is no new campaign content, layout, collision or gameplay tuning.

## Composition

The view is an ordinary Node2D, behind its parent's drawing at relative z=0.
It inherits native transform, visibility, modulate and processing mode. It
contains no collider, sonar geometry, world/host lookup, noise source, Health,
actor logic or progression state. Parent self_modulate/material are separate
Godot properties; arbitrary shader/self-modulation inheritance is not promised.
The existing sonar layer-20 blackout still covers the world, including this view.
Mission/room BoundaryScope roots and the separate BoundaryHazard are unchanged.

`RoomBackdropProfile` contains local `room_bounds`, `theme` and `visual_seed`.
The bounds' bottom edge is the floor baseline. Drawing intentionally overscans
those bounds, including skyline silhouettes beyond the background fill.
Production bounds are Rect2(0, top, width, 300-top). The offset
(bounds.x, bounds.end.y-300) and adjusted top preserve the original coordinates.
Zero offset does not install a draw transform. Rain keeps the original 285px
band, speeds, fmod, counts, colors and widths. Seed zero is exact authored art;
nonzero seeds phase skyline heights and rain positions, repeating modulo 160.
Bounds must have finite position/size/end and positive width/height.

The view has `profile`, `automatic_animation` and
`set_animation_time(seconds)`. Time belongs to the instance, not the Resource;
manual finite time is absolute and can rewind. Scene-owned profiles are local to
each instance. Shared profiles may intentionally share configuration without
sharing clocks; use a separate profile for independent configuration changes.

Mission creates a profile, disables automatic animation before adding the child,
and supplies its existing room.time initially and after every process increment.
Standalone instances self-animate by default. Inherited pause/disabled processing
freezes that clock; resume does not catch up elapsed paused time. Profile changes
request redraws and replacing the profile retires the old changed connection.

## Evidence and running

- `simulation/room_backdrop_review.tscn`: native live standalone repeated/rotated/
  scaled instances and translated local bounds. Space freezes rain, H hides the
  first view, R resets clocks. This scene contains real views, not screenshots.
- `simulation/room_backdrop_pixels.tscn`: native archive-backed paired SubViewport
  exact-image comparison. These are frozen presentation snapshots, not gameplay,
  physics simulation or route proof. Headless rendering explicitly does not run
  this pixel gate. Both sides use matched viewport/camera/filter/environment
  settings, exact old room script bytes and the new production room composition.
- `simulation/tests/room_backdrop_regression.gd -- --hz=60` (repeat at 120): actual
  scene topology, resource/clock isolation, visibility, process pause and mission
  replacement checks. Direct fixture configuration is labelled.
- `python3 simulation/tests/run_room_backdrop_acceptance.py`: existing 72-stage
  foundation, focused tests at both rates, showcase boot, stock, held, four
  Health/Defeat/shield suites at both rates, historical aggregate and four routes.
  Prior reports are restored; current copies live in `room_backdrop_gates/`.
  Native pixel evidence must match the complete frozen source set.

The old room bytes are preserved directly from the immutable consolidated
boundary checkpoint ZIP (SHA-256
27596040947c6fca60e6fbfab369dab70001cce90b11b578cb909c72a41f4b24).
The exact member, retained bytes and hash are in
`evidence/room_backdrop_baseline/provenance.json`.
Only completed evidence in the final acceptance index establishes a pass; this
contract describes the intended gates and does not predeclare their result.
