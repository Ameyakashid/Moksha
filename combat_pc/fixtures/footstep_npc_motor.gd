extends "res://movement/components/movement_motor.gd"
## Review-only bridge around the unchanged NPC motor. No movement overrides.
var _footstep_dash_started := false

func _ready() -> void:
	super._ready()
	landed.connect(_on_footstep_landed)
	dash_started.connect(_on_footstep_dash)

func _footsteps() -> MokshaCharacterFootsteps:
	return get_node_or_null("Footsteps") as MokshaCharacterFootsteps

func _ordinary_locomotion() -> bool:
	return enabled and pause_left <= 0.0 and stun_left <= 0.0 and dash_left <= 0.0 and not _footstep_dash_started

func step_motor(dt: float) -> void:
	var observer := _footsteps()
	if not enabled:
		if is_instance_valid(observer): observer.reset_history()
		super.step_motor(dt)
		return
	if pause_left > 0.0:
		if is_instance_valid(observer): observer.suspend_motion()
		super.step_motor(dt)
		return
	_footstep_dash_started = false
	var token := observer.begin_motion_sample(dt, _ordinary_locomotion()) if is_instance_valid(observer) else 0
	super.step_motor(dt)
	if is_instance_valid(observer): observer.finish_motion_sample(token, _ordinary_locomotion())

func _on_footstep_landed(speed: float) -> void:
	var observer := _footsteps()
	if is_instance_valid(observer): observer.capture_landing(speed)

func _on_footstep_dash(_direction: int) -> void:
	_footstep_dash_started = true

func reset_at(at: Vector2) -> void:
	var observer := _footsteps()
	if is_instance_valid(observer): observer.reset_history()
	super.reset_at(at)

func apply_pause(seconds: float = 0.08) -> void:
	var observer := _footsteps()
	if is_instance_valid(observer): observer.suspend_motion()
	super.apply_pause(seconds)

func apply_impulse(impulse: Vector2, seconds: float = 0.14) -> void:
	var observer := _footsteps()
	if is_instance_valid(observer): observer.reset_history()
	super.apply_impulse(impulse, seconds)
