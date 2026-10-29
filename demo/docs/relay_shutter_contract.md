# Detachable relay shutter

`demo/components/relay_shutter.gd` is an independently placeable `StaticBody2D`. It uses one rectangular `CollisionShape2D` for ordinary two-way terrain and for sound contours. The existing combat PC, movement code, NoiseBus, preserved sonar, and optimized demo sonar are unchanged.

## Integration

```gdscript
var shutter = preload("res://demo/components/relay_shutter.gd").new()
shutter.position = Vector2(900, 180) # rectangle center, in room coordinates
shutter.configure(Vector2(24, 240), relay_index)
shutter.set_open(already_activated) # optional quiet pre-tree checkpoint restore
room.add_child(shutter)

# Relay ownership stays in the room/mission composition.
shutter.set_open(true)
shutter.reset() # same as set_open(false)
```

- `shutter_size` and `relay_index` are exported and can be set before adding the component. `configure(size, index)` also updates the real rectangle at runtime. Dimensions are finite and at least one pixel; an invalid non-finite size falls back to 24 × 120.
- `position` is the rectangle center. Place the node anywhere below the active room, including a transformed room child. There is no lookup for another room, mission host, or player.
- `is_open` is the committed collision/visual state. `collision_shape` exposes the sole collider for inspection. `open_changed(open)` reports state changes.
- `set_open(bool)` is idempotent. In physics callbacks it defers the complete state change until the safe deferred queue; it never disables a shape during a query flush. Several requests in that same flush commit only their final state, so a canceled open/close pair produces no fictitious sound. There is no animation or timer gate.
- Opening disables the actual shape, adds `sonar_ignore` to it, and changes the visible wireframe together. Closing restores the same shape and removes the group. Node transforms and collider transforms are untouched.
- The closed wireframe is amber with fine internal slats. Open state draws only a thin green frame. That decorative frame has no enabled collider and contributes no sonar geometry.
- Every committed in-tree transition emits exactly one ordinary `prop_impact` through `/root/NoiseBus` at the shutter's exact global position with the shutter itself as source. Default loudness is 0.8. The node must remain a descendant of the active room for the existing sonar provenance filters to admit its sound. Construction/pre-tree restore and repeated state calls are silent. Off-tree changes emit no unscoped sound.
- Opening is safe while the player overlaps the rectangle. Closing reinstates a solid rectangle; the caller owns checkpoint/player placement and should not close a passage around a player it intends to leave free. This component neither moves nor teleports that player.

## Verification

Run from the project root with Godot 4.6.3:

```sh
XDG_DATA_HOME=/tmp/moksha-data XDG_CONFIG_HOME=/tmp/moksha-config XDG_CACHE_HOME=/tmp/moksha-cache \
  /usr/local/bin/godot --headless --path . --script demo/tests/relay_shutter_regression.gd -- --hz=120
XDG_DATA_HOME=/tmp/moksha-data XDG_CONFIG_HOME=/tmp/moksha-config XDG_CACHE_HOME=/tmp/moksha-cache \
  /usr/local/bin/godot --headless --path . --script demo/tests/relay_shutter_regression.gd -- --hz=60
```

Evidence is written to `demo/evidence/relay_shutter_120hz.json` and `demo/evidence/relay_shutter_60hz.json`. Each run checks:

- Actual production-PC movement into a closed gate from both sides, with the motor's physical wall normal and an independent non-moving `test_move` identifying that same touching shutter. The motor uses `move_and_collide`, so `get_slide_collision_count()` would not be a valid observer here.
- Actual input-driven traversal through the open rectangle in both directions, and physical blocking again after reset. Recorded start/end positions, collision identity, wall normals, actor velocity, and physics-step receipts establish the result. Frame budgets bound failures; waiting is not the evidence.
- Opening from a real `Area2D.body_entered` callback with the player embedded in the rectangle, deferred collision mutation during the physics-query flush, no actor repositioning, and successful normal-motor exit/landing.
- Repeated requests, coalesced requests, one noise event per committed change, exact world-origin/source provenance, coherent state visible to noise listeners, and accepted events in both production sonar implementations.
- Disabled shape exclusion immediately through `Geometry.is_live`, removal from both collectors and active pulse tracks after refresh, reset/reclose, detachment and reattachment without duplicate shapes or ghost geometry.
- Exact local/global transform preservation through a rotated, nonuniformly scaled, skewed parent hierarchy, plus before/after SHA-256 equality for preserved PC and sonar sources.

This focused headless suite verifies component behavior; it is not a substitute for room-route integration or rendered visual review of authored placement.
