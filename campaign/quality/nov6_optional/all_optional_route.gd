extends "res://campaign/route_tests/l23_route.gd"
## Isolated authored district start; every measured action is ordinary input.
## Includes optional branches deliberately omitted by the main-route observer.
var optional_output := "/tmp/moksha-all-optional-route.json"
var optional_lens := "neutral"
var observed_all := false
var rewards_before_exit := {}
var plate_cargo: RigidBody2D
var plate_id := ""
var plate_start := Vector2.ZERO

func _initialize() -> void:
	scene_path = "res://campaign/campaign.tscn"
	max_sector_seconds = 360
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--district="): district_id = arg.trim_prefix("--district=")
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
		if arg.begins_with("--output="): optional_output = arg.trim_prefix("--output=")
		if arg.begins_with("--lens="): optional_lens = arg.trim_prefix("--lens=")
		if arg.begins_with("--seconds="): max_sector_seconds = int(arg.trim_prefix("--seconds="))
		if arg == "--sacrifice": sacrifice = true
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func run() -> void:
	capture_sources("res://")
	input_dispatch = InputDispatch.new()
	input_dispatch.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(input_dispatch)
	host = load(scene_path).instantiate()
	host.save_enabled = false
	root.add_child(host)
	host.lens = optional_lens # Explicit initial build fixture, no accumulated upgrades.
	host.start_new(true)
	for i in host.sectors.size():
		if host.sectors[i].id == district_id: probe_sector = i
	if probe_sector < 0: quit(2); return
	host.load_sector(probe_sector)
	if sacrifice:
		host.state = "choice" # Explicit initial sight fixture, before measured motion.
		host.choose_sight(true)
		choice_done = true
	measured_start = host.elapsed
	events.append({"event":"initial_fixture", "district":district_id, "lens":optional_lens, "sight_trade":sacrifice, "spawn":str(host.player.position)})
	var expected := {}
	for goal in host.goals:
		if goal.specification.has("reward"): expected[district_id + "/" + goal.objective_id] = goal.specification.reward
	for tick in hz * max_sector_seconds:
		frame = tick
		if host.sector != probe_sector or host.state == "upgrade" or host.state == "final_choice": break
		if host.state == "dead": failures.append("Ordinary optional route died"); break
		if host.state == "archive": await key(KEY_E)
		elif host.state == "choice": await key(KEY_J if sacrifice else KEY_K); choice_done = true
		elif host.state == "playing":
			if sector_seen != host.sector: begin_sector()
			host.input_override = decide()
			if host.goals.all(func(g): return g.completed):
				observed_all = true
				rewards_before_exit = host.rewards.duplicate(true)
			if frame % hz == 0:
				trace.append(snapshot())
				if trace.size() > 100: trace.pop_front()
			if frame % (hz * 30) == 0: print("OPTIONAL_PROGRESS ", district_id, " ", snapshot(), " goals=", goals_seen.keys())
		await physics_frame
		await process_frame
	var reached: bool = host.sector != probe_sector or host.state in ["upgrade", "final_choice"]
	if not observed_all: failures.append("Not all authored optional/required goals observed completed")
	if not reached: failures.append("No district exit reached")
	if rewards_before_exit != expected: failures.append("Reward receipt does not match authored rewards")
	var drift: Array[String] = []
	for path in checkpoint_hashes:
		if FileAccess.get_sha256(path) != checkpoint_hashes[path]: drift.append(path)
	if not drift.is_empty(): failures.append("Source changed during run")
	var report := {"passed":failures.is_empty(), "district":district_id, "hz":hz, "lens":optional_lens, "sight_trade":sacrifice, "all_goals_observed":observed_all, "district_exit_reached":reached, "expected_rewards":expected, "actual_rewards":rewards_before_exit, "goals_observed":goals_seen, "events":events, "trace":trace, "failures":failures, "source_drift":drift, "source_hashes":checkpoint_hashes, "bot_active_seconds":host.elapsed-measured_start, "human_duration_validated":false, "full_campaign_evidence":false, "method":"Explicit district-start, lens and optional sight fixtures. Thereafter only ordinary production buttons and dispatched proximity E/Q/menu keys. Live actors, damage, cargo and geometry. No measured-phase position, velocity, health, enemy, goal or collision writes. Bot failures are not automatically game defects."}
	FileAccess.open(optional_output, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("OPTIONAL_RESULT ", optional_output, " passed=", report.passed, " seconds=", report.bot_active_seconds, " failures=", failures)
	host.free()
	quit(0 if report.passed else 1)

func decide() -> Dictionary:
	have_goal = false
	for goal in host.goals:
		if goal.completed:
			if not goals_seen.has(goal.objective_id):
				goals_seen[goal.objective_id] = {"frame":frame, "position":str(host.player.position), "optional":goal.optional, "kind":goal.kind, "setting":goal.setting}
			continue
		if not goal.available: continue
		if not have_goal:
			have_goal = true
			goal_target = goal.global_position
			if goal.kind == "plate":
				var plate_raw := guide_plate(goal)
				if plate_raw.has("raw"): return plate_raw.raw
				goal_target = plate_raw.get("target", goal_target)
		if goal.kind == "plate": continue
		if goal.kind == "breaker" and host._near(goal.global_position, 48):
			var facing: float = signf(goal.global_position.x-host.player.position.x)
			if host.player.facing != int(facing) and facing != 0:
				return {"right":1.0} if facing > 0 else {"left":1.0}
			if frame-interaction_tick >= 12:
				interaction_tick = frame
				return {"attack":true}
			return {}
		if host._near(goal.global_position, 48) and frame-interaction_tick >= 12:
			interaction_tick = frame
			queue_key(KEY_E)
			return {}
	return production_decide()

func guide_plate(goal: Node) -> Dictionary:
	if plate_id != goal.objective_id:
		plate_id = goal.objective_id
		plate_cargo = null
		var nearest := INF
		for body in host.room.find_children("*", "RigidBody2D", true, false):
			var distance: float = body.position.distance_to(goal.position-Vector2(0,15))
			if distance < nearest and absf(body.position.y-goal.position.y+15) < 30:
				nearest = distance
				plate_cargo = body
		if is_instance_valid(plate_cargo):
			plate_start = plate_cargo.position
			events.append({"event":"plate_cargo_selected", "goal":plate_id, "position":str(plate_start)})
	if not is_instance_valid(plate_cargo): return {"target":goal.position}
	if plate_cargo.position.distance_to(goal.position-Vector2(0,14)) < 29:
		return {"raw":{}}
	var direction: float = signf(goal.position.x-plate_cargo.position.x)
	var stance := Vector2(plate_cargo.position.x-direction*37, goal.position.y)
	if host.player.position.distance_to(stance) < 28 and host.player.grounded:
		return {"raw":{"right":1.0} if direction > 0 else {"left":1.0}}
	return {"target":stance}

func queue_key(code: int) -> void:
	# A later optional goal may remain even when the campaign exit opens.
	if code == KEY_E and host.goals.any(func(g): return not g.completed):
		var d: Dictionary = host.sectors[host.sector]
		if host._near(Vector2(float(d.width)-45,float(d.get("gate_y",300))),65) and not is_instance_valid(host._nearby_objective()): return
	super.queue_key(code)
