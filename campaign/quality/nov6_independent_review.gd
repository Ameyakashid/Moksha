extends SceneTree
## Independent adversarial review. Scene/menu fixtures are explicit; device input
## enters through Input.parse_input_event, not the campaign input override.
const GATE = preload("res://campaign/logic/campaign_input_gate.gd")
const HUD = preload("res://campaign/views/campaign_hud.gd")
var host: Node
var failures: Array[String] = []
var checks := 0
var observations: Array[Dictionary] = []
var hz := 120

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func device(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func tap(code: int) -> void:
	device(code, true)
	device(code, false)

func release_all() -> void:
	for code in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_SPACE, KEY_C, KEY_SHIFT, KEY_J, KEY_K]: device(code, false)

func fresh() -> void:
	release_all()
	host.input_override = null
	host.start_new(true)
	await frames(4)

func neutral_actor(label: String) -> void:
	var input: Dictionary = host.player._input
	check(input.x == 0 and input.y == 0, label + " neutral axes")
	for name_ in ["jump", "roll", "attack", "shield"]:
		check(not input[name_] and not input[name_ + "_pressed"], label + " no " + name_)

func menu_device_case(menu: String, close_key: int) -> void:
	await fresh()
	# Opening every menu is a direct fixture so this isolates exit-boundary behavior.
	host.state = menu
	paused = true
	# Space is itself an intro-dismiss action; use the C jump alias while preparing
	# that modal so later held inputs are not accidentally fresh gameplay presses.
	for code in [KEY_D, KEY_W, KEY_C if menu == "intro" else KEY_SPACE, KEY_SHIFT]: device(code, true)
	if menu not in ["choice", "upgrade", "final_choice"]:
		device(KEY_J, true)
		device(KEY_K, true)
	await frames(2)
	tap(close_key)
	await frames(3)
	check(host.state == "playing", menu + " exits to gameplay")
	neutral_actor(menu + " held device input")
	release_all()
	await frames(2)
	device(KEY_D, true)
	device(KEY_SPACE, true)
	await frames(1)
	check(host.player._input.x > 0 and host.player._input.jump, menu + " fresh inputs rearm")
	release_all()

func run() -> void:
	host = load("res://campaign/campaign.tscn").instantiate()
	host.save_enabled = false
	root.add_child(host)
	for pair in [["intro", KEY_ENTER], ["journal", KEY_ESCAPE], ["paused", KEY_ESCAPE], ["archive", KEY_ENTER], ["choice", KEY_K], ["upgrade", KEY_L], ["dead", KEY_ENTER]]:
		await menu_device_case(pair[0], pair[1])
	# Real entry and exit callbacks, with held movement before opening pause.
	await fresh()
	device(KEY_D, true)
	await frames(5)
	check(host.player._input.x > 0, "device movement reaches actual actor before pause")
	tap(KEY_ESCAPE)
	check(host.state == "paused", "device Escape opens pause")
	tap(KEY_ESCAPE)
	await frames(4)
	check(host.state == "playing" and host.player._input.x == 0, "same-event-loop pause/resume suppresses held movement")
	release_all()
	await frames(2)
	device(KEY_D, true)
	await frames(1)
	check(host.player._input.x > 0, "same-event-loop pause/resume can rearm")
	# Button aliases: one held key must keep the action blocked until every alias releases.
	await fresh()
	tap(KEY_TAB)
	device(KEY_SPACE, true)
	device(KEY_C, true)
	tap(KEY_ESCAPE)
	await frames(2)
	device(KEY_SPACE, false)
	await frames(2)
	check(not host.player._input.jump, "releasing only one held jump alias does not clear gate")
	device(KEY_C, false)
	await frames(2)
	device(KEY_SPACE, true)
	await frames(1)
	check(host.player._input.jump and host.player.velocity.y < 0, "last alias release rearms real jump")
	# Automatic intro expiration does not call the key wrapper.
	await fresh()
	host.state = "intro"
	host.intro_time = 3.68
	paused = true
	device(KEY_D, true)
	device(KEY_J, true)
	await frames(8)
	check(host.state == "playing", "automatic intro expiration resumes")
	check(host.player._input.x == 0 and not host.player._input.attack, "automatic intro expiration suppresses held device input")
	release_all()
	# Focus loss is a separate asynchronous boundary, including actions queued
	# earlier in the same event batch. It must not silently resume behind another app.
	await fresh()
	tap(KEY_R)
	root.focus_exited.emit()
	var retry_pause_elapsed: float = host.elapsed
	await frames(3)
	check(host.state == "paused" and paused and host.elapsed == retry_pause_elapsed, "focus loss suspends already-queued retry")
	await fresh()
	host.state = "upgrade"
	paused = true
	tap(KEY_L)
	root.focus_exited.emit()
	await frames(3)
	check(host.state == "paused" and paused and host.sector == 0, "focus loss suspends upgrade transition before loading")
	await fresh()
	host.start_new(false)
	host.intro_time = 3.68
	root.focus_exited.emit()
	var intro_pause_elapsed: float = host.elapsed
	await frames(8)
	check(host.state != "playing" and paused and host.elapsed == intro_pause_elapsed, "focus loss prevents timed intro from starting gameplay off-focus")
	check(is_equal_approx(host.intro_time, 3.68), "focus pause freezes remaining intro timer")
	tap(KEY_ESCAPE)
	check(host.state == "intro" and paused, "explicit resume restores the suspended intro")
	await frames(8)
	check(host.state == "playing" and not paused, "resumed intro finishes normally")
	await fresh()
	# The pure gate must preserve every unrelated caller field and analog axis value.
	var gate = GATE.new()
	var raw := {"right": .37, "attack": true, "metadata": {"id": 1}}
	check(gate.filter_frame(raw) == raw, "unblocked frame is semantically unchanged")
	gate.suppress_held(raw)
	var filtered: Dictionary = gate.filter_frame(raw)
	check(filtered.right == 0 and not filtered.attack and filtered.attack_released, "gate blocks held analog/button with release")
	check(raw.right == .37 and raw.attack and filtered.metadata == raw.metadata, "gate preserves caller data")
	gate.filter_frame({})
	check(gate.filter_frame(raw) == raw, "neutral frame rearms pure gate")
	# Measure overlap separately: this is an observation, not subjective visual acceptance.
	var view := HUD.new()
	var worst: Dictionary = {"overlap": 0.0}
	for d in host.sectors:
		for spec in d.get("objectives", []):
			var notice: String = spec.label + " · COMPLETE" + (" — " + str(spec.text) if spec.has("text") else "")
			var layout: Dictionary = view.playing_layout({"notice_visible": true, "notice": notice})
			var overlap := maxf(0, minf(300.0, float(layout.context_top) + float(layout.context_height)) - maxf(264.0, float(layout.context_top)))
			if spec.at.y == 300 and overlap > float(worst.overlap):
				worst = {"district": d.id, "goal": spec.id, "notice": notice, "context_top": layout.context_top, "floor_body_overlap_pixels": overlap, "overlap": overlap}
	observations.append(worst)
	view.free()
	print("NOV6_INDEPENDENT_RESULT " + JSON.stringify({"passed": failures.is_empty(), "checks": checks, "hz": hz, "failures": failures, "observations": observations, "scope": "Explicit menu/scene fixtures with Input.parse_input_event device path, actor physics and static presentation overlap; not native acceptance or full campaign traversal."}))
	release_all()
	host.free()
	quit(0 if failures.is_empty() else 1)
