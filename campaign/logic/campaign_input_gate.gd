extends RefCounted
## Campaign-only modal boundary. The preserved actor still owns input edges,
## buffering and action admission; menus must not become gameplay commands.
const AXES := ["left", "right", "up", "down"]
const BUTTONS := ["jump", "roll", "attack", "shield"]
var _blocked: Dictionary = {}

func sample_device() -> Dictionary:
	var frame := {}
	for axis in AXES:
		frame[axis] = Input.get_action_strength("cp_" + axis) if InputMap.has_action("cp_" + axis) else 0.0
	for button in BUTTONS:
		if not InputMap.has_action("cp_" + button):continue
		frame[button] = Input.is_action_pressed("cp_" + button)
		frame[button + "_pressed"] = Input.is_action_just_pressed("cp_" + button)
		# Device release edges can expire while the scene is paused. Omitting
		# false lets the preserved actor infer release from its last held sample.
		# Caller-provided explicit override edges are never rewritten here.
		if Input.is_action_just_released("cp_" + button):frame[button + "_released"] = true
	return frame

func suppress_held(frame: Dictionary) -> void:
	for action in AXES + BUTTONS:
		if float(frame.get(action, 0)) > 0.0 or bool(frame.get(action + "_pressed", false)):
			_blocked[action] = true
		else:
			_blocked.erase(action)

func has_held_blocker(frame: Dictionary) -> bool:
	# Read-only UI query. Do not clear edge state or admit input from a snapshot.
	for action in _blocked:
		if float(frame.get(action, 0)) > 0.0 or bool(frame.get(action + "_pressed", false)):
			return true
	return false

func filter_frame(frame: Dictionary) -> Dictionary:
	var filtered := frame.duplicate()
	for action in _blocked.keys():
		if float(frame.get(action, 0)) <= 0.0 and not bool(frame.get(action + "_pressed", false)):
			_blocked.erase(action)
			continue
		filtered[action] = false if action in BUTTONS else 0.0
		if action in BUTTONS:
			filtered[action + "_pressed"] = false
			# A guard or held jump from before the menu must also see release.
			filtered[action + "_released"] = true
	return filtered
