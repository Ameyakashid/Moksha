extends Node
## The sole scheduler for this composition. The preserved combat controller is
## still the sole movement/attack/defense authority. Providers supply raw input.
const Capabilities = preload("res://simulation/resources/actor_capabilities.gd")
const OWNER: StringName = &"_moksha_intent_driver"
const LAST_TICK: StringName = &"_moksha_intent_last_tick"
const BUTTONS := ["jump", "roll", "attack", "shield"]
@export_node_path("Node") var source_path := NodePath("../InputSource")
@export var capabilities: Capabilities
@export var enabled := true:
	set(value):
		if enabled == value: return
		enabled = value
		if is_inside_tree(): clear_intent_state()
@export var automatic_driver := true
var tick_count := 0
var last_frame: Dictionary:
	get: return _last_frame.duplicate(true)
var _last_frame := {}
var _actor: Node
var _source: Node
var _owns_tick := false
var _epoch := 0
var _last_tick := -1
var _rearm := {}
var _host_suspended := false
var _source_available := false
var _global_pause_seen := false

func _ready() -> void:
	_actor = get_parent()
	if not _actor.has_method("physics_tick") or _actor.automatic_physics: return
	if _actor.has_meta(OWNER):
		var reference: Variant = _actor.get_meta(OWNER)
		if reference is WeakRef and is_instance_valid(reference.get_ref()) and reference.get_ref().is_inside_tree() and not reference.get_ref().is_queued_for_deletion(): return
	_actor.set_meta(OWNER, weakref(self))
	_owns_tick = true
	# Instance ownership prevents capability/profile edits leaking to peers.
	_actor.profile = _actor.profile.duplicate(true)
	_actor.combat_profile = _actor.combat_profile.duplicate(true)
	_actor.shield_profile = _actor.shield_profile.duplicate(true)
	capabilities = capabilities.duplicate(true) if capabilities != null else Capabilities.new()
	capabilities.apply_to(_actor)
	_actor.movement_event.connect(_on_actor_event)
	var defeat := _actor.get_node_or_null("DefeatResponse")
	if defeat != null:
		defeat.defeat_started.connect(_refresh_hearing)
		defeat.defeat_cleared.connect(_refresh_hearing)
	_refresh_hearing()
func _notification(what: int) -> void:
	if _owns_tick and what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_DISABLED, NOTIFICATION_ENABLED]: clear_intent_state()
func _exit_tree() -> void:
	_epoch += 1
	if is_instance_valid(_actor):
		if _actor.has_meta(OWNER):
			var reference: Variant = _actor.get_meta(OWNER)
			if reference is WeakRef and reference.get_ref() == self:
				_actor.clear_input_buffers()
				_actor.remove_meta(OWNER)
		if _actor.movement_event.is_connected(_on_actor_event): _actor.movement_event.disconnect(_on_actor_event)
	_owns_tick = false
func _physics_process(dt: float) -> void:
	if automatic_driver: tick(dt)
func configure_capabilities(value: Capabilities) -> void:
	capabilities = value.duplicate(true) if value != null else Capabilities.new()
	if _owns_tick and is_instance_valid(_actor):
		clear_intent_state()
		capabilities.apply_to(_actor)
		_refresh_hearing()
func clear_intent_state() -> void:
	_epoch += 1
	_rearm.clear()
	for button in BUTTONS: _rearm[button] = true
	_last_frame.clear()
	if _owned_source(_source) and _source.has_method("reset_intent"): _source.reset_intent()
	if _owns_tick and is_instance_valid(_actor): _actor.clear_input_buffers()
func _on_actor_event(kind: StringName, _payload: Dictionary) -> void:
	if kind == &"reset":
		clear_intent_state()
		capabilities.apply_to(_actor)
		_refresh_hearing()
func _refresh_hearing() -> void:
	if not _owns_tick or not is_instance_valid(_actor): return
	var sensor := _actor.get_node_or_null("HearingSensor")
	if sensor != null: sensor.enabled = capabilities.can_hear and not _actor.is_defeated()
func _owned_source(source: Variant) -> bool:
	return is_instance_valid(_actor) and is_instance_valid(source) and source is Node and source.is_inside_tree() and not source.is_queued_for_deletion() and _actor.is_ancestor_of(source) and source.has_method("sample_raw")
func _live_source(source: Variant) -> bool:
	return _owned_source(source) and source.can_process()
func tick(dt: float) -> bool:
	if not _owns_tick or not is_inside_tree() or is_queued_for_deletion() or not can_process() or not is_instance_valid(_actor) or _actor.is_queued_for_deletion(): return false
	if get_tree().paused:
		if not _global_pause_seen: clear_intent_state()
		_global_pause_seen = true
		return false
	if _global_pause_seen:
		_global_pause_seen = false
		clear_intent_state()
	if not _actor.can_process() or not _actor.is_physics_processing() or _actor.automatic_physics:
		if not _host_suspended: clear_intent_state()
		_host_suspended = true
		return false
	if _host_suspended:
		_host_suspended = false
		clear_intent_state()
	if not is_finite(dt) or dt <= 0: return false
	var frame_id := Engine.get_physics_frames()
	if _last_tick == frame_id or int(_actor.get_meta(LAST_TICK, -1)) == frame_id: return false
	_last_tick = frame_id
	_actor.set_meta(LAST_TICK, frame_id)
	var candidate := get_node_or_null(source_path)
	if not is_instance_valid(_source) or candidate != _source:
		clear_intent_state()
		_source = candidate
		_source_available = false
		clear_intent_state()
	var source_available := _live_source(_source)
	if source_available != _source_available:
		clear_intent_state()
		_source_available = source_available
	var epoch := _epoch
	var generation: int = _actor.damage_generation()
	var raw: Variant = _source.sample_raw(_actor, dt) if enabled and _live_source(_source) else {}
	if epoch != _epoch or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(_actor) or _actor.is_queued_for_deletion() or generation != _actor.damage_generation(): return false
	if enabled and (not _live_source(_source) or get_node_or_null(source_path) != _source):
		clear_intent_state()
		_source_available = false
		raw = {}
	if get_tree().paused:
		_global_pause_seen = true
		clear_intent_state()
		return false
	if not _actor.can_process() or not _actor.is_physics_processing() or _actor.automatic_physics or not can_process(): return false
	var frame := _sanitize(raw)
	_last_frame = frame.duplicate(true)
	tick_count += 1
	_actor.physics_tick(dt, frame)
	return true
func _sanitize(raw: Variant) -> Dictionary:
	if not raw is Dictionary: return {}
	var frame := {}
	for axis in ["left", "right", "up", "down"]:
		var value: Variant = raw.get(axis, 0.0)
		frame[axis] = clampf(float(value), 0, 1) if (value is float or value is int) and is_finite(float(value)) else 0.0
	for button in BUTTONS:
		var held: bool = raw.get(button) == true
		var blocked := _rearm.has(button)
		if not held: _rearm.erase(button)
		frame[button] = held and not blocked
		for edge in ["_pressed", "_released"]:
			if raw.has(button + edge): frame[button + edge] = raw[button + edge] == true and not blocked
	return frame
