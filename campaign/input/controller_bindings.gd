extends Node
## Campaign-local aliases let Godot sample every controller without altering the
## preserved actor mappings. Removing a global cp_* event clears its held state,
## so aliases are private to each host and never share that lifecycle hazard.
const DEFAULTS := {
	"cp_left": [[KEY_A, KEY_LEFT], JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0],
	"cp_right": [[KEY_D, KEY_RIGHT], JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0],
	"cp_up": [[KEY_W, KEY_UP], JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0],
	"cp_down": [[KEY_S, KEY_DOWN], JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0],
	"cp_jump": [[KEY_SPACE, KEY_C], JOY_BUTTON_A],
	"cp_roll": [[KEY_SHIFT], JOY_BUTTON_RIGHT_SHOULDER],
	"cp_attack": [[KEY_J], JOY_BUTTON_X],
	"cp_shield": [[KEY_K], JOY_BUTTON_LEFT_SHOULDER],
}
signal bindings_ready
const MAX_REMEMBERED_DEVICES := 64
# Real connected devices are always discovered through Input. The bounded ID
# cache also covers synthetic/disconnected devices observed by a previous host.
# It owns no Nodes or InputEvents and prunes neutral devices when a host exits.
static var _remembered_devices: Array[int] = []
var _aliases: Dictionary = {}
var _initial_devices: Array[int] = []

func _enter_tree() -> void:
	_initial_devices = Input.get_connected_joypads()
	for device in _remembered_devices:
		if device not in _initial_devices: _initial_devices.append(device)
	for action in DEFAULTS:
		if not _has_default_layout(action): continue
		var alias := "__moksha_pad_%d_%s" % [get_instance_id(), action]
		while InputMap.has_action(alias): alias += "_"
		var deadzone := InputMap.action_get_deadzone(action)
		InputMap.add_action(alias, deadzone)
		var owned: Array[InputEvent] = []
		for original in InputMap.action_get_events(action):
			var wildcard: InputEvent = original.duplicate()
			if wildcard is InputEventJoypadButton or wildcard is InputEventJoypadMotion:
				wildcard.device = -1
			InputMap.action_add_event(alias, wildcard)
			owned.append(wildcard)
		_aliases[action] = {"name": alias, "deadzone": deadzone, "events": owned, "shapes": owned.map(func(event): return event.duplicate()), "source": InputMap.action_get_events(action), "source_shapes": InputMap.action_get_events(action).map(func(event): return event.duplicate())}
		_aliases[action].initial_hold = Input.is_action_pressed(action) or _physical_strength(_aliases[action]) > 0.0
	# The host's existing modal gate, not this sampler, owns action suppression.
	bindings_ready.emit()

func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion) or event.device < 0: return
	_remembered_devices.erase(event.device)
	_remembered_devices.append(event.device)
	if _remembered_devices.size() > MAX_REMEMBERED_DEVICES: _remembered_devices.pop_front()

func _physical_strength(record: Dictionary) -> float:
	var strength := 0.0
	for binding in record.source_shapes:
		if binding is InputEventKey:
			if Input.is_physical_key_pressed(binding.physical_keycode): return 1.0
		elif binding is InputEventJoypadButton:
			for device in _initial_devices:
				if Input.is_joy_button_pressed(device, binding.button_index): return 1.0
		elif binding is InputEventJoypadMotion:
			for device in _initial_devices:
				var value := Input.get_joy_axis(device, binding.axis) * signf(binding.axis_value)
				var amount := 1.0 if value >= 1.0 else clampf((value - record.deadzone) / (1.0 - record.deadzone), 0.0, 1.0) if record.deadzone < 1.0 else 0.0
				strength = maxf(strength, amount)
	return strength

static func _device_still_held(device: int) -> bool:
	if Input.get_joy_axis(device, JOY_AXIS_LEFT_X) != 0.0 or Input.get_joy_axis(device, JOY_AXIS_LEFT_Y) != 0.0: return true
	for spec in DEFAULTS.values():
		if Input.is_joy_button_pressed(device, spec[1]): return true
	return false


func extend_frame(frame: Dictionary) -> Dictionary:
	for action in _aliases:
		var record: Dictionary = _aliases[action]
		# Keep all keys and pads for an action in ONE native action state. ORing
		# separate just-pressed flags creates extra edges when another source is
		# already held. Godot owns aggregate held/edge semantics in this alias.
		if not _source_unchanged(action, record) or not InputMap.has_action(record.name): continue
		var name: String = action.trim_prefix("cp_")
		if record.initial_hold:
			# Newly registered actions do not inherit already-held physical state.
			# Keep it visible to the modal gate until every initial/current source
			# is neutral. This reads state only: no replay, press, or edge synthesis.
			var held_strength := maxf(float(frame.get(name, 0)), maxf(Input.get_action_strength(record.name), _physical_strength(record)))
			if held_strength > 0.0:
				frame[name] = held_strength if name in ["left", "right", "up", "down"] else true
				continue
			record.initial_hold = false
		if name in ["left", "right", "up", "down"]:
			frame[name] = Input.get_action_strength(record.name)
		else:
			frame[name] = Input.is_action_pressed(record.name)
			frame[name + "_pressed"] = Input.is_action_just_pressed(record.name)
			frame.erase(name + "_released")
			# As in the campaign gate, omit an expired release so the preserved
			# actor can infer it after a pause from its last held sample.
			if Input.is_action_just_released(record.name): frame[name + "_released"] = true
	return frame

func _source_unchanged(action: String, record: Dictionary) -> bool:
	if not InputMap.has_action(action): return false
	if InputMap.action_get_deadzone(action) != record.deadzone: return false
	var events := InputMap.action_get_events(action)
	if events.size() != record.source.size(): return false
	for i in events.size():
		if events[i] != record.source[i] or not _same_binding(events[i], record.source_shapes[i]): return false
	return true

func _exit_tree() -> void:
	for record in _aliases.values():
		# Erasing an event is by VALUE, not Resource identity. A caller can edit
		# one event to equal another, making partial cleanup erase the wrong one.
		# A modified private alias is therefore caller-owned as a whole. Leave
		# its contents AND current action state untouched instead of restoring it.
		if _alias_unchanged(record):
			# erase_action alone retains held state if the same name is recreated.
			# The complete untouched ownership check makes this native event cleanup
			# safe; an adopted alias never reaches this branch.
			for event in record.events: InputMap.action_erase_event(record.name, event)
			InputMap.erase_action(record.name)
	_aliases.clear()
	_initial_devices.clear()
	_remembered_devices = _remembered_devices.filter(_device_still_held)

func _alias_unchanged(record: Dictionary) -> bool:
	if not InputMap.has_action(record.name): return false
	if InputMap.action_get_deadzone(record.name) != record.deadzone: return false
	var events := InputMap.action_get_events(record.name)
	if events.size() != record.events.size(): return false
	for i in events.size():
		if events[i] != record.events[i] or not _same_binding(events[i], record.shapes[i]): return false
	return true

static func _has_default_layout(action: String) -> bool:
	if not InputMap.has_action(action): return false
	var spec: Array = DEFAULTS[action]
	var events := InputMap.action_get_events(action)
	if events.size() != spec[0].size() + (2 if spec.size() == 4 else 1): return false
	var expected: Array[InputEvent] = []
	for code in spec[0]:
		var key := InputEventKey.new()
		key.physical_keycode = code
		expected.append(key)
	var button := InputEventJoypadButton.new()
	button.button_index = spec[1]
	expected.append(button)
	if spec.size() == 4:
		var axis := InputEventJoypadMotion.new()
		axis.axis = spec[2]
		axis.axis_value = spec[3]
		expected.append(axis)
	for wanted in expected:
		if not events.any(func(event): return _same_binding(event, wanted)): return false
	return true

static func _same_binding(left: InputEvent, right: InputEvent) -> bool:
	if left.get_class() != right.get_class() or left.device != right.device: return false
	if not left.is_match(right, true): return false
	if left is InputEventJoypadMotion: return left.axis_value == right.axis_value
	return true
