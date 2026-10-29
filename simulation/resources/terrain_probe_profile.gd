extends Resource
## Prospective sampling geometry relative to the host origin. Character/body
## dimensions are configuration, never inferred from a PC/NPC label.
@export var wall_sample_heights := PackedFloat32Array([-23.0, -9.0])
@export_range(0.0, 200.0, 0.1) var floor_probe_above := 30.0
@export_range(0.0, 200.0, 0.1) var floor_probe_below := 28.0
@export_range(0.0, 200.0, 0.1) var body_margin := 14.0
@export_range(0.0, 400.0, 0.1) var minimum_lookahead := 24.0
