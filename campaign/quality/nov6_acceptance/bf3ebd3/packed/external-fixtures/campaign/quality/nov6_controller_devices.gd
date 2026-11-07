extends SceneTree
## Self-contained acceptance fixture. It can run from source or as an external
## --script against the exported PCK. All res:// paths are production resources.
## Synthetic Godot input events, not physical-controller hardware validation.
var host: Node
var device_id := 0
var checks := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var baseline := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
		if arg == "--baseline": baseline = true
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	var context := "device %d: %s" % [device_id, label]
	records.append({"device": device_id, "check": label, "passed": ok})
	if not ok: failures.append(context)

func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame

func pad(code: int, down: bool, device := -2) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device_id if device == -2 else device
	event.button_index = code; event.pressed = down
	Input.parse_input_event(event); Input.flush_buffered_events()

func button(code: int, down: bool) -> void: pad(code, down)
func tap(code: int, device := -2) -> void: pad(code, true, device); pad(code, false, device)

func axis(code: int, value: float, device := -2) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device_id if device == -2 else device
	event.axis = code; event.axis_value = value
	Input.parse_input_event(event); Input.flush_buffered_events()

func stick(value: float, device := -2) -> void: axis(JOY_AXIS_LEFT_X, value, device)

func keyboard(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code; event.pressed = down
	Input.parse_input_event(event); Input.flush_buffered_events()

func release_all() -> void:
	for device in [0, 1, 3]:
		for code in range(16): pad(code, false, device)
		axis(JOY_AXIS_LEFT_X, 0, device); axis(JOY_AXIS_LEFT_Y, 0, device)
	for code in [KEY_SPACE, KEY_J, KEY_K, KEY_SHIFT, KEY_D, KEY_TAB, KEY_ESCAPE, KEY_Z]: keyboard(code, false)

func fresh() -> void:
	release_all(); host.start_new(true); host.input_override = null
	await frames(4)

func run() -> void:
	for device in [0, 1, 3]:
		device_id = device
		host = load("res://campaign/campaign.tscn").instantiate()
		host.save_enabled = false; root.add_child(host)
		await frames(3)
		await controller_cases()
		await gameplay_cases()
		release_all(); host.free(); await frames(2)
	print("NOV6_CONTROLLER_DEVICES_RESULT " + JSON.stringify({"passed": failures.is_empty(), "checks": checks, "hz": Engine.physics_ticks_per_second, "devices": [0, 1, 3], "baseline": baseline, "failures": failures, "records": records, "scope": "Native synthetic input pipeline and actual campaign actor; no hardware or full-traversal claim."}))
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
	Input.joy_connection_changed.emit(7, false)
	check(host.state == "playing", "inactive controller disconnect does not pause")
	Input.joy_connection_changed.emit(device_id, false)
	check(host.state == "paused" and paused and adapter.input_device == "keyboard", "active controller disconnect pauses")
	Input.joy_connection_changed.emit(device_id, true)
	await frames(2)
	check(host.state == "paused" and paused, "reconnection never silently resumes")
	tap(JOY_BUTTON_B)
	await frames(2)
	check(host.state == "playing", "pad B explicitly resumes disconnect pause")

func gameplay_cases() -> void:
	await fresh()
	for row in [[JOY_AXIS_LEFT_X,-1.0,"left"],[JOY_AXIS_LEFT_X,1.0,"right"],[JOY_AXIS_LEFT_Y,-1.0,"up"],[JOY_AXIS_LEFT_Y,1.0,"down"]]:
		axis(row[0],row[1]); await frames(2)
		check(is_equal_approx(host._raw_campaign_input()[row[2]],1.0),"full axis "+row[2])
		if row[2] in ["left","right"]: check(is_equal_approx(host.player._input.x,row[1]),"actor axis "+row[2])
		else: check(is_equal_approx(host.player._input.physical_y,row[1]),"actor axis "+row[2])
		axis(row[0],0); await frames(2)
		check(is_zero_approx(host._raw_campaign_input()[row[2]]),"axis release "+row[2])
	axis(JOY_AXIS_LEFT_X,0.15); await frames(2)
	check(is_zero_approx(host.player._input.x),"below source deadzone stays neutral")
	axis(JOY_AXIS_LEFT_X,0.625); await frames(2)
	check(is_equal_approx(host.player._input.x,0.5),"source deadzone preserves half-strength response")
	axis(JOY_AXIS_LEFT_X,0)
	for row in [[JOY_BUTTON_DPAD_LEFT,"left",-1.0],[JOY_BUTTON_DPAD_RIGHT,"right",1.0],[JOY_BUTTON_DPAD_UP,"up",-1.0],[JOY_BUTTON_DPAD_DOWN,"down",1.0]]:
		button(row[0],true); await frames(2)
		check(is_equal_approx(host._raw_campaign_input()[row[1]],1.0),"Dpad "+row[1])
		button(row[0],false); await frames(2)
		check(is_zero_approx(host._raw_campaign_input()[row[1]]),"Dpad release "+row[1])
	await fresh(); button(JOY_BUTTON_A,true); await frames(2)
	check(host.player._input.jump and host.player.velocity.y<0,"A admits real jump")
	tap(JOY_BUTTON_START); button(JOY_BUTTON_A,false); await frames(5); tap(JOY_BUTTON_START); await frames(1)
	check(not host.player._input.jump and host.player._input.jump_released and host.player.velocity.y>=-host.player.profile.jump_release_rise_cap-1.0,"jump release during pause cuts on resume")
	await fresh(); button(JOY_BUTTON_LEFT_SHOULDER,true); await frames(2)
	check(host.player._input.shield and host.player.shield_phase!=&"idle","LB admits real guard")
	tap(JOY_BUTTON_START); button(JOY_BUTTON_LEFT_SHOULDER,false); await frames(5); tap(JOY_BUTTON_START); await frames(1)
	check(not host.player._input.shield and host.player._input.shield_released,"guard release during pause reaches actor")
	await frames(ceili(0.5 * Engine.physics_ticks_per_second)); check(host.player.shield_phase==&"idle","guard settles after release")
	await fresh(); button(JOY_BUTTON_RIGHT_SHOULDER,true); await frames(2)
	check(host.player._input.roll and host.player.roll_phase!=&"idle","RB admits real roll")
	await fresh(); button(JOY_BUTTON_X,true); await frames(2)
	check(host.player._input.attack and host.player.weapon_phase!=&"idle","X admits real strike")
	# Every held action uses the same modal release/rearm boundary.
	for row in [[JOY_BUTTON_A,"jump"],[JOY_BUTTON_RIGHT_SHOULDER,"roll"],[JOY_BUTTON_X,"attack"],[JOY_BUTTON_LEFT_SHOULDER,"shield"]]:
		await fresh(); tap(JOY_BUTTON_BACK); button(row[0],true); tap(JOY_BUTTON_BACK); await frames(3)
		check(not host.player._input[row[1]],"journal held "+row[1]+" suppressed")
		button(row[0],false); await frames(2); button(row[0],true); await frames(2)
		check(host.player._input[row[1]],"journal released "+row[1]+" rearms")
	await fresh(); axis(JOY_AXIS_LEFT_X,1.0); tap(JOY_BUTTON_START); tap(JOY_BUTTON_START); await frames(2)
	check(is_zero_approx(host.player._input.x),"held analog direction suppressed after pause")
	axis(JOY_AXIS_LEFT_X,0); await frames(2); axis(JOY_AXIS_LEFT_X,1.0); await frames(2)
	check(host.player._input.x>0,"analog direction rearms after release")
