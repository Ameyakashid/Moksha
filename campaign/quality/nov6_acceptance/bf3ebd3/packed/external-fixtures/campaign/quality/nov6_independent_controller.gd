extends SceneTree
## Independent controller event integration. Synthesized Godot device events are
## not hardware QA. All commands enter the real _input/_unhandled_input pipeline.
var host: Node
var checks := 0
var failures: Array[String] = []
var hz := 120

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame

func pad(button: int, down: bool, device := 0) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(button: int, device := 0) -> void:
	pad(button, true, device)
	pad(button, false, device)

func keyboard(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func stick(value: float, device := 0) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func release_all() -> void:
	for device in [0, 1]:
		for button in range(16): pad(button, false, device)
		stick(0, device)

func fresh() -> void:
	release_all()
	host.start_new(true)
	host.input_override = null
	await frames(4)

func run() -> void:
	host = load("res://campaign/campaign.tscn").instantiate()
	host.save_enabled = false
	root.add_child(host)
	await frames(3)
	if host.get("gamepad_navigation") == null:
		check(false, "actual campaign root mounts controller adapter")
	else:
		await controller_cases()
	print("NOV6_INDEPENDENT_CONTROLLER " + JSON.stringify({"passed": failures.is_empty(), "checks": checks, "hz": hz, "failures": failures, "scope": "Synthesized InputEventJoypadButton/Motion through actual campaign event pipeline and actor physics. Not physical controller hardware or full campaign traversal."}))
	release_all()
	host.free()
	quit(0 if failures.is_empty() else 1)

func controller_cases() -> void:
	var adapter: Node = host.gamepad_navigation
	check(adapter.input_device == "keyboard", "initial prompt device is keyboard")
	pad(JOY_BUTTON_DPAD_RIGHT, true)
	check(host.lens == "strength", "title Dpad selects strength")
	pad(JOY_BUTTON_DPAD_RIGHT, true)
	check(host.lens == "strength", "duplicate held Dpad does not cycle twice")
	pad(JOY_BUTTON_DPAD_RIGHT, false)
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(host.lens == "agility", "fresh Dpad cycles again")
	keyboard(KEY_1, true); keyboard(KEY_1, false)
	check(host.lens == "neutral" and adapter.input_device == "keyboard", "keyboard selection coexists with pad")
	pad(JOY_BUTTON_A, true)
	check(host.state == "intro", "pad A starts new campaign")
	pad(JOY_BUTTON_A, true)
	check(host.state == "intro", "held start A does not also skip intro")
	tap(JOY_BUTTON_START)
	await frames(3)
	check(host.state == "playing" and not host.player._input.jump and host.player.velocity.y >= 0, "skip with A held does not jump")
	pad(JOY_BUTTON_A, false); await frames(2)
	pad(JOY_BUTTON_A, true); await frames(1)
	check(host.player._input.jump and host.player.velocity.y < 0, "fresh A reaches real actor jump")
	await fresh()
	tap(JOY_BUTTON_START)
	check(host.state == "paused" and paused, "pad Start pauses")
	pad(JOY_BUTTON_X, true)
	await frames(3)
	check(host.state == "playing" and not host.player._input.attack and host.player.weapon_phase == &"idle", "pad retry X does not leak strike")
	pad(JOY_BUTTON_X, false); await frames(2)
	pad(JOY_BUTTON_X, true); await frames(2)
	check(host.player.weapon_phase != &"idle", "fresh X still strikes after retry")
	await fresh()
	tap(JOY_BUTTON_BACK)
	check(host.state == "journal", "pad Back opens journal")
	pad(JOY_BUTTON_DPAD_RIGHT, true)
	var page: int = host.journal_page
	pad(JOY_BUTTON_DPAD_RIGHT, true)
	check(host.journal_page == page, "held Dpad does not repeatedly page")
	tap(JOY_BUTTON_B)
	await frames(3)
	check(host.state == "playing" and host.player._input.x == 0, "journal Dpad does not leak movement on B close")
	pad(JOY_BUTTON_DPAD_RIGHT, false); await frames(2)
	pad(JOY_BUTTON_DPAD_RIGHT, true); await frames(1)
	check(host.player._input.x > 0, "released journal Dpad rearms movement")
	await fresh()
	host.state = "archive"; paused = true
	pad(JOY_BUTTON_A, true); await frames(3)
	check(host.state == "playing" and not host.player._input.jump, "archive close A does not jump")
	await fresh()
	host.state = "choice"; paused = true
	pad(JOY_BUTTON_X, true); await frames(3)
	check(host.blind and host.state == "playing" and host.player.weapon_phase == &"idle", "trade X accepts without strike")
	await fresh()
	host.state = "upgrade"; paused = true
	pad(JOY_BUTTON_X, true); pad(JOY_BUTTON_X, true)
	await frames(3)
	check(host.sector == 1 and host.upgrades == ["force"] and host.player.weapon_phase == &"idle", "held upgrade X commits one force upgrade without strike")
	await fresh()
	host.state = "dead"; paused = true
	pad(JOY_BUTTON_A, true); await frames(3)
	check(host.state == "playing" and not host.player._input.jump, "dead retry A does not jump")
	await fresh()
	tap(JOY_BUTTON_B)
	check(host.tap_cooldown > 0, "playing B produces sonar tap")
	var goal = load("res://campaign/logic/objective.tscn").instantiate()
	goal.configure({"id": "pad_fixture", "label": "Pad fixture", "kind": "recover", "at": host.player.position}, host)
	host.room.add_child(goal); host.goals.append(goal); goal.changed.connect(host._goal_changed.bind(goal))
	tap(JOY_BUTTON_Y)
	check(goal.completed, "playing Y reaches real objective interaction")
	await fresh()
	host.state = "final_choice"; paused = true
	pad(JOY_BUTTON_X, true)
	check(host.state == "complete" and host.campaign_ending == "public_record", "final X selects public record")
	tap(JOY_BUTTON_A)
	check(host.state == "title", "complete A returns title")
	# Device intent must survive harmless releases/noise and propagate all the way
	# to the actual View rather than merely updating the adapter's local state.
	await fresh()
	keyboard(KEY_Z, true); keyboard(KEY_Z, false)
	stick(.15)
	check(adapter.input_device == "keyboard", "stick drift does not steal keyboard prompt")
	stick(.8)
	await frames(2)
	check(adapter.input_device == "controller", "intentional stick selects controller prompt")
	keyboard(KEY_Z, false)
	check(adapter.input_device == "controller", "keyboard release does not steal controller prompt")
	var view_data: Dictionary = host.hud.get_node("View").data
	check(view_data.get("input_device") == "controller", "controller device reaches real HUD View")
	stick(0)
	Input.joy_connection_changed.emit(1, false)
	check(host.state == "playing", "inactive controller disconnect does not pause")
	Input.joy_connection_changed.emit(0, false)
	check(host.state == "paused" and paused and adapter.input_device == "keyboard", "active controller disconnect pauses")
	Input.joy_connection_changed.emit(0, true)
	await frames(2)
	check(host.state == "paused" and paused, "reconnection never silently resumes")
	tap(JOY_BUTTON_B)
	await frames(2)
	check(host.state == "playing", "pad B explicitly resumes disconnect pause")
