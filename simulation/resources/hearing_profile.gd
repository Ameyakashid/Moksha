extends Resource
## Stylized audibility policy, not an acoustic wave solver. Shared by any actor.
@export var hearing_enabled := true
@export_range(0.0, 4000.0, 1.0) var range_at_unit_loudness := 340.0
@export_range(0.0, 10.0, 0.01) var gain := 1.0
@export_range(0.0, 10.0, 0.01) var minimum_loudness_scale := 0.2
@export_range(0.0, 10.0, 0.01) var maximum_loudness_scale := 2.0
@export var terrain_attenuation_enabled := false
@export_flags_2d_physics var terrain_mask := 1
@export_range(0.0, 1.0, 0.01) var blocked_range_multiplier := 0.25
@export var ignore_own_source := true
@export var ear_offset := Vector2(0, -20)

## Avoid counting the emitting contact surface at the ray endpoint as a wall.
@export_range(0.0, 1.0, 0.01) var contact_endpoint_tolerance := 0.1
