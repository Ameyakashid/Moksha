class_name MokshaAttackPoseProfile
extends Resource
## Replaceable body drawings and grip anchors; gameplay timings remain external.
@export var frames: SpriteFrames
@export var animation: StringName = &"attack"
@export var hand_anchors: Array[Vector2] = []
@export var foot_origin: Vector2 = Vector2(320,352)
@export_range(0.1, 4.0, 0.001) var source_scale: float = 1.0
@export_range(0, 15, 1) var contact_frame: int = 2
@export_range(1, 15, 1) var recovery_frame: int = 4

func is_usable() -> bool:
	return frames != null and frames.has_animation(animation) and frames.get_frame_count(animation) >= 3 and hand_anchors.size() == frames.get_frame_count(animation)

func frame_at(progress: float, contact: float, active_end: float) -> int:
	# Timing arrives through Vector2 (32-bit components); tolerate its rounding
	# at the exact contact/recovery boundary without advancing a real frame early.
	progress = clampf(progress + 0.000001,0.0,1.0)
	var count := frames.get_frame_count(animation)
	var impact := clampi(contact_frame, 1, count - 2)
	var recover := clampi(recovery_frame, impact + 1, count - 1)
	if progress < contact:
		return clampi(int(progress / maxf(contact,0.001) * impact),0,impact-1)
	if progress < active_end:
		return clampi(impact + int(inverse_lerp(contact,active_end,progress)*(recover-impact)),impact,recover-1)
	return clampi(recover + int(inverse_lerp(active_end,1.0,progress)*(count-recover)),recover,count-1)
