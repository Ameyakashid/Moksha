extends SceneTree
## Authored-layout regression fixtures. No controller or enemy-policy overrides.
## Every movement phase uses ordinary production input_override buttons only.
## District/spawn and initial objective interactions are explicitly labeled fixtures,
## not evidence of reaching these pockets through a complete campaign.
const DATA = preload("res://campaign/logic/campaign_data.gd")
const DOOR = preload("res://campaign/logic/objective_door.gd")
const HAZARD = preload("res://campaign/logic/hazard.gd")
var failures: Array[String] = []
var receipts: Array[Dictionary] = []
var hz := 60
var host: Node
var output := "/tmp/moksha-nov6-layout-regression.json"
var negative_control := ""
var source_hashes := {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--negative-control="): negative_control = arg.trim_prefix("--negative-control=")
	Engine.physics_ticks_per_second = hz
	run.call_deferred()

func require(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func supported(d: Dictionary, p: Vector2) -> bool:
	if is_equal_approx(p.y, 300):
		return not d.get("gaps", []).any(func(gap): return p.x > gap.x and p.x < gap.y)
	return d.platforms.any(func(rect): return is_equal_approx(rect.position.y, p.y) and p.x >= rect.position.x and p.x <= rect.end.x)

func apply_negative_control(d: Dictionary) -> void:
	# Test-only in-memory mutations reproduce the defects without touching source.
	if negative_control == "preloaded_plate" and d.id == "l2_stamping_galleries":
		for objective in d.objectives:
			if objective.id == "counterweight": objective.at = Vector2(3900, 300)
	elif negative_control == "unsafe_gate_staging" and d.id == "l3_inundated_market":
		d.objective_doors[0].at = Vector2(3030, 150)
	elif negative_control == "blocked_underpass" and d.id == "city_evac_spine":
		d.platforms.append(Rect2(3980, 240, 200, 60))

func capture_sources(directory: String, result: Dictionary) -> void:
	for name in DirAccess.get_files_at(directory):
		if name.get_extension() in ["gd", "tscn", "tres", "gdshader", "godot"]:
			var path := directory.path_join(name)
			result[path] = FileAccess.get_sha256(path)
	for child in DirAccess.get_directories_at(directory):
		if child.begins_with(".") or "test" in child or child in ["quality", "qa_audit", "evidence", "docs"]: continue
		capture_sources(directory.path_join(child), result)

func static_contracts() -> void:
	var levels := {}
	var ids := {}
	var plate_count := 0
	for d in DATA.sectors():
		apply_negative_control(d)
		levels[d.level] = levels.get(d.level, 0) + 1
		require(not ids.has(d.id), "Duplicate district: " + d.id)
		ids[d.id] = true
		var goals := {}
		for o in d.get("objectives", []):
			require(not goals.has(o.id), d.id + " duplicate objective: " + o.id)
			goals[o.id] = o
			require(supported(d, o.at), d.id + " unsupported objective: " + o.id)
			var body := Rect2(o.at - Vector2(14, 36), Vector2(28, 35))
			for rect in d.platforms:
				require(rect.size.y <= 18 or not rect.intersects(body), d.id + " embedded standing objective: " + o.id)
			if o.kind == "plate":
				plate_count += 1
				require(o.get("optional", false), d.id + " mandatory destructible-cargo plate")
				var accessible_cargo := false
				for prop in d.props:
					if not prop is Array: continue
					var p := Vector2(prop[0], prop[1])
					require((p - Vector2(0, 15)).distance_to(o.at - Vector2(0, 14)) >= 48, d.id + " plate starts loaded: " + o.id)
					if is_equal_approx(p.y, o.at.y) and absf(p.x - o.at.x) <= 160:
						var lane := Rect2(Vector2(minf(p.x, o.at.x) - 16, p.y - 30), Vector2(absf(p.x - o.at.x) + 32, 29))
						accessible_cargo = accessible_cargo or not d.platforms.any(func(rect): return rect.size.y > 18 and rect.intersects(lane))
				require(accessible_cargo, d.id + " no nearby flat cargo approach: " + o.id)
		for o in d.get("objectives", []):
			for dependency in o.get("requires", []):
				require(goals.has(dependency), d.id + " missing dependency: " + str(dependency))
				if goals.has(dependency) and not o.get("optional", false):
					require(not goals[dependency].get("optional", false), d.id + " required objective depends on optional: " + o.id)
		for hazard in d.get("hazards", []):
			# Match the production damage envelope, including its 10 px expansion.
			var hot := Rect2(hazard.at - hazard.size / 2, hazard.size).grow(10)
			for door in d.get("objective_doors", []):
				if door.at.y + door.size.y / 2 < 299 or hot.end.y < 288: continue
				var left: float = door.at.x - door.size.x / 2
				var right: float = door.at.x + door.size.x / 2
				if hazard.at.x < left:
					require(left - hot.end.x >= 80, d.id + " unsafe left gate staging")
				elif hazard.at.x > right:
					require(hot.position.x - right >= 80, d.id + " unsafe right gate staging")
				else: require(false, d.id + " hazard overlaps gate")
		for ladder in d.get("ladders", []):
			require(supported(d, Vector2(ladder[0], ladder[1])), d.id + " unsupported ladder bottom")
			require(supported(d, Vector2(ladder[0], ladder[1] - ladder[2])), d.id + " unsupported ladder top")
		for enemy in d.enemies:
			if enemy.size() > 2: require(supported(d, Vector2(enemy[0], enemy[2])), d.id + " unsupported enemy")
		for prop in d.props:
			if prop is Array: require(supported(d, Vector2(prop[0], prop[1])), d.id + " unsupported cargo")
		require(supported(d, Vector2(d.width - 45, d.get("gate_y", 300))), d.id + " unsupported exit")
	require(ids.size() == 32 and levels.size() == 5, "Campaign must remain five levels / 32 districts")
	require(plate_count == 3, "Expected all three authored plate pockets")
	receipts.append({"test":"static_layout_contracts", "districts":ids.size(), "levels":levels, "plates":plate_count})

func fixture(id: String, spawn = null, pulse_fixture := false) -> void:
	if is_instance_valid(host):
		host.queue_free()
		await process_frame
		host = null
	paused = false
	host = load("res://campaign/campaign.tscn").instantiate()
	root.add_child(host)
	host.save_enabled = false
	host.start_new(true)
	for i in host.sectors.size():
		if host.sectors[i].id == id:
			apply_negative_control(host.sectors[i])
			if spawn is Vector2: host.sectors[i]["spawn"] = spawn
			if pulse_fixture:
				for hazard in host.sectors[i].get("hazards", []): hazard.phase = 0.0
			host.load_sector(i)
			return
	failures.append("Unknown fixture district: " + id)

func ticks(count: int, raw: Dictionary = {}) -> void:
	for tick in count:
		host.input_override = raw
		await physics_frame
		await process_frame

func goal(id: String) -> Node:
	for item in host.goals:
		if item.objective_id == id: return item
	return null

func plate_case(district: String, id: String, crate_x: float) -> void:
	await fixture(district)
	await ticks(hz * 2)
	require(not goal(id).completed, district + " idle start granted plate reward")
	require(host.rewards.is_empty(), district + " idle start granted an augment")
	receipts.append({"test":"plate_idle", "district":district, "seconds":2, "completed":goal(id).completed})
	await fixture(district, Vector2(crate_x - 75, 300))
	await ticks(hz / 2)
	var plate := goal(id)
	var cargo: RigidBody2D
	for body in host.room.find_children("*", "RigidBody2D", true, false):
		if absf(body.position.x - crate_x) < 8 and absf(body.position.y - 285) < 12: cargo = body
	require(is_instance_valid(cargo), district + " authored spare crate missing")
	if not is_instance_valid(cargo): return
	var initial_position: Vector2 = cargo.position
	var movement_frames := 0
	for tick in hz * 10:
		if plate.completed or host.state != "playing": break
		# Walk into the crate until it lies safely inside the physical plate radius.
		# Release pressure so that its real velocity settles, rather than writing it.
		host.input_override = {"right":1.0} if cargo.position.x < plate.position.x - 22 else {}
		if not host.input_override.is_empty(): movement_frames += 1
		await physics_frame
		await process_frame
	require(plate.completed, district + " real cargo push did not load optional plate")
	require(cargo.position.distance_to(initial_position) > 12, district + " reward did not require cargo movement")
	require(host.rewards.has(district + "/" + id), district + " plate did not award its augment")
	receipts.append({"test":"plate_actual_push", "district":district, "fixture_spawn":str(Vector2(crate_x - 75, 300)), "crate_start":str(initial_position), "crate_end":str(cargo.position), "player_end":str(host.player.position), "movement_frames":movement_frames, "completed":plate.completed, "reward":host.rewards.get(district + "/" + id, ""), "state":host.state})

func underpass_case(opened: bool) -> void:
	await fixture("city_evac_spine", Vector2(3850, 300))
	if opened:
		# Explicit initial door-state fixture uses actual objective interactions.
		# This is a collision test, not a claim of a full rescue input route.
		require(goal("keys").interact(), "Underpass fixture key interaction failed")
		require(goal("west").interact(), "Underpass fixture rescue interaction failed")
	await ticks(4)
	var door: Node
	for child in host.room.get_children():
		if child.get_script() == DOOR: door = child
	require(is_instance_valid(door) and door.opened == opened, "Underpass door did not match rescue fixture")
	var start: Vector2 = host.player.position
	await ticks(hz * 2, {"right":1.0})
	var finish: Vector2 = host.player.position
	if opened: require(finish.x > 4200, "Rescued underpass still blocks a ground-level crossing")
	else: require(finish.x < 4000, "Unrescued underpass allows walking through its locked door")
	require(absf(finish.y - 300) < 5, "Underpass walking test left recovery floor")
	receipts.append({"test":"underpass_actual_walk", "rescue_fixture":opened, "start":str(start), "end":str(finish), "door_open":door.opened})

func gate_staging_case(id: String) -> void:
	var data: Dictionary
	for district in DATA.sectors():
		if district.id == id: data = district
	apply_negative_control(data)
	var first: Dictionary = data.objective_doors[0]
	var spawn := Vector2(first.at.x - first.size.x / 2 - 24, 300)
	# Explicit worst-phase fixture: all authored pulses are initially active.
	# Neither their size, damage, period nor the production admission is changed.
	await fixture(id, spawn, true)
	await ticks(3)
	var cooldown := 0.0
	var active_count := 0
	for child in host.room.get_children():
		if child.get_script() == HAZARD:
			cooldown = maxf(cooldown, child.cooldown)
			if child.active: active_count += 1
	require(active_count > 0, id + " staging test failed to exercise an active pulse")
	require(is_zero_approx(cooldown), id + " active hazard hit closed-gate staging")
	receipts.append({"test":"gate_active_pulse_staging", "district":id, "fixture_spawn":str(spawn), "initial_hazard_phase_fixture":0, "active_pulses":active_count, "maximum_damage_cooldown":cooldown})

func run() -> void:
	capture_sources("res://", source_hashes)
	source_hashes[get_script().resource_path] = FileAccess.get_sha256(get_script().resource_path)
	static_contracts()
	await plate_case("city_records", "counterweight", 1400)
	await plate_case("l2_stamping_galleries", "counterweight", 3900)
	await plate_case("l3_water_clinic", "bench", 3510)
	await underpass_case(false)
	await underpass_case(true)
	await gate_staging_case("l2_thermal_foundry")
	await gate_staging_case("l3_inundated_market")
	await gate_staging_case("l3_drainage_commons")
	var end_sources := {}
	capture_sources("res://", end_sources)
	end_sources[get_script().resource_path] = FileAccess.get_sha256(get_script().resource_path)
	var drift: Array[String] = []
	for path in source_hashes:
		if end_sources.get(path, "") != source_hashes[path]: drift.append(path)
	for path in end_sources:
		if not source_hashes.has(path): drift.append(path + " (new)")
	require(drift.is_empty(), "Production source changed during layout regression: " + str(drift))
	var report := {"godot_version":Engine.get_version_info(), "source_hashes":source_hashes, "source_drift":drift, "negative_control":negative_control, "passed":failures.is_empty(), "hz":hz, "failures":failures, "receipts":receipts, "method":"Static 32-district contracts plus explicitly initialized district/spawn/door-state and worst-phase pulse fixtures. Measured motion uses ordinary production movement buttons only, with live enemies and real crate/door physics. No mid-phase position, velocity, health, objective-completion or collision writes.", "full_campaign_evidence":false, "human_duration_validated":false}
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("NOV6_LAYOUT_REGRESSION passed=", report.passed, " hz=", hz, " negative_control=", negative_control, " receipts=", receipts.size(), " failures=", failures)
	quit(0 if failures.is_empty() else 1)
