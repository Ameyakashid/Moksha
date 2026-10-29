class_name MokshaMovementTuning
extends Resource
## Shared movement data. Runtime switches belong to each motor, never this resource.
@export_category("Ground response")
@export var run_speed: float = 260.0
@export var instant_ground_response: bool = true
@export var acceleration: float = 4200.0
@export var braking: float = 6000.0
@export var reversal_acceleration: float = 8500.0
@export var floor_snap: float = 6.0
@export var max_slope_degrees: float = 46.0
@export_category("Air response")
@export var air_acceleration: float = 2600.0
@export var instant_air_steering: bool = true
@export var walk_off_speed_ratio: float = 0.5
@export var air_braking: float = 900.0
@export var air_reversal: float = 4600.0
@export var gravity: float = 1400.0
@export var fall_gravity_multiplier: float = 1.0
@export var terminal_speed: float = 720.0
@export var apex_speed: float = 65.0
@export var apex_gravity_multiplier: float = 0.8
@export_category("Jump intent")
@export var jump_speed: float = 440.0
@export var air_jump_speed: float = 400.0
@export var coyote_seconds: float = 0.10
@export var jump_buffer_seconds: float = 0.12
@export var jump_release_speed_cap: float = 160.0
@export var max_jumps: int = 2
@export var landing_seconds: float = 0.055
@export_category("Dash intent")
@export var dash_speed: float = 620.0
@export var dash_seconds: float = 0.13
@export var dash_cooldown: float = 0.36
@export var dash_buffer_seconds: float = 0.12
@export var dash_jump_cancel_after: float = 0.045
@export var air_dashes: int = 1
@export var wall_dash_stop: bool = true
