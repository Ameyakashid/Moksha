extends SceneTree
## Synthetic SDL-style joypad events enter the real root input pipeline.
## Fixtures may place actors/open gates; acceptance never calls menu handlers or
## supplies input_override. This is not a physical-device or traversal test.
const PAD := 0
const BUTTONS := [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y,
	JOY_BUTTON_BACK, JOY_BUTTON_START, JOY_BUTTON_LEFT_SHOULDER,
	JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
	JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]
var host: Node
var checks := 0
var failures: Array[String] = []
var records: Array[Dictionary] = []
var taps := 0

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	records.append({"passed":ok,"check":label})
	if not ok:
		failures.append(label)
		push_error(label)

func frames(count: int) -> void:
	for index in count:
		await physics_frame
		await process_frame

func button(index: int, pressed: bool, device := PAD) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(index: int, device := PAD) -> void:
	button(index, true, device)
	button(index, false, device)

func motion(axis: int, value: float, device := PAD) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func key(code: int, pressed := true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func release_all() -> void:
	for index in BUTTONS: button(index, false)
	motion(JOY_AXIS_LEFT_X, 0)
	motion(JOY_AXIS_LEFT_Y, 0)

func fresh() -> void:
	release_all()
	host.start_new(true)
	for enemy in host.enemies: enemy.queue_free()
	await frames(4)
	check(host.input_override == null, "fixture retains real InputMap actor source")

func objective(id: String, kind: String, at: Vector2) -> Node:
	var goal = load("res://campaign/logic/objective.tscn").instantiate()
	goal.configure({"id":id,"label":id,"kind":kind,"at":at,"target":1}, host)
	host.room.add_child(goal)
	goal.changed.connect(host._goal_changed.bind(goal))
	host.goals.append(goal)
	return goal

func noise(_at: Vector2, kind: StringName, _loudness: float, source: Node) -> void:
	if kind == &"weapon_tap" and source == host.player: taps += 1

func run() -> void:
	host = load("res://campaign/campaign.tscn").instantiate()
	host.save_enabled = false
	root.add_child(host)
	await frames(3)
	check(host.state == "title" and host.gamepad_navigation.input_device == "keyboard", "title defaults to keyboard without controller hardware assumption")
	motion(JOY_AXIS_LEFT_X, 0.2)
	motion(JOY_AXIS_LEFT_X, 0)
	motion(JOY_AXIS_RIGHT_X, 1.0)
	check(host.gamepad_navigation.input_device == "keyboard", "stick noise and unused right stick do not change prompt device")
	tap(JOY_BUTTON_X)
	check(host.state == "title" and not is_instance_valid(host.player), "X without valid checkpoint cannot manufacture Continue")
	button(JOY_BUTTON_DPAD_RIGHT, true)
	button(JOY_BUTTON_DPAD_RIGHT, true)
	check(host.lens == "strength", "title right selects exactly one lens until physical release")
	button(JOY_BUTTON_DPAD_RIGHT, false)
	tap(JOY_BUTTON_DPAD_RIGHT)
	check(host.lens == "agility", "title right selects agility after release")
	tap(JOY_BUTTON_DPAD_RIGHT)
	tap(JOY_BUTTON_DPAD_LEFT)
	check(host.lens == "agility", "title lenses wrap in both directions")
	check(host._hud_snapshot().input_device == "controller", "intentional joypad input reaches campaign HUD snapshot")
	button(JOY_BUTTON_A, true)
	check(host.state == "intro", "title A starts the campaign through root input pipeline")
	button(JOY_BUTTON_A, true)
	check(host.state == "intro", "held A cannot double-accept title then intro")
	button(JOY_BUTTON_A, false)
	button(JOY_BUTTON_A, true)
	await frames(4)
	check(host.state == "playing" and not host.player._input.jump and host.player.velocity.y >= 0, "intro A skips without leaking held jump")
	button(JOY_BUTTON_A, false)
	await frames(2)
	button(JOY_BUTTON_A, true)
	await frames(2)
	check(host.player.velocity.y < 0, "fresh A after release uses original actor jump")
	button(JOY_BUTTON_A, false)
	await fresh()
	motion(JOY_AXIS_LEFT_X, 1)
	await frames(3)
	check(host.player._input.x > 0, "left stick still drives original actor movement")
	motion(JOY_AXIS_LEFT_X, 0)
	button(JOY_BUTTON_LEFT_SHOULDER, true)
	await frames(2)
	check(host.player._input.shield and host.player.shield_phase != &"idle", "LB retains original actor shield")
	button(JOY_BUTTON_LEFT_SHOULDER, false)
	await frames(2)
	button(JOY_BUTTON_RIGHT_SHOULDER, true)
	await frames(2)
	check(host.player._input.roll, "RB retains original actor roll")
	button(JOY_BUTTON_RIGHT_SHOULDER, false)
	await fresh()
	var route := objective("controller route", "route", host.player.position)
	button(JOY_BUTTON_Y, true)
	button(JOY_BUTTON_Y, true)
	check(route.setting == 0, "Y interacts once despite duplicate held press")
	button(JOY_BUTTON_Y, false)
	tap(JOY_BUTTON_Y)
	check(route.completed and route.setting == 1, "fresh Y cycles real route objective again")
	host.bus.noise_emitted.connect(noise)
	button(JOY_BUTTON_B, true)
	button(JOY_BUTTON_B, true)
	check(taps == 1 and host.tap_cooldown > 0, "B emits one real sonar tap without duplicate side effects")
	button(JOY_BUTTON_B, false)
	for index in 7: objective("journal row %d" % index, "terminal", Vector2(500 + index * 80, 300))
	tap(JOY_BUTTON_BACK)
	check(host.state == "journal" and paused, "Back opens paused field journal")
	button(JOY_BUTTON_DPAD_RIGHT, true)
	button(JOY_BUTTON_DPAD_RIGHT, true)
	check(host.journal_page == 1, "journal paging is one page per fresh press")
	button(JOY_BUTTON_X, true)
	tap(JOY_BUTTON_B)
	var before: Vector2 = host.player.position
	await frames(4)
	check(host.state == "playing" and host.player.position.distance_to(before) < 1 and host.player.weapon_phase == &"idle", "journal close suppresses held direction and strike")
	button(JOY_BUTTON_DPAD_RIGHT, false)
	button(JOY_BUTTON_X, false)
	await frames(2)
	button(JOY_BUTTON_X, true)
	await frames(2)
	check(host.player.weapon_phase != &"idle", "fresh X rearms original actor strike after journal")
	button(JOY_BUTTON_X, false)
	await fresh()
	tap(JOY_BUTTON_START)
	var paused_elapsed: float = host.elapsed
	await frames(3)
	check(host.state == "paused" and paused and host.elapsed == paused_elapsed, "Start pauses scene and active play clock")
	tap(JOY_BUTTON_B)
	check(host.state == "playing" and not paused, "paused B resumes")
	tap(JOY_BUTTON_START)
	var previous_actor: int = host.player.get_instance_id()
	button(JOY_BUTTON_X, true)
	button(JOY_BUTTON_X, true)
	await frames(4)
	check(host.state == "playing" and host.player.get_instance_id() != previous_actor and host.player.weapon_phase == &"idle", "paused X retries district once without striking new actor")
	button(JOY_BUTTON_X, false)
	await frames(2)
	tap(JOY_BUTTON_START)
	tap(JOY_BUTTON_Y)
	check(host.state == "title", "paused Y returns to title")
	tap(JOY_BUTTON_START)
	check(host.state == "intro", "title Start also begins new campaign")
	tap(JOY_BUTTON_START)
	check(host.state == "playing", "fresh Start skips intro")
	await fresh()
	for decision in [JOY_BUTTON_B, JOY_BUTTON_X]:
		host.state = "choice"; paused = true
		button(decision, true)
		await frames(3)
		check(host.state == "playing" and host.blind == (decision == JOY_BUTTON_X) and host.player.weapon_phase == &"idle", "sight choice %d uses same decision path without combat leakage" % decision)
		button(decision, false)
		await frames(2)
	# A modal fixture represents an already discovered archive, not traversal.
	host.state = "archive"; paused = true
	button(JOY_BUTTON_A, true)
	await frames(3)
	check(host.state == "playing" and not host.player._input.jump, "archive A returns without jumping")
	button(JOY_BUTTON_A, false)
	await frames(2)
	for decision in [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_B]:
		await fresh()
		host.state = "upgrade"; paused = true
		button(decision, true)
		button(decision, true)
		await frames(4)
		var expected: String = {JOY_BUTTON_X:"force", JOY_BUTTON_Y:"agility", JOY_BUTTON_B:"vitality"}[decision]
		check(host.state == "playing" and host.sector == 1 and host.upgrades == [expected] and host.player.weapon_phase == &"idle", "upgrade %s applies once, ascends once, and suppresses held attack" % expected)
		button(decision, false)
		await frames(2)
	for decision in [JOY_BUTTON_X, JOY_BUTTON_Y]:
		await fresh()
		host.state = "final_choice"; paused = true
		button(decision, true)
		button(decision, true)
		var expected: String = "public_record" if decision == JOY_BUTTON_X else "local_custody"
		check(host.state == "complete" and host.campaign_ending == expected and host.level_receipts.size() == 1, "final %s records exactly one ending" % expected)
		button(decision, false)
		tap(JOY_BUTTON_A)
		check(host.state == "title", "completion A returns to title")
	await fresh()
	host._on_defeat()
	button(JOY_BUTTON_A, true)
	await frames(4)
	check(host.state == "playing" and host.deaths == 1 and not host.player._input.jump, "death A retries without jump or lost death count")
	button(JOY_BUTTON_A, false)
	host._on_defeat()
	tap(JOY_BUTTON_Y)
	check(host.state == "title", "death Y returns to title")
	await fresh()
	button(JOY_BUTTON_DPAD_RIGHT, true)
	await frames(2)
	Input.joy_connection_changed.emit(PAD, false)
	var disconnected_elapsed: float = host.elapsed
	await frames(3)
	check(host.state == "paused" and paused and host.elapsed == disconnected_elapsed and host.gamepad_navigation.input_device == "keyboard", "active controller disconnect pauses and exposes keyboard fallback")
	Input.joy_connection_changed.emit(PAD, true)
	await frames(2)
	check(host.state == "paused" and paused, "controller reconnect never silently resumes")
	tap(JOY_BUTTON_START)
	await frames(3)
	check(host.state == "playing" and host.player._input.x == 0, "explicit resume suppresses held disconnected direction")
	button(JOY_BUTTON_DPAD_RIGHT, false)
	await frames(2)
	button(JOY_BUTTON_DPAD_RIGHT, true)
	await frames(2)
	check(host.player._input.x > 0, "direction rearms after release following disconnect")
	button(JOY_BUTTON_DPAD_RIGHT, false)
	key(KEY_TAB)
	key(KEY_TAB, false)
	check(host.state == "journal" and host.gamepad_navigation.input_device == "keyboard", "keyboard journal command coexists and restores keyboard prompts")
	motion(JOY_AXIS_LEFT_X, 0.2)
	check(host.gamepad_navigation.input_device == "keyboard", "analog jitter cannot steal active keyboard prompts")
	motion(JOY_AXIS_LEFT_X, 0.8)
	check(host.gamepad_navigation.input_device == "controller", "deliberate left-stick deflection changes prompt device")
	motion(JOY_AXIS_LEFT_X, 0)
	Input.joy_connection_changed.emit(3, false)
	check(host.state == "journal", "unrelated controller disconnect preserves menu")
	tap(JOY_BUTTON_BACK)
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	check(host.state == "paused", "keyboard Escape still pauses after controller use")
	key(KEY_ESCAPE)
	key(KEY_ESCAPE, false)
	check(host.state == "playing", "keyboard Escape still resumes after controller use")
	# The test runner must provide an isolated writable HOME/XDG save directory.
	await fresh()
	host.save_enabled = true
	host.lens = "strength"
	host.upgrades.assign(["vitality"])
	host.load_sector(1)
	tap(JOY_BUTTON_START)
	tap(JOY_BUTTON_Y)
	check(host.state == "title" and host.continue_available, "real controller title return exposes saved checkpoint")
	button(JOY_BUTTON_X, true)
	await frames(4)
	check(host.state == "playing" and host.sector == 1 and host.lens == "strength" and host.upgrades == ["vitality"] and host.player.weapon_phase == &"idle", "title X restores real checkpoint without attack leakage")
	release_all()
	print("NOV6_GAMEPAD_NAVIGATION_RESULT " + JSON.stringify({"passed":failures.is_empty(),"checks":checks,"hz":Engine.physics_ticks_per_second,"failures":failures,"records":records,"scope":"Synthetic Input.parse_input_event joypad events through real campaign event pipeline; controlled modal/world fixtures; no input_override, physical controller, full traversal, or hardware compatibility claim."}))
	host.free()
	quit(0 if failures.is_empty() else 1)
