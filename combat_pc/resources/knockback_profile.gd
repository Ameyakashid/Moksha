class_name MokshaKnockbackProfile
extends Resource
## Original MOKSHA receiver response, measured in pixels/second and seconds.
## The incoming impulse is already signed in world space.
@export var velocity_scale := Vector2(0.55, 1.0)
@export_range(0.001, 2.0, 0.001) var stun_seconds := 0.18
@export_range(1.0, 2000.0, 1.0) var maximum_speed := 420.0
@export var copy_source_pause := true
@export_range(0.0, 0.25, 0.001) var maximum_pause_seconds := 0.12

func is_valid_profile() -> bool:
	return velocity_scale.is_finite() and velocity_scale.x >= 0.0 and velocity_scale.y >= 0.0 and velocity_scale.x <= 4.0 and velocity_scale.y <= 4.0 \
		and is_finite(stun_seconds) and stun_seconds > 0.0 and stun_seconds <= 2.0 \
		and is_finite(maximum_speed) and maximum_speed >= 1.0 and maximum_speed <= 2000.0 \
		and is_finite(maximum_pause_seconds) and maximum_pause_seconds >= 0.0 and maximum_pause_seconds <= 0.25
