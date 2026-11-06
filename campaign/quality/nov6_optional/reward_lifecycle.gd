extends "res://campaign/quality/nov6_layout_regression.gd"
## Physical optional rewards through ordinary Retry and title Continue controls.
## The sole location fixture is each district's initial spawn next to its spare.
var bonus_checks := 0
var current_district := ""
var current_goal := ""
var fixture_spawn := Vector2.ZERO

func _initialize() -> void:
	output = "/tmp/moksha-optional-lifecycle.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	Engine.physics_ticks_per_second = hz
	var isolated := OS.get_environment("XDG_DATA_HOME").simplify_path()
	if OS.get_environment("MOKSHA_QUALITY_ISOLATED") != "1" or not isolated.is_absolute_path() or not OS.get_user_data_dir().simplify_path().begins_with(isolated + "/"):
		push_error("Requires an owned isolated XDG_DATA_HOME and MOKSHA_QUALITY_ISOLATED=1"); quit(2); return
	run.call_deferred()

func key(code: int) -> void:
	await process_frame
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	host._unhandled_key_input(event)
	await process_frame

func build_snapshot() -> Dictionary:
	var damage: Array[float] = []
	for step in host.player.melee_chain.steps: damage.append(step.damage)
	return {"rewards":host.rewards.duplicate(true), "capacity":host.health.capacity, "run_speed":host.player.profile.run_speed, "damage":damage}

func push_plate(phase: String, crate_x: float) -> void:
	await ticks(hz / 2)
	var plate := goal(current_goal)
	require(not plate.completed, phase + " must start with incomplete local plate")
	var cargo: RigidBody2D
	for body in host.room.find_children("*", "RigidBody2D", true, false):
		if absf(body.position.x-crate_x) < 8 and absf(body.position.y-285) < 12: cargo = body
	require(is_instance_valid(cargo), phase + " spare crate missing")
	if not is_instance_valid(cargo): return
	var initial: Vector2 = cargo.position
	var health_before: float = host.health.current_health
	var capacity_before: float = host.health.capacity
	var moved_frames := 0
	for tick in hz * 10:
		if plate.completed or host.state != "playing": break
		host.input_override = {"right":1.0} if cargo.position.x < plate.position.x-22 else {}
		if not host.input_override.is_empty(): moved_frames += 1
		await physics_frame
		await process_frame
	host.input_override = {}
	require(plate.completed, phase + " physical push failed")
	require(cargo.position.distance_to(initial) > 12, phase + " reward requires actual displacement")
	require(host.rewards.size() == 1 and host.rewards.has(current_district+"/"+current_goal), phase + " exactly one stable reward ID")
	require(host.health.current_health <= health_before, phase + " live collection cannot heal")
	receipts.append({"test":"physical_reward_collection", "phase":phase, "district":current_district, "goal":current_goal, "spawn_fixture":str(fixture_spawn), "crate_start":str(initial), "crate_end":str(cargo.position), "moved_frames":moved_frames, "completed":plate.completed, "health_before":health_before, "health_after":host.health.current_health, "capacity_before":capacity_before, "capacity_after":host.health.capacity, "build":build_snapshot()})
	bonus_checks += 1

func lifecycle(district: String, id: String, crate_x: float) -> void:
	current_district = district
	current_goal = id
	fixture_spawn = Vector2(crate_x-75,300)
	await fixture(district, fixture_spawn)
	host.save_enabled = true
	var baseline := build_snapshot()
	await push_plate("first collect", crate_x)
	var awarded := build_snapshot()
	require(awarded != baseline, district + " first collection changes the intended build")
	var decoded: Dictionary = host._read_checkpoint()
	require(decoded.get("ok",false) and decoded.get("campaign",{}).get("rewards",{}) == awarded.rewards, district + " reward is committed to checkpoint")
	for iteration in 2:
		host.input_override = {}
		await key(KEY_R)
		await ticks(4)
		require(build_snapshot() == awarded, district + " Retry preserves exactly one bonus")
		await push_plate("Retry " + str(iteration+1), crate_x)
		require(build_snapshot() == awarded, district + " recollect after Retry cannot stack")
	await key(KEY_ESCAPE)
	await key(KEY_N)
	require(host.state == "title", district + " pause N reaches title")
	await key(KEY_C)
	await ticks(4)
	require(build_snapshot() == awarded, district + " title Continue restores exactly one bonus")
	await push_plate("title Continue", crate_x)
	require(build_snapshot() == awarded, district + " recollect after Continue cannot stack")
	# Simulated process restart: fresh host reads the same genuine checkpoint.
	# Reapply only the initial local spawn fixture to avoid claiming full traversal.
	host.free()
	paused = false
	host = load("res://campaign/campaign.tscn").instantiate()
	host.save_enabled = true
	root.add_child(host)
	for district_data in host.sectors:
		if district_data.id == district: district_data["spawn"] = fixture_spawn
	require(host.continue_available, district + " fresh host discovers checkpoint")
	await key(KEY_C)
	await ticks(4)
	require(host.sectors[host.sector].id == district, district + " fresh Continue returns correct district")
	require(build_snapshot() == awarded, district + " fresh Continue restores exactly one bonus")
	await push_plate("fresh-host Continue", crate_x)
	require(build_snapshot() == awarded, district + " fresh-host recollection cannot stack")
	host.save_enabled = false

func run() -> void:
	capture_sources("res://", source_hashes)
	for path in [get_script().resource_path, "res://campaign/quality/nov6_layout_regression.gd"]: source_hashes[path] = FileAccess.get_sha256(path)
	await lifecycle("city_records", "counterweight", 1400)
	await lifecycle("l2_stamping_galleries", "counterweight", 3900)
	await lifecycle("l3_water_clinic", "bench", 3510)
	var drift: Array[String] = []
	for path in source_hashes:
		if FileAccess.get_sha256(path) != source_hashes[path]: drift.append(path)
	require(drift.is_empty(), "Source changed during lifecycle test")
	var report := {"passed":failures.is_empty(), "hz":hz, "collections":bonus_checks, "failures":failures, "receipts":receipts, "source_hashes":source_hashes, "source_drift":drift, "method":"Three authored district/spawn fixtures; actual crate pushing, live enemies, normal R/pause/N/C controls, saved checkpoint and fresh host Continue. No post-fixture position, velocity, health, goals, enemy or collision writes. Fresh starts intentionally refill through production checkpoint behavior; pickups must not heal. Not full-campaign traversal or human pacing evidence."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("OPTIONAL_LIFECYCLE_RESULT passed=", report.passed, " hz=", hz, " collections=", bonus_checks, " failures=", failures)
	host.free()
	quit(0 if report.passed else 1)
