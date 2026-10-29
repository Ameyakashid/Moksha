extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: _run.call_deferred()
func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _key(code: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventKey.new()
	event.physical_keycode = code
	Input.parse_input_event(event)
	await _frames(2)
func _run() -> void:
	change_scene_to_file("res://simulation/gym.tscn")
	await _frames(3)
	var base_connections := root.get_node("NoiseBus").get_signal_connection_list("noise_emitted").size()
	for stage in ["Footing", "Hearing", "Impact", "Movement", "Strike", "Projectile", "Bracing", "Bracing", "Projectile", "Strike", "Movement", "Impact", "Hearing", "Footing"]:
		_check(current_scene.name == "SimulationGym", "selector available before " + stage)
		# Explicit UI action boundary; gameplay remains ordinary physics afterward.
		current_scene.get_node(stage).pressed.emit()
		await _frames(8)
		_check(current_scene.name == stage + "Sandbox", "selected independent stage loads " + stage)
		var old_id := current_scene.get_instance_id()
		await _key(KEY_R)
		_check(current_scene.name == stage + "Sandbox" and current_scene.get_instance_id() != old_id, "R reloads complete stage " + stage)
		await _key(KEY_ESCAPE)
		_check(current_scene.name == "SimulationGym", "Esc returns to selector " + stage)
		_check(root.get_node("NoiseBus").get_signal_connection_list("noise_emitted").size() == base_connections, "no orphan listeners after stage exit " + stage)
	print("GYM LIFECYCLE: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
