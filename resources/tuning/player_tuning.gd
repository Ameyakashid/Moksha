class_name EmberPlayerTuning
extends Resource
## Controller values are shared read-only by actor instances.

@export_category("Health and movement")
@export var max_health: int = 5
@export var move_speed: float = 218.0
@export var gravity: float = 1100.0
@export var terminal_speed: float = 650.0
@export_category("Jump")
@export var jump_speed: float = 365.0
@export var double_jump_speed: float = 365.0
@export var max_jumps: int = 2
@export var coyote_seconds: float = 0.10
@export var jump_buffer_seconds: float = 0.12
@export var release_cut_threshold: float = -120.0
@export var release_cut_factor: float = 0.5
@export_category("Dash")
@export var dash_speed: float = 490.0
@export var dash_seconds: float = 0.17
@export var dash_cooldown: float = 0.60
@export var dash_invulnerability: float = 0.22
@export var dash_buffer_seconds: float = 0.12
@export_category("Combo")
@export var combo_reset_seconds: float = 0.70
@export var attack_buffer_seconds: float = 0.14
@export var attack_active_seconds: float = 0.055
@export var attack_seconds: float = 0.19
@export var finisher_seconds: float = 0.26
@export var attack_cooldown: float = 0.23
@export var finisher_cooldown: float = 0.34
@export var attack_hit_remaining: float = 0.15
@export var finisher_hit_remaining: float = 0.22
@export var attack_lunge_speed: float = 80.0
@export var attack_lunge_remaining: float = 0.12
@export_category("Damage")
@export var damage_invulnerability: float = 1.0
@export var damage_air_lock: float = 0.19
@export var damage_knockback: float = 185.0
@export var damage_lift: float = -140.0

@export_category("Grounded sound")
@export var footstep_spacing: float = 52.0
@export var minimum_landing_speed: float = 90.0
@export var tap_cooldown: float = 0.42
@export var tap_pose_seconds: float = 0.15
