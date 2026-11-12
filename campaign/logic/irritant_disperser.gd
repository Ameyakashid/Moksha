extends "res://simulation/components/irritant_field.gd"
## Experimental campaign adapter. No save or actor-motion authority.
const NOTICE_RANGE := 300.0
const REPEAT_SECONDS := 0.4
var host: Node
var armed := false
var _session_generation := -1
var _notice_left := 0.0
func _ready() -> void:
	_session_generation = host.session_generation if is_instance_valid(host) else -1
	super._ready()
	phase_changed.connect(_phase_notice)
	if is_instance_valid(_view): _view.visible = _host_live() and not host.blind
func set_sight_enabled(value: bool) -> void:
	if is_instance_valid(_view): _view.visible = value and _host_live()
func _host_live() -> bool:
	return is_instance_valid(host) and host.is_inside_tree() and not host.is_queued_for_deletion() and host.session_generation == _session_generation and host.state == "playing" and not host._loading_campaign and host._pending_sector < 0 and not host._pending_retry and is_instance_valid(host.room) and not host.room.is_queued_for_deletion() and host.room == get_parent() and host.player == target and is_instance_valid(target) and not target.is_queued_for_deletion() and target.is_inside_tree() and target.can_process() and not target.is_defeated()
func current() -> bool:
	return _host_live() and super.current()
func _near_listener() -> bool:
	return _host_live() and target.global_position.is_finite() and target.global_position.distance_to(global_position) <= NOTICE_RANGE
func _phase_notice(_next: StringName) -> void:
	# Never invoke synchronous NoiseBus listeners from inside the base phase tick.
	_notice_left = 0.0
func _emit_notice() -> void:
	if not current() or not _near_listener() or not is_instance_valid(host.bus): return
	if phase not in [&"warning", &"active"]: return
	_notice_left = REPEAT_SECONDS
	host.bus.emit_noise(global_position, &"irritant_warning" if phase == &"warning" else &"irritant_hiss", 0.8, self)
func _physics_process(dt: float) -> void:
	if is_instance_valid(_view): _view.visible = _host_live() and not host.blind
	if not _host_live() or dt <= 0 or not current(): return
	if not armed:
		if not _near_listener(): return
		armed = true
		phase = &"warning"
		phase_elapsed = 0.0
		_emit_notice() # First audible warning precedes any advancement/exposure.
		return
	if phase == &"recovery" and not _near_listener():
		armed = false
		phase = &"warning"
		phase_elapsed = 0.0
		return
	_notice_left -= dt
	super._physics_process(dt)
	if _notice_left <= 0: _emit_notice()
func presentation() -> Dictionary:
	var snapshot := super.presentation()
	snapshot.live = snapshot.live and armed
	return snapshot

func accepts_notice(origin: Vector2, kind: StringName) -> bool:
	return current() and armed and _near_listener() and origin.is_finite() and origin.is_equal_approx(global_position) and ((kind == &"irritant_warning" and phase == &"warning") or (kind == &"irritant_hiss" and phase == &"active"))
