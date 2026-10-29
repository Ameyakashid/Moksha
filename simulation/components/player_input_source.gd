extends Node
## Raw device adapter only. No actor motion, action or collision authority.
func sample_raw(_actor: Node, _dt: float) -> Dictionary:
	var raw := {}
	for axis in ["left", "right", "up", "down"]:
		raw[axis] = Input.get_action_strength("cp_" + axis)
	for button in ["jump", "roll", "attack", "shield"]:
		raw[button] = Input.is_action_pressed("cp_" + button)
		raw[button + "_pressed"] = Input.is_action_just_pressed("cp_" + button)
		raw[button + "_released"] = Input.is_action_just_released("cp_" + button)
	return raw
func reset_intent() -> void:
	pass # Held-device rearming belongs to the shared driver.
