extends "res://campaign/quality/nov6_optional/reward_lifecycle.gd"
## Initial upper-pocket fixture; genuine walk and E recovery for agility.
func fixture(id: String, _spawn = null, pulse_fixture := false) -> void:
	fixture_spawn = Vector2(3145,-90)
	await super.fixture(id, fixture_spawn, pulse_fixture)

func push_plate(phase: String, _crate_x: float) -> void:
	await ticks(4)
	var pickup := goal(current_goal)
	require(not pickup.completed, phase + " local recover objective resets")
	var health_before: float = host.health.current_health
	var start: Vector2 = host.player.position
	for tick in hz * 3:
		if pickup.completed or host.state != "playing": break
		if host._near(pickup.position, 45):
			host.input_override = {}
			await key(KEY_E)
		else:
			host.input_override = {"right":1.0}
			await physics_frame
			await process_frame
	host.input_override = {}
	require(pickup.completed, phase + " real E recovery failed")
	require(host.player.position.distance_to(start)>15, phase + " real approach walk required")
	require(host.rewards.size()==1 and host.rewards.has(current_district+"/"+current_goal), phase + " exactly one stable agility receipt")
	require(host.health.current_health<=health_before, phase + " recovery cannot heal")
	receipts.append({"test":"agility_recovery", "phase":phase, "district":current_district, "goal":current_goal, "spawn_fixture":str(fixture_spawn), "approach_start":str(start), "approach_end":str(host.player.position), "health_before":health_before, "health_after":host.health.current_health, "completed":pickup.completed, "build":build_snapshot()})
	bonus_checks += 1

func run() -> void:
	capture_sources("res://",source_hashes)
	for path in [get_script().resource_path,"res://campaign/quality/nov6_optional/reward_lifecycle.gd","res://campaign/quality/nov6_layout_regression.gd"]: source_hashes[path]=FileAccess.get_sha256(path)
	await lifecycle("l2_thermal_foundry","service",3220)
	var drift:Array[String]=[]
	for path in source_hashes:
		if FileAccess.get_sha256(path)!=source_hashes[path]: drift.append(path)
	require(drift.is_empty(),"Source changed during agility lifecycle test")
	var report:={"passed":failures.is_empty(),"hz":hz,"collections":bonus_checks,"failures":failures,"receipts":receipts,"source_hashes":source_hashes,"source_drift":drift,"method":"Explicit authored upper-pocket spawn fixture; actual approach walking and E pickup, two R retries, pause/N/C and fresh-host Continue using a real checkpoint. No measured position, velocity, health, enemy, goal or collision writes. This is focused reward-lifecycle coverage, not a whole-district route."}
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("OPTIONAL_AGILITY_RESULT passed=",report.passed," hz=",hz," collections=",bonus_checks," failures=",failures)
	host.free()
	quit(0 if report.passed else 1)
