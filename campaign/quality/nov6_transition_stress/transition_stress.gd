extends SceneTree
## Bounded command sequences on a frozen production snapshot. Fixtures initialize
## real authored modal-entry locations; this does not simulate a full traversal.
var host: Node
var checks := 0
var failures: Array[Dictionary] = []
var trace: Array[String] = []
var rng := RandomNumberGenerator.new()
var seed_base := 719035
var seed_count := 48
var steps := 96
var hz := 60
var output := ""
var mode := "all"
var mutation := ""
var case_name := "boot"
var scenario_count := 0
var event_count := 0
var model: Dictionary = {}
var state_visits: Dictionary = {}
var command_hash := HashingContext.new()
const BUTTON_KEYS := [KEY_ENTER, KEY_ESCAPE, KEY_TAB, KEY_R, KEY_N, KEY_C, KEY_J, KEY_K, KEY_L, KEY_1, KEY_2, KEY_3, KEY_E, KEY_Q, KEY_LEFT, KEY_RIGHT, KEY_SPACE]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
		if arg.begins_with("--seeds="): seed_count = int(arg.trim_prefix("--seeds="))
		if arg.begins_with("--steps="): steps = int(arg.trim_prefix("--steps="))
		if arg.begins_with("--seed="): seed_base = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg.begins_with("--mode="): mode = arg.trim_prefix("--mode=")
		if arg.begins_with("--mutation="): mutation = arg.trim_prefix("--mutation=")
	Engine.physics_ticks_per_second = hz
	command_hash.start(HashingContext.HASH_SHA256)
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok and failures.size() < 40:
		failures.append({"case": case_name, "label": label, "trace": trace.duplicate(), "observed": observation(), "model": model.duplicate(true)})
func observation() -> Dictionary:
	if not is_instance_valid(host): return {}
	return {"state": host.state, "paused": paused, "sector": host.sector, "pending": host._pending_sector, "retry": host._pending_retry, "focus": host._focus_pause_active, "lens": host.lens, "upgrades": host.upgrades.duplicate(), "metrics": host.metrics.size(), "receipts": host.level_receipts.size(), "elapsed": host.elapsed}
func event_key(code: int, pressed: bool, logical := false, echo := false) -> void:
	var event := InputEventKey.new()
	event.pressed = pressed; event.echo = echo
	if logical: event.keycode = code
	else: event.physical_keycode = code
	Input.parse_input_event(event); Input.flush_buffered_events()
func key(code: int, logical := false, echo := false) -> void:
	event_key(code, true, logical, echo); event_key(code, false, logical)
func joy_event(button: int, pressed: bool, device := 0) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button; event.pressed = pressed; event.device = device
	Input.parse_input_event(event); Input.flush_buffered_events()
func joy(button: int, device := 0) -> void:
	joy_event(button, true, device); joy_event(button, false, device)
func clear_devices() -> void:
	for code in BUTTON_KEYS + [KEY_A, KEY_D, KEY_W, KEY_S, KEY_SHIFT]: event_key(code, false)
	for button in 16: joy_event(button, false)
	for action in InputMap.get_actions(): Input.action_release(action)
	Input.flush_buffered_events()
func tick(count := 1) -> void:
	for index in count:
		await physics_frame
		host._physics_process(1.0 / hz)
		await process_frame
func fresh() -> void:
	clear_devices()
	host.start_new(true)
	host.input_override = null
	await tick(3)
	key(KEY_1) # Establish actual keyboard intent; releases do not change device.
	trace.clear()
func reset_model() -> void:
	model = {"state": "playing", "paused": false, "pending": -1, "retry": false, "focus": false, "resume": "playing", "sector": 0, "lens": host.lens, "controller": -1}
func model_key(code: int, echo := false, keyboard := true) -> void:
	if echo: return
	if keyboard: model.controller = -1
	if model.focus:
		if code == KEY_ESCAPE:
			model.focus = false
			model.state = "transition" if model.pending >= 0 else model.resume
			model.paused = model.state == "intro"
			return
		if code == KEY_R:
			model.pending = -1; model.retry = true; return
		if code == KEY_N:
			model.pending = -1; model.retry = false; model.focus = false; model.state = "title"; model.paused = true; return
	if model.pending >= 0 or model.retry: return
	match model.state:
		"title":
			if code in [KEY_1, KEY_2, KEY_3]: model.lens = {KEY_1:"neutral", KEY_2:"strength", KEY_3:"agility"}[code]
			elif code == KEY_ENTER: model.state = "intro"; model.paused = true; model.sector = 0; model.focus = false
			elif code == KEY_C and host.continue_available:
				var saved: Dictionary = host._decode_campaign_checkpoint()
				if saved.ok:
					model.state = "playing"; model.paused = false; model.sector = saved.sector; model.lens = saved.campaign.lens
		"intro":
			if code in [KEY_ENTER, KEY_SPACE, KEY_ESCAPE]: model.state = "playing"; model.paused = false
		"playing":
			if code == KEY_ESCAPE: model.state = "paused"; model.paused = true
			elif code == KEY_TAB: model.state = "journal"; model.paused = true
			elif code == KEY_R: model.retry = true
		"paused":
			if code == KEY_ESCAPE: model.state = "playing"; model.paused = false
			elif code == KEY_R: model.retry = true
			elif code == KEY_N: model.state = "title"; model.paused = true
		"journal":
			if code in [KEY_TAB, KEY_ESCAPE]: model.state = "playing"; model.paused = false
func model_focus() -> void:
	if model.state not in ["playing", "transition", "intro"] and model.pending < 0 and not model.retry: return
	model.resume = "intro" if model.state == "intro" else "playing"
	model.focus = true; model.state = "paused"; model.paused = true
func model_joy(button: int) -> void:
	model.controller = 0
	var code := KEY_NONE
	match model.state:
		"title":
			if button in [JOY_BUTTON_A, JOY_BUTTON_START]: code = KEY_ENTER
			elif button == JOY_BUTTON_X: code = KEY_C
			elif button in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
				var lenses := ["neutral", "strength", "agility"]
				var next := posmod(lenses.find(model.lens) + (-1 if button == JOY_BUTTON_DPAD_LEFT else 1), 3)
				code = [KEY_1, KEY_2, KEY_3][next]
		"intro":
			if button in [JOY_BUTTON_A, JOY_BUTTON_START]: code = KEY_ENTER
		"playing":
			if button == JOY_BUTTON_START: code = KEY_ESCAPE
			elif button == JOY_BUTTON_BACK: code = KEY_TAB
			elif button == JOY_BUTTON_Y: code = KEY_E
			elif button == JOY_BUTTON_B: code = KEY_Q
		"paused":
			if button in [JOY_BUTTON_START, JOY_BUTTON_B]: code = KEY_ESCAPE
			elif button == JOY_BUTTON_X: code = KEY_R
			elif button == JOY_BUTTON_Y: code = KEY_N
		"journal":
			if button in [JOY_BUTTON_B, JOY_BUTTON_BACK]: code = KEY_TAB
			elif button == JOY_BUTTON_DPAD_LEFT: code = KEY_LEFT
			elif button == JOY_BUTTON_DPAD_RIGHT: code = KEY_RIGHT
	if code != KEY_NONE: model_key(code, false, false)
func assert_model() -> void:
	for field in ["state", "sector", "lens"]: check(host.get(field) == model[field], "state model " + field)
	check(paused == model.paused, "tree pause agrees with model")
	check(host._focus_pause_active == model.focus, "focus latch agrees with model")
	check(host._pending_retry == model.retry and host._pending_sector == model.pending, "queued work agrees with model")
	check(host.upgrades.is_empty(), "basic commands cannot mint upgrades")
	check(host._decode_campaign_checkpoint().get("ok",false), "valid checkpoint survives command sequence")
	check(host.player.position.is_finite() and host.player.velocity.is_finite(), "actor finite after command sequence")
func fuzz_basic() -> void:
	for seed_index in seed_count:
		case_name = "basic_seed_" + str(seed_base + seed_index)
		rng.seed = seed_base + seed_index
		await fresh(); reset_model(); scenario_count += 1
		for index in steps:
			var op := rng.randi_range(0, 9)
			var time_before: float = host.elapsed
			if op <= 4:
				var code: int = BUTTON_KEYS[rng.randi_range(0, BUTTON_KEYS.size() - 1)]
				# E is meaningful at authored spawn in some future maps; basic
				# command fuzz deliberately uses the safe first district spawn.
				var logical := rng.randf() < 0.3
				var echo := rng.randf() < 0.15
				trace.append("key " + str(code) + " logical=" + str(logical) + " echo=" + str(echo))
				model_key(code, echo); key(code, logical, echo)
			elif op == 5:
				trace.append("focus out"); model_focus(); root.focus_exited.emit()
			elif op == 6:
				trace.append("focus in"); root.focus_entered.emit()
			elif op == 7:
				var button: int = [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_BACK, JOY_BUTTON_START, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT][rng.randi_range(0,7)]
				trace.append("joy " + str(button)); model_joy(button); joy(button)
			elif op == 8:
				trace.append("disconnect active controller")
				if model.controller == 0: model_focus(); model.controller = -1
				Input.joy_connection_changed.emit(0, false)
			else:
				trace.append("tick")
				if not model.focus:
					if model.pending >= 0: model.sector = model.pending; model.pending = -1; model.state = "playing"; model.paused = false
					if model.retry: model.retry = false; model.state = "playing"; model.paused = false
				await tick()
				if model.state != "playing": check(host.elapsed == time_before, "modal tick freezes campaign clock")
			assert_model(); event_count += 1
			state_visits[host.state] = int(state_visits.get(host.state, 0)) + 1
			command_hash.update((case_name + ":" + trace[-1] + ":" + str(host.state) + ":" + str(paused) + "\n").to_utf8_buffer())
			if not failures.is_empty(): return
func completed_exit_fixture(index: int) -> void:
	await fresh()
	host.load_sector(index)
	for enemy in host.enemies: enemy.queue_free()
	for goal in host.goals: goal.completed = true
	host.relay_on = true
	await tick(3)
	host._update_gate()
	var district: Dictionary = host.sectors[index]
	host.player.position = Vector2(float(district.width) - 45, float(district.get("gate_y", 300)))
	host.player.velocity = Vector2.ZERO
	check(host.room.gate_open, "initialized completed district opens authored exit")
	trace.clear(); key(KEY_E)
	check(host.state == "upgrade" and paused, "real E at authored exit opens upgrade")
func decline_hearing_offer(modelled := false) -> void:
	if host.state != "hearing_choice": return
	check(int(host.sectors[host.sector].level) == 1, "hearing offer follows first-level exit")
	check(paused and host._pending_sector == -1, "hearing offer keeps world paused before ascent")
	check(host.upgrades.size() == 1 and host.metrics.size() == 1 and host.level_receipts.size() == 1, "hearing offer retains one staged upgrade and exit receipt")
	var before := observation()
	var checkpoint_digest := FileAccess.get_sha256(host.CAMPAIGN_SAVE)
	trace.append("explicit hearing decline K")
	if modelled:
		check(model.state == "hearing_choice", "independent model predicts hearing offer")
		tx_key(KEY_K)
	key(KEY_K)
	check(host.hearing_retained, "normal K decline retains hearing")
	check(host.state == "transition" and not paused and host._pending_sector == host.sector + 1, "decline queues ordinary onward ascent")
	check(host.upgrades == before.upgrades and host.metrics.size() == before.metrics and host.level_receipts.size() == before.receipts, "decline does not duplicate staged progression")
	check(FileAccess.get_sha256(host.CAMPAIGN_SAVE) == checkpoint_digest, "decline does not commit before onward load")
	event_count += 1

func upgrade_sequences() -> void:
	var exits: Array[int] = []
	for i in host.sectors.size() - 1:
		if host.sectors[i].level != host.sectors[i+1].level: exits.append(i)
	var sequences := [
		["J", "J", "K", "L", "tick"],
		["K", "focus", "R", "R", "escape", "tick"],
		["L", "focus", "N", "continue", "tick"],
		["J", "focus", "R", "N", "continue", "tick"],
		["K", "focus", "escape", "tick", "R", "tick"],
		["L", "focus", "escape", "focus", "escape", "tick"],
		["joyX", "disconnect", "joyX", "joyB", "tick"],
		["joyY", "disconnect", "joyY", "continue", "tick"],
		["focus", "escape", "N", "R", "tab", "joyB", "tick"],
		["joyX", "joyX", "joyY", "joyB", "tick"]]
	for exit_index in exits:
		for seq_index in sequences.size():
			case_name = "upgrade_exit_%d_sequence_%d" % [exit_index, seq_index]
			model.clear(); scenario_count += 1
			await completed_exit_fixture(exit_index)
			for action in sequences[seq_index]:
				trace.append(action)
				match action:
					"J": key(KEY_J)
					"K": key(KEY_K)
					"L": key(KEY_L)
					"R": key(KEY_R)
					"N": key(KEY_N)
					"escape": key(KEY_ESCAPE)
					"tab": key(KEY_TAB)
					"focus": root.focus_exited.emit()
					"continue": key(KEY_C)
					"joyX": joy(JOY_BUTTON_X)
					"joyY": joy(JOY_BUTTON_Y)
					"joyB": joy(JOY_BUTTON_B)
					"disconnect": Input.joy_connection_changed.emit(0, false)
					"tick": await tick(3)
				decline_hearing_offer()
				check(host.upgrades.size() <= 1, "bounded upgrade granted at most once")
				check(host.level_receipts.size() <= 1 and host.metrics.size() <= 1, "bounded transition receipt recorded at most once")
				if host.state in ["upgrade", "paused", "journal", "title"]: check(paused, "transaction modal cannot unpause world")
				check(host._decode_campaign_checkpoint().get("ok",false), "valid checkpoint survives upgrade sequence")
				event_count += 1
			if host.sector == exit_index and host.state == "playing":
				check(host.upgrades.is_empty() and host.level_receipts.is_empty() and host.metrics.is_empty(), "old room retry/Continue rolls back whole uncommitted upgrade")
			elif host.sector == exit_index + 1:
				check(host.upgrades.size() == 1 and host.level_receipts.size() == 1 and host.metrics.size() == 1, "onward load commits exactly one whole upgrade")
			host._save_checkpoint()
			var digest := FileAccess.get_sha256(host.CAMPAIGN_SAVE)
			host._save_checkpoint(); host._save_checkpoint()
			check(FileAccess.get_sha256(host.CAMPAIGN_SAVE) == digest, "repeated unchanged save is byte-idempotent")
			if not failures.is_empty(): return

func open_modal_fixture(kind: String) -> void:
	await fresh()
	match kind:
		"intro": host.start_new(false)
		"journal": key(KEY_TAB)
		"pause": key(KEY_ESCAPE)
		"title": key(KEY_ESCAPE); key(KEY_N)
		"focus": root.focus_exited.emit()
		"disconnect": joy(JOY_BUTTON_DPAD_RIGHT); Input.joy_connection_changed.emit(0, false)
		"retry": key(KEY_ESCAPE)
		"choice":
			var index := -1
			for i in host.sectors.size():
				if host.sectors[i].has("station"): index = i; break
			host.load_sector(index)
			host.player.position = host.sectors[index].station
			host.player.velocity = Vector2.ZERO
			key(KEY_E)
			check(host.state == "choice" and paused, "real station E opens sight choice")
		"archive":
			host.player.position = host.sectors[0].cache
			host.player.velocity = Vector2.ZERO
			key(KEY_E)
			check(host.state == "archive" and paused, "real cache E opens archive")
		"upgrade": await completed_exit_fixture(5)
func close_modal(kind: String) -> void:
	match kind:
		"intro":
			if host.state == "intro": key(KEY_ENTER)
		"journal": key(KEY_TAB)
		"pause", "focus", "disconnect": key(KEY_ESCAPE)
		"title": key(KEY_C)
		"retry": key(KEY_R)
		"choice":
			if host.state == "choice": key(KEY_J)
		"archive": key(KEY_E)
		"upgrade":
			if host.state == "upgrade": key(KEY_L)
			decline_hearing_offer()
func held_boundaries() -> void:
	for boundary in ["intro", "journal", "pause", "title", "focus", "disconnect", "retry", "choice", "archive", "upgrade"]:
		for held in [KEY_D, KEY_A, KEY_W, KEY_S, KEY_J, KEY_K, KEY_SPACE, KEY_SHIFT]:
			case_name = "held_%s_%d" % [boundary, held]; model.clear(); scenario_count += 1
			await open_modal_fixture(boundary)
			trace.append("hold " + str(held)); event_key(held, true)
			trace.append("close " + boundary); close_modal(boundary)
			await tick(3)
			check(host.state == "playing" and not paused, "modal close reaches playing")
			var frame: Dictionary = host.player._input
			check(is_zero_approx(frame.x) and is_zero_approx(frame.y), "held direction does not cross modal")
			for button in ["jump", "roll", "attack", "shield"]:
				check(not frame[button] and not frame[button + "_pressed"], "held " + button + " does not cross modal")
			check(host.player.weapon_phase == &"idle" and host.player.shield_phase == &"idle", "modal action cannot start attack or shield")
			event_key(held, false); await tick(2)
			event_key(held, true); await tick(1)
			frame = host.player._input
			var action: String = {KEY_D:"right",KEY_A:"left",KEY_W:"up",KEY_S:"down",KEY_J:"attack",KEY_K:"shield",KEY_SPACE:"jump",KEY_SHIFT:"roll"}[held]
			if action == "right": check(frame.x > 0, "fresh right rearms")
			elif action == "left": check(frame.x < 0, "fresh left rearms")
			elif action == "up": check(frame.y < 0, "fresh up rearms")
			elif action == "down": check(frame.y > 0, "fresh down rearms")
			else: check(frame[action], "fresh " + action + " rearms")
			event_key(held, false); event_count += 4
			if not failures.is_empty(): return
	# Controller holds use actual joy motion/buttons and the same scene dispatch.
	for boundary in ["journal", "pause", "focus", "disconnect", "title", "choice", "archive", "upgrade"]:
		for action in ["stick", "attack", "jump", "shield", "roll"]:
			case_name = "joyheld_%s_%s" % [boundary, action]; model.clear(); scenario_count += 1
			await open_modal_fixture(boundary)
			var button: int = {"attack":JOY_BUTTON_X,"jump":JOY_BUTTON_A,"shield":JOY_BUTTON_LEFT_SHOULDER,"roll":JOY_BUTTON_RIGHT_SHOULDER}.get(action, -1)
			if action == "stick":
				var event := InputEventJoypadMotion.new(); event.device = 0; event.axis = JOY_AXIS_LEFT_X; event.axis_value = 1.0
				Input.parse_input_event(event); Input.flush_buffered_events()
			else: joy_event(button, true)
			trace.append("controller hold " + action)
			# Some face buttons have already chosen/closed their own menu.
			if host.state not in ["playing", "transition"]: close_modal(boundary)
			if host.state == "intro": key(KEY_ENTER)
			await tick(3)
			check(host.state == "playing" and not paused, "controller modal close reaches playing")
			var frame: Dictionary = host.player._input
			check(is_zero_approx(frame.x) and is_zero_approx(frame.y), "held stick does not cross modal")
			for name in ["jump", "roll", "attack", "shield"]: check(not frame[name], "held controller " + name + " does not cross modal")
			if action == "stick":
				var event := InputEventJoypadMotion.new(); event.device = 0; event.axis = JOY_AXIS_LEFT_X; event.axis_value = 0.0
				Input.parse_input_event(event); Input.flush_buffered_events(); await tick(2)
				event = InputEventJoypadMotion.new(); event.device = 0; event.axis = JOY_AXIS_LEFT_X; event.axis_value = 1.0
				Input.parse_input_event(event); Input.flush_buffered_events(); await tick()
				check(host.player._input.x > 0, "neutralized stick rearms")
				event = InputEventJoypadMotion.new(); event.device = 0; event.axis = JOY_AXIS_LEFT_X; event.axis_value = 0.0
				Input.parse_input_event(event); Input.flush_buffered_events()
			else:
				joy_event(button, false); await tick(2); joy_event(button, true); await tick()
				check(host.player._input[action], "fresh controller " + action + " rearms")
				joy_event(button, false)
			event_count += 4
			if not failures.is_empty(): return
func save_lifecycle() -> void:
	for sight in [false, true]:
		for lens in ["neutral", "strength", "agility"]:
			case_name = "save_lifecycle_%s_%s" % [str(sight),lens]; model.clear(); scenario_count += 1
			await open_modal_fixture("choice")
			# Lens is a declared starting-build fixture, established before
			# the real sight choice and all tested persistence transitions.
			host.lens = lens; host._apply_build(); key(KEY_J if sight else KEY_K)
			host._save_checkpoint()
			var build := {"speed":host.player.profile.run_speed,"capacity":host.health.capacity,"damage":host.player.melee_chain.steps[0].damage}
			var data: Dictionary = host._decode_campaign_checkpoint().campaign.duplicate(true)
			var room_ids: Dictionary = {}
			for repeat in 25:
				trace.append("pause/title/Continue " + str(repeat))
				var old_room: WeakRef = weakref(host.room); var old_actor: WeakRef = weakref(host.player)
				key(KEY_ESCAPE); key(KEY_N)
				var saved_hash := FileAccess.get_sha256(host.CAMPAIGN_SAVE)
				host._save_checkpoint(); host._save_checkpoint()
				check(FileAccess.get_sha256(host.CAMPAIGN_SAVE) == saved_hash, "repeated stable checkpoint identical bytes")
				key(KEY_C)
				check(host.state == "playing" and not paused, "Continue resumes saved room")
				check(old_room.get_ref() == null and old_actor.get_ref() == null, "Continue frees old room and actor")
				check(not room_ids.has(host.room.get_instance_id()), "Continue creates a fresh room identity")
				room_ids[host.room.get_instance_id()] = true
				check(host.blind == sight and host.lens == lens, "Continue preserves genuine sight choice and lens")
				check(is_equal_approx(host.player.profile.run_speed, build.speed) and is_equal_approx(host.health.capacity, build.capacity) and is_equal_approx(host.player.melee_chain.steps[0].damage, build.damage), "Continue does not stack build")
				check(host._decode_campaign_checkpoint().campaign == data, "Continue roundtrip stable saved data")
				# Real deferred object-paint discovery from the just-freed room
				# is drained alongside discovery for its replacement.
				await process_frame
				host.object_paint._sync()
				for record in host.object_paint.records:
					var node = record.node.get_ref()
					check(is_instance_valid(node) and host.room.is_ancestor_of(node), "deferred paint discovery contains only current room")
				event_count += 3
				if not failures.is_empty(): return

func death_lifecycle() -> void:
	var sequences := [
		["enter", "enter", "R", "tick"],
		["enter", "focus", "tick", "escape", "tick"],
		["enter", "focus", "R", "N", "C", "tick"],
		["N", "C", "tick"],
		["focus", "escape", "N", "C", "tick"],
		["joyA", "disconnect", "tick", "joyB", "tick"]]
	for seq_index in sequences.size():
		case_name = "death_sequence_%d" % seq_index; model.clear(); scenario_count += 1
		await fresh()
		# Declared gravity-boundary fixture: begin outside the left floor edge,
		# above the authored lethal boundary. All death/damage is production
		# gravity + BoundaryReceiver; health and state are never written.
		host.player.reset_actor(Vector2(-60, 390), 1)
		var receipts: Array[Dictionary] = []
		host.health.damage_processed.connect(func(receipt: Dictionary): receipts.append(receipt.duplicate(true)))
		for frame in hz:
			await tick()
			if host.state == "dead": break
		check(host.state == "dead" and paused and host.health.current_health == 0, "gravity fixture reaches real dead state")
		check(host.deaths == 1 and receipts.size() == 1 and receipts[0].get("applied", 0) > 0, "genuine boundary death produces one receipt and death")
		var old_actor: WeakRef = weakref(host.player)
		var old_room: WeakRef = weakref(host.room)
		var old_health: WeakRef = weakref(host.health)
		var frozen_time: float = host.elapsed
		for action in sequences[seq_index]:
			trace.append(action)
			match action:
				"enter": key(KEY_ENTER)
				"escape": key(KEY_ESCAPE)
				"R": key(KEY_R)
				"N": key(KEY_N)
				"C": key(KEY_C)
				"focus": root.focus_exited.emit()
				"joyA": joy(JOY_BUTTON_A)
				"joyB": joy(JOY_BUTTON_B)
				"disconnect": Input.joy_connection_changed.emit(0, false)
				"tick": await tick(3)
			if host.state != "playing": check(host.elapsed == frozen_time, "death/focus modal freezes active clock")
			check(host.deaths == 1, "death/retry commands cannot duplicate or lose death")
			event_count += 1
		check(host.state == "playing" and not paused and host.health.current_health == host.health.capacity, "dead retry/Continue restores live district")
		check(old_room.get_ref() == null and old_actor.get_ref() == null and old_health.get_ref() == null, "dead retry retires old room actor health")
		check(receipts.size() == 1, "retired health emits no later receipt")
		check(host.player.weapon_phase == &"idle" and host.player.shield_phase == &"idle" and not host.player._input.jump, "death dismissal does not attack shield or jump")
		for row in host.bus.event_history:
			if int(row.source_id) == 0: continue
			var source = instance_from_id(int(row.source_id))
			check(is_instance_valid(source) and (source == host.room or host.room.is_ancestor_of(source)), "new room history has no stale old-room source")
		if not failures.is_empty(): return
func interrupted_actions() -> void:
	for action_key in [KEY_SPACE, KEY_J, KEY_K, KEY_SHIFT]:
		for boundary in ["retry", "focus_retry", "title_continue", "journal_retry"]:
			case_name = "inflight_%d_%s" % [action_key,boundary]; model.clear(); scenario_count += 1
			await fresh()
			event_key(action_key, true); await tick(2)
			var old_actor: WeakRef = weakref(host.player)
			var old_room: WeakRef = weakref(host.room)
			check(host.player._input[{KEY_SPACE:"jump",KEY_J:"attack",KEY_K:"shield",KEY_SHIFT:"roll"}[action_key]], "real action admitted before interruption")
			trace.append("admitted " + str(action_key)); trace.append(boundary)
			match boundary:
				"retry": key(KEY_R)
				"focus_retry": key(KEY_R); root.focus_exited.emit(); await tick(3); key(KEY_ESCAPE)
				"title_continue": key(KEY_ESCAPE); key(KEY_N); key(KEY_C)
				"journal_retry": key(KEY_TAB); await tick(3); key(KEY_TAB); key(KEY_R)
			await tick(3)
			check(host.state == "playing" and not paused and host.sector == 0, "interrupted action returns to live same district")
			check(old_actor.get_ref() == null and old_room.get_ref() == null, "in-flight actor and room retired")
			check(host.player.weapon_phase == &"idle" and host.player.shield_phase == &"idle", "in-flight weapon/shield cannot survive room replacement")
			check(not host.player._input.jump and not host.player._input.roll and not host.player._input.attack and not host.player._input.shield, "held old action cannot restart on replacement actor")
			check(host.health.current_health == host.health.capacity, "replacement actor has clean health")
			event_key(action_key, false); await tick(2); event_key(action_key, true); await tick()
			check(host.player._input[{KEY_SPACE:"jump",KEY_J:"attack",KEY_K:"shield",KEY_SHIFT:"roll"}[action_key]], "fresh action rearmed after interruption")
			event_key(action_key, false); event_count += 5
			if not failures.is_empty(): return

func tx_cancel() -> void:
	if model.txn:
		model.choice = ""; model.metrics = 0; model.receipts = 0; model.txn = false
func tx_save() -> void:
	model.saved = {"sector":model.sector,"choice":model.choice,"metrics":model.metrics,"receipts":model.receipts}
func tx_key(code: int, keyboard := true) -> void:
	if keyboard: model.controller = -1
	if model.focus:
		if code in [KEY_R, KEY_N]: tx_cancel()
		model_key(code, false, keyboard)
		if code == KEY_N: tx_save()
		return
	if model.pending >= 0 or model.retry: return
	if model.state == "upgrade":
		if code in [KEY_J, KEY_K, KEY_L]:
			model.choice = {KEY_J:"force",KEY_K:"agility",KEY_L:"vitality"}[code]
			if int(host.sectors[model.sector].level) == 1:
				model.state = "hearing_choice"; model.paused = true
			else:
				model.pending = model.sector + 1; model.state = "transition"; model.paused = false
		return
	if model.state == "hearing_choice":
		if code in [KEY_K, KEY_ESCAPE]:
			model.pending = model.sector + 1; model.state = "transition"; model.paused = false
		return
	var prior: String = model.state
	if prior == "paused" and code == KEY_N: tx_cancel()
	model_key(code, false, keyboard)
	if prior == "paused" and code == KEY_N: tx_save()
	if prior == "title" and code == KEY_C:
		model.sector = model.saved.sector; model.choice = model.saved.choice
		model.metrics = model.saved.metrics; model.receipts = model.saved.receipts; model.txn = false
func tx_joy(button: int) -> void:
	model.controller = 0
	var code := KEY_NONE
	match model.state:
		"upgrade": code = {JOY_BUTTON_X:KEY_J,JOY_BUTTON_Y:KEY_K,JOY_BUTTON_B:KEY_L}.get(button, KEY_NONE)
		"title":
			if button == JOY_BUTTON_X: code = KEY_C
		"paused": code = {JOY_BUTTON_X:KEY_R,JOY_BUTTON_Y:KEY_N,JOY_BUTTON_B:KEY_ESCAPE}.get(button, KEY_NONE)
		"playing":
			if button == JOY_BUTTON_BACK: code = KEY_TAB
			elif button == JOY_BUTTON_B: code = KEY_Q
			# Y interacts at the just-completed exit and could reopen upgrade;
			# keep this matrix focused on the existing transaction, not replay.
		"journal":
			if button in [JOY_BUTTON_BACK, JOY_BUTTON_B]: code = KEY_TAB
	if code != KEY_NONE: tx_key(code, false)
func tx_tick() -> void:
	if model.focus: return
	var loaded := false
	if model.pending >= 0:
		model.sector = model.pending; model.pending = -1; model.txn = false
		model.state = "playing"; model.paused = false; loaded = true
	if model.retry:
		tx_cancel(); model.retry = false; model.state = "playing"; model.paused = false; loaded = true
	if loaded: tx_save()
func upgrade_fuzz() -> void:
	var exits := [5,11,17,24]
	for seed_index in seed_count:
		case_name = "transaction_seed_" + str(seed_base + seed_index)
		rng.seed = seed_base + seed_index
		var exit_index: int = exits[seed_index % exits.size()]
		await completed_exit_fixture(exit_index); scenario_count += 1
		model = {"state":"upgrade","paused":true,"sector":exit_index,"pending":-1,"retry":false,"focus":false,"resume":"playing","controller":-1,"lens":host.lens,"choice":"","metrics":1,"receipts":1,"txn":true,"saved":{"sector":exit_index,"choice":"","metrics":0,"receipts":0}}
		for index in 48:
			var op := rng.randi_range(0,7)
			if op <= 3:
				var code: int = [KEY_J,KEY_K,KEY_L,KEY_R,KEY_N,KEY_ESCAPE,KEY_TAB,KEY_C][rng.randi_range(0,7)]
				trace.append("key " + str(code)); tx_key(code); key(code)
			elif op == 4:
				trace.append("focus out"); model_focus(); root.focus_exited.emit()
			elif op == 5:
				trace.append("tick"); tx_tick(); await tick()
			elif op == 6:
				var button: int = [JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_B,JOY_BUTTON_BACK][rng.randi_range(0,3)]
				# A Y at a playing exit is a new deliberate E interaction, not
				# part of this one-transaction model. Use Back in that case.
				if button == JOY_BUTTON_Y and model.state == "playing": button = JOY_BUTTON_BACK
				trace.append("joy " + str(button)); tx_joy(button); joy(button)
			else:
				trace.append("disconnect")
				if model.controller == 0: model_focus(); model.controller = -1
				Input.joy_connection_changed.emit(0, false)
			decline_hearing_offer(true)
			for field in ["state","sector","lens"]: check(host.get(field) == model[field], "transaction model " + field)
			check(paused == model.paused and host._focus_pause_active == model.focus, "transaction pause/focus matches model")
			check(host._pending_sector == model.pending and host._pending_retry == model.retry, "transaction queue matches model")
			var expected: Array = [] if model.choice.is_empty() else [model.choice]
			check(host.upgrades == expected and host.metrics.size() == model.metrics and host.level_receipts.size() == model.receipts, "transaction upgrade receipt metric matches independent model")
			var saved: Dictionary = host._decode_campaign_checkpoint()
			check(saved.get("ok",false), "transaction retains valid checkpoint")
			if saved.get("ok",false):
				var saved_upgrades: Array = [] if model.saved.choice.is_empty() else [model.saved.choice]
				check(saved.sector == model.saved.sector and saved.campaign.upgrades == saved_upgrades and saved.metrics.size() == model.saved.metrics and saved.campaign.level_receipts.size() == model.saved.receipts, "committed checkpoint matches independent transaction model")
			command_hash.update((case_name + ":" + trace[-1] + ":" + str(host.state) + ":" + str(paused) + "\n").to_utf8_buffer())
			event_count += 1
			if not failures.is_empty(): return

func run() -> void:
	var root_path := OS.get_environment("XDG_DATA_HOME").simplify_path()
	var actual := OS.get_user_data_dir().simplify_path()
	if OS.get_environment("MOKSHA_QUALITY_ISOLATED") != "1" or root_path.is_empty() or not actual.begins_with(root_path + "/"):
		printerr("REFUSED: isolated XDG save directory required"); quit(2); return
	if mutation.is_empty():
		host = load("res://campaign/campaign.tscn").instantiate()
	else:
		if mutation not in ["rollback", "input"]: quit(3); return
		var mutant: Script = load("res://campaign/quality/nov6_transition_stress/mutations/" + mutation + ".gd")
		if mutant == null: quit(3); return
		# The campaign scene is a script-only Node2D. Instantiate the mutant
		# directly so script replacement cannot orphan its pre-ready menu node.
		host = mutant.new()
		host.name = "MokshaCampaign"
	root.add_child(host)
	host.set_process(false); host.set_physics_process(false)
	if mode in ["all", "basic"]: await fuzz_basic()
	if failures.is_empty() and mode in ["all", "upgrade"]: await upgrade_sequences()
	if failures.is_empty() and mode in ["all", "transaction"]: await upgrade_fuzz()
	if failures.is_empty() and mode in ["all", "held"]: await held_boundaries()
	if failures.is_empty() and mode in ["all", "save"]: await save_lifecycle()
	if failures.is_empty() and mode in ["all", "death"]: await death_lifecycle()
	if failures.is_empty() and mode in ["all", "interrupted"]: await interrupted_actions()
	var result := {"passed": failures.is_empty(), "checks": checks, "failures": failures, "hz": hz, "scenarios": scenario_count, "events": event_count, "seed_base": seed_base, "seed_count": seed_count, "steps": steps, "state_visits": state_visits, "command_digest": command_hash.finish().hex_encode(), "mutation": mutation, "scope": "Seeded bounded native event command-state model plus initialized completed-level exit transaction fixtures. Manual deterministic host ticks use actual shared actor physics. No full traversal, human timing, native device or rendered quality claim."}
	if not output.is_empty():
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(result,"\t")); file.close()
	print("TRANSITION_STRESS_RESULT " + JSON.stringify(result))
	clear_devices(); host.free(); quit(0 if failures.is_empty() else 1)
