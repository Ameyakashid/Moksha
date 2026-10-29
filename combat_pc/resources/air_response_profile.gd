class_name MokshaAirResponseProfile
extends Resource
## Optional ordinary airborne steering only. MOKSHA-authored acceleration;
## no new jump, neutral drag, speed cap, vertical force or action permission.
@export var air_acceleration := 2300.0

func is_valid() -> bool:
	return is_finite(air_acceleration) and air_acceleration>0.0
