class_name MokshaShieldProfile
extends Resource
## Original MOKSHA shield tuning. Source evidence supports distinct guard,
## parry, cancellation and counter-result concepts, not these phase values.
@export_category("Attempt / authored seconds")
@export var can_be_held := true
@export var parry_window_from := 0.025
@export var parry_window_until := 0.16
@export var miss_recovery_seconds := 0.14
@export var success_recovery_seconds := 0.08
@export var release_recovery_seconds := 0.08
@export var input_buffer_seconds := 0.12
@export var use_lock_seconds := 0.22
@export var hold_cancel_after := 0.16
@export_category("Independent phase permissions / authored")
@export var ground_move_scale := 0.45
@export var air_move_scale := 0.65
@export var allow_turn_raise := true
@export var allow_turn_parry := true
@export var allow_turn_hold := true
@export var allow_turn_recovery := true
@export_category("Incoming contact / authored geometry")
@export var contact_width := 10.0
@export var contact_forward_offset := 3.0
@export var contact_height_inset := 4.0
@export var contact_height_ratio := 0.55
@export var minimum_contact_height := 8.0
@export var frontal_half_angle_degrees := 60.0
@export var minimum_incoming_dot := 0.25
## Exact IDs inside this per-authenticator range may arrive out of order.
## Older IDs are explicitly stale, so eviction cannot resurrect a contact.
@export_range(1, 4096, 1) var incoming_history_window := 256
## Historical developer text says approximately 75%; this remains a MOKSHA
## starting value, not a recovered v35 constant or health implementation.
@export_range(0.0, 1.0) var guard_absorption := 0.75
@export var guard_recoil_speed := 65.0
@export_category("Counter / independent authored power")
@export var counter_damage := 3.0
@export var counter_impulse := Vector2(280, -90)
@export var counter_range := 52.0
@export var reflected_projectile_speed := 420.0
@export_category("One feedback-pause budget per attempt")
@export var guard_hitpause_seconds := 0.025
@export var parry_hitpause_seconds := 0.045
@export var guard_loudness := 0.85
@export var parry_loudness := 1.25
