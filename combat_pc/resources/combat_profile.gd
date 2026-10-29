class_name MokshaCombatProfile
extends Resource
## ORIGINAL MOKSHA combat tuning, not recovered Dead Cells v35 values.
## The source audit supports separate main-action and weapon permissions only.
@export_category("Horizontal roll / authored seconds and pixels")
@export var roll_start_seconds := 0.04
@export var roll_travel_seconds := 0.18
@export var roll_recovery_seconds := 0.08
@export var roll_start_speed := 385.0
@export var roll_end_speed := 300.0
@export var roll_exit_speed_limit := 218.0
@export var roll_cooldown_seconds := 0.42
@export var roll_jump_cancel_after := 0.18
@export var roll_attack_cancel_after := 0.16
@export var roll_invulnerable_from := 0.035
@export var roll_invulnerable_until := 0.20
@export var roll_buffer_seconds := 0.12
@export var roll_loudness := 0.85
@export_category("Melee phases / authored weapon policy")
@export var attack_windup_seconds := 0.09
@export var attack_active_seconds := 0.075
@export var attack_recovery_seconds := 0.18
@export var attack_windup_move_scale := 0.35
@export var attack_recovery_move_scale := 0.70
@export var attack_buffer_seconds := 0.14
@export var attack_active_ground_speed := 65.0
@export var attack_air_drag := 950.0
@export var strike_size := Vector2(32, 24)
@export var strike_center_offset := Vector2(24, -20)
@export var strike_origin_offset := Vector2(3, -22)
@export var strike_damage := 1.0
@export var strike_impulse := Vector2(260, -80)
@export var attack_loudness := 1.05
@export_category("Actor-local impact / authored policy")
@export var contact_hitpause_seconds := 0.045
@export var hurt_hitpause_seconds := 0.06
@export var hurt_seconds := 0.18
@export var hurt_horizontal_speed := 180.0
@export var hurt_vertical_speed := -130.0
@export var hurt_drag := 650.0
@export var hurt_loudness := 1.0
@export_category("Downward dive / original MOKSHA")
@export var dive_startup_seconds := 0.08
@export var dive_startup_vertical_braking := 4000.0
@export var dive_min_floor_clearance := 8.0
@export var dive_initial_speed := 180.0
@export var dive_acceleration := 2000.0
@export var dive_max_speed := 700.0
@export var dive_horizontal_drag := 1800.0
@export var dive_max_descent_seconds := 2.0
@export var dive_impact_seconds := 0.06
@export var dive_recovery_seconds := 0.14
@export var dive_impact_loudness := 1.3
