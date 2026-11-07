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
var _aliases: Dictionary = {}

func _enter_tree() -> void:
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

func extend_frame(frame: Dictionary) -> Dictionary:
	for action in _aliases:
		var record: Dictionary = _aliases[action]
		# Keep all keys and pads for an action in ONE native action state. ORing
		# separate just-pressed flags creates extra edges when another source is
		# already held. Godot owns aggregate held/edge semantics in this alias.
		if not _source_unchanged(action, record) or not InputMap.has_action(record.name): continue
		var name: String = action.trim_prefix("cp_")
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
	if not is_equal_approx(InputMap.action_get_deadzone(action), record.deadzone): return false
	var events := InputMap.action_get_events(action)
	if events.size() != record.source.size(): return false
	for i in events.size():
		if events[i] != record.source[i] or not _same_binding(events[i], record.source_shapes[i]): return false
	return true

func _exit_tree() -> void:
	for record in _aliases.values():
		if not InputMap.has_action(record.name): continue
		for i in record.events.size():
			for event in InputMap.action_get_events(record.name):
				# Preserve external replacements and in-place edits, even if they
				# are equivalent to a private binding we once owned.
				if event == record.events[i] and _same_binding(event, record.shapes[i]):
					InputMap.action_erase_event(record.name, event)
					break
		if InputMap.action_get_events(record.name).is_empty() and is_equal_approx(InputMap.action_get_deadzone(record.name), record.deadzone):
			InputMap.erase_action(record.name)
	_aliases.clear()

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
	if left is InputEventJoypadMotion: return is_equal_approx(left.axis_value, right.axis_value)
	return true
