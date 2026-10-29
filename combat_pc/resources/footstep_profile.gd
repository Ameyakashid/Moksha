class_name MokshaFootstepProfile
extends Resource
## Authored NPC cadence and contact policy. Distances are world pixels.
@export_range(1.0, 200.0, 0.5) var step_spacing := 28.0
@export_range(0.1, 100.0, 0.1) var minimum_speed := 3.0
@export var step_kind: StringName = &"enemy_step"
@export var landing_kind: StringName = &"enemy_land"
@export_range(0.01, 5.0, 0.01) var step_loudness := 0.8
@export_range(1.0, 2000.0, 1.0) var minimum_landing_speed := 70.0
@export_range(1.0, 2000.0, 1.0) var landing_speed_scale := 420.0
@export_range(0.01, 5.0, 0.01) var minimum_landing_loudness := 0.8
@export_range(0.01, 5.0, 0.01) var maximum_landing_loudness := 1.6
@export_range(0.001, 1.0, 0.001) var minimum_air_seconds := 0.06
@export_range(0.1, 50.0, 0.1) var minimum_air_travel := 6.0
## Footprint location relative to the body; the sample NPC origin is its sole.
@export var sole_offset := Vector2.ZERO
@export_range(0.0, 30.0, 0.5) var probe_half_width := 6.0
@export_range(0.1, 40.0, 0.5) var probe_above := 12.0
@export_range(0.1, 40.0, 0.5) var probe_below := 12.0
## Discontinuities are refused, never converted into a catch-up step burst.
@export_range(0.001, 0.25, 0.001) var maximum_sample_seconds := 0.1
@export_range(1.0, 300.0, 1.0) var maximum_sample_travel := 64.0
@export_range(0, 256, 1) var recent_receipt_limit := 32
