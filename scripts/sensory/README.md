# MOKSHA sensory rendering

This subsystem turns discrete gameplay noise events into short, white highlights
that travel along actual collision surfaces. It does not add a permanent world
outline, periodic scan, player-centred reveal circle, or always-visible enemy
silhouette.

## Runtime contract

- `NoiseBus` is the autoload in `project.godot`.
- Actors call `NoiseBus.emit_noise(world_origin, kind, loudness, source_node)` at
  the moment the physical action happens. The origin is copied unchanged; it is
  never replaced with the player's position.
- `SonarView.bind_level(level, player)` selects the level and clears all prior
  events, pulses, tracks and geometry. A source must be a live node within that
  level, or the level itself. Null, queued-for-deletion and foreign-level sources
  are rejected. Every production emitter must pass its source node.
- `SonarView.set_blind(true)` places opaque black over the world. The layer is 20;
  the HUD should remain on a higher CanvasLayer. Changing the mode clears active
  pulses; calling it repeatedly with the same value preserves active pulses.
  Emit the station's sacrifice noise *after* entering blind mode.
- `SonarView.clear_pulses()` removes active visual noise without changing sight.
- Set `simulation_enabled = false` during menus, pause, failure and completion.
  Both event intake and simulation time freeze. SceneTree pause is also respected.
- `preview_when_sighted` defaults to `false`. The unpowered city uses normal
  vision with no sonar drawing. An explicitly enabled preview uses faint white
  highlights; it is optional debugging/design feedback, not a gameplay default.

Current actor event kinds include `weapon_tap`, `player_step`, `enemy_step`,
`prop_impact`, and `prop_break`. The renderer also accepts other named physical
events using a default profile. Event generation and audio playback belong to
the actor/gameplay systems; sonar only consumes their events.

## Travelling surfaces

Enabled `CollisionShape2D` and `CollisionPolygon2D` children of physics bodies are
sampled into approximately six-world-pixel line fragments. Supported shapes are
rectangles, capsules, circles, convex polygons, segment shapes and concave segment
sets. The player, `Area2D` triggers, disabled colliders and any subtree in
`sonar_ignore` are excluded.

For each noise and each reachable collider, the first contact is the closest
point on that collider. Its delay is distance divided by propagation speed.
Two fronts then travel away from that contact along the collider perimeter,
including tops, sides and undersides. Open segments have no wrap-around.
Every fragment has its own arrival and attenuation. The bright front leaves a
brief decaying trail; overlapping noises add up to white. Origin markers are
small contact sparks, not expanding reveal rings.

Defaults use 550 px/s airborne propagation, 650 px/s contour travel, a 0.095 s
bright head and a 0.53 s tap trail. The player's 1.1-loudness tap reaches about
427 world pixels; a 0.8-loudness enemy step reaches 252 pixels and a
1.6-loudness prop break reaches 655 pixels. These are configurable in
`resources/sensory/sonar_tuning.gd` and the shared default resource.

During silence every world fragment fades to black. A small white body-position
mark is deliberately retained for proprioception; it reveals no terrain or
enemy. All world-space geometry, noise sparks and the body cue use the active
Camera2D canvas transform, so vertical scrolling and zoom remain aligned.

## Moving and disappearing geometry

Contour vertices remain local to the actual collider and are transformed at draw
time. Highlights therefore follow moving/rotating props instead of leaving old
outlines behind. Existing tracks retain their emission-time arrival schedules
when only rigid motion changes. Geometry refreshes every 0.35 s and rebuilds
tracks for shape/scale changes. Deleted or disabled colliders stop drawing
immediately; refresh also removes their obsolete tracks.

## Acoustic abstraction and limits

This is a stylized, deterministic visual acoustic model, not a full acoustic
simulation. Each collider receives a distance-delayed contact independently.
There is no raycast occlusion, room diffraction, reflected bounce network,
frequency-dependent absorption, material acoustics or physical reverberation.
Nearby surfaces behind other surfaces can be reached. Disconnected colliders do
not share a propagated surface graph, and concave segment sets are independent
open traces. Moving geometry carries its original arrival schedule, so this is
not a moving-wavefront solver. Finite geometry and pulse caps may omit details
under extreme density. Do not describe this implementation as simulating sound
reflection through an entire environment.

Caps are 18 simultaneous pulses, 9,000 sampled geometry fragments, 3,600 drawn
fragments and 160 view-history entries. Oldest pulses are evicted at the cap.
Pulse expiry is finite even when geometry changes. The render loop skips
not-yet-arrived and fully faded tracks, uses typed local arrays and avoids work
after overlapping alpha has saturated.

## Verification and observability

Run from the project directory:

```sh
mkdir -p /tmp/moksha-sonar/data /tmp/moksha-sonar/cache /tmp/moksha-sonar/config
XDG_DATA_HOME=/tmp/moksha-sonar/data \
XDG_CACHE_HOME=/tmp/moksha-sonar/cache \
XDG_CONFIG_HOME=/tmp/moksha-sonar/config \
godot --headless --path . --script tests/sonar_regression.gd
```

The test writes `tests/sonar_report.json` and exits nonzero on any failure.
`tests/sonar_test_report.md` explains coverage and what headless verification
does not prove.

- `advance_simulation(seconds)` permits deterministic arrival/fade checks.
- `debug_sample(world_position, tolerance)` reports nearby actual collision
  fragments, per-noise arrival times, contributing origins and composite alpha.
- `debug_snapshot()` reports accepted events, pulse ages/origins, geometry count,
  active geometry fragments, peak alpha, draw count, black cover, body cue,
  origin-marker counts and budget eviction count.
- `debug_project_world(position)` exposes the same camera projection used by
  drawing.

The debug APIs are instrumentation; they do not generate noise or reveal
otherwise silent world geometry to the player.
