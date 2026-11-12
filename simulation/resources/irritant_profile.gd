class_name MokshaIrritantProfile
extends Resource
## Original fixed-volume pilot tuning; not a gas simulation or toxic damage model.
@export var field_size := Vector2(120, 64)
@export var warning_seconds := 1.2
@export var active_seconds := 0.65
@export var recovery_seconds := 2.4
func valid() -> bool:
	return field_size.is_finite() and field_size.x >= 32 and field_size.x <= 200 and field_size.y >= 24 and field_size.y <= 100 and is_finite(warning_seconds) and warning_seconds >= 1.0 and warning_seconds <= 4.0 and is_finite(active_seconds) and active_seconds > 0 and active_seconds <= 0.8 and is_finite(recovery_seconds) and recovery_seconds >= 2.0 and recovery_seconds <= 8.0
