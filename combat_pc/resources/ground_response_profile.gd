class_name MokshaGroundResponseProfile
extends Resource
## Optional standing, uncommitted ground response. All numbers are MOKSHA
## tuning, not recovered Dead Cells constants. Other owners keep base rates.
@export var ground_acceleration := 4800.0
@export var ground_braking := 2700.0
@export var reversal_acceleration := 6200.0
@export var turn_pose_seconds := 0.07

func is_valid() -> bool:
	for value in [ground_acceleration, ground_braking, reversal_acceleration, turn_pose_seconds]:
		if not is_finite(value) or value<=0: return false
	return true
