class_name MokshaMeleeStepProfile
extends Resource
## Original MOKSHA light-melee step; no recovered Dead Cells frame values.
@export var step_label := "Slash"
@export var pose_id: StringName = &"slash"
@export var next_step := 1
@export_category("Independent phase clocks / seconds")
@export var windup_seconds := 0.07
@export var active_seconds := 0.065
@export var recovery_seconds := 0.16
@export var reuse_lock_seconds := 0.0
@export_category("One fresh follow-up / elapsed seconds")
@export var followup_open_seconds := 0.035
@export var followup_close_seconds := 0.295
@export var followup_commit_recovery_seconds := 0.06
@export_category("Movement and facing / authored")
@export var windup_move_scale := 0.50
@export var recovery_move_scale := 0.80
@export var active_ground_speed := 70.0
@export var air_drag := 950.0
@export var allow_turn_windup := true
@export var allow_turn_active := false
@export var allow_turn_recovery := true
@export_category("Committed hurt response / optional role-neutral bracing")
## Empty retains ordinary hurt. Only these committed phases may resist recoil;
## damage, forced cancellation, reset and defeat keep their existing owners.
@export var hurt_protected_phases := PackedStringArray()
@export var hurt_interrupt_seconds := 0.70
@export_category("Ordinary cancellation / forced cancellation always wins")
@export var windup_cancels := PackedStringArray(["roll", "jump", "air_jump", "shield", "drop", "dive", "climb", "wall"])
@export var active_cancels := PackedStringArray()
@export var recovery_cancels := PackedStringArray(["roll", "jump", "air_jump", "shield", "drop", "dive", "climb", "wall"])
@export var recovery_cancel_after := 0.0
@export_category("Live strike / pixels and original power")
@export var strike_size := Vector2(34, 24)
@export var strike_center_offset := Vector2(25, -20)
@export var strike_origin_offset := Vector2(3, -22)
@export var damage := 1.0
@export var impulse := Vector2(240, -70)
@export var prop_launch_scale := 1.0
@export var hitpause_seconds := 0.04
@export var loudness := 1.0

func is_valid_step(count: int) -> bool:
	if pose_id.is_empty() or next_step < -1 or next_step >= count: return false
	if not is_valid_hurt_response(): return false
	for duration in [windup_seconds, active_seconds, recovery_seconds]:
		if not is_finite(duration) or duration < 0.001: return false
	for value in [reuse_lock_seconds, followup_open_seconds, followup_close_seconds, followup_commit_recovery_seconds, recovery_cancel_after, windup_move_scale, recovery_move_scale, active_ground_speed, air_drag, damage, prop_launch_scale, hitpause_seconds, loudness]:
		if not is_finite(value) or value < 0: return false
	if next_step >= 0 and (followup_close_seconds <= followup_open_seconds or followup_commit_recovery_seconds > recovery_seconds): return false
	return strike_size.is_finite() and strike_size.x > 0 and strike_size.y > 0 and strike_center_offset.is_finite() and strike_origin_offset.is_finite() and impulse.is_finite()

func is_valid_hurt_response() -> bool:
	if not is_finite(hurt_interrupt_seconds) or hurt_interrupt_seconds < 0.0: return false
	for phase in hurt_protected_phases:
		if phase not in ["windup", "active"]: return false
	return true
