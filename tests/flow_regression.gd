extends SceneTree
## Focused integration setup teleports to interaction points. This is not a full
## combat/platforming playthrough. E/Q/Escape/R/N are real parsed input events.

var checks: Array[Dictionary] = []
var observations: Dictionary = {}
var game: Node
var bus: Node
var tap_records: Array[Dictionary] = []
var step_records: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String, detail: String = "") -> void:
	checks.append({"pass": ok, "check": label, "detail": detail})
	print("PASS " if ok else "FAIL ", label, " ", detail)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func press(code: int) -> void:
	key(code, true)
	await frames(2)
	key(code, false)
	await frames(2)

func place_player(at: Vector2) -> void:
	game.player.global_position = at
	game.player.velocity = Vector2.ZERO
	game.player.invuln = 10.0
	game.player.air_lock = 0.0
	game.player.hitpause = 0.0

func wait_interact() -> void:
	while game.interaction_cooldown > 0.0:
		await frames(2)
	await frames(2)

func actor_positions() -> Dictionary:
	var result := {}
	for actor in get_nodes_in_group("actors"):
		if game.current_level.is_ancestor_of(actor):
			result[actor.get_instance_id()] = actor.global_position
	return result

func _on_noise(origin: Vector2, kind: StringName, _loudness: float, source: Node) -> void:
	if not is_instance_valid(source): return
	if kind == &"weapon_tap":
		tap_records.append({"origin": origin, "contact": source.tap_contact, "tip": source.graphics.weapon_tip(), "source_id": source.get_instance_id(), "frame": Engine.get_physics_frames()})
	elif kind == &"enemy_step":
		step_records.append({"origin": origin, "feet": source.global_position + Vector2(source.facing * 3, 0), "source_id": source.get_instance_id()})

func barrier_hit() -> Dictionary:
	var barrier: Node2D = game.current_level.get_node("GateBarrier")
	var at := barrier.global_position + Vector2(0, -30)
	var query := PhysicsRayQueryParameters2D.create(at + Vector2(-25, 0), at + Vector2(25, 0), 1)
	return game.player.get_world_2d().direct_space_state.intersect_ray(query)

func run() -> void:
	var scene: PackedScene = load("res://main.tscn")
	check(scene != null, "main PackedScene loads")
	if scene == null:
		finish()
		return
	game = scene.instantiate()
	root.add_child(game)
	bus = root.get_node("NoiseBus")
	bus.noise_emitted.connect(_on_noise)
	await frames(25)
	check(game.state == "playing" and game.current_level != null, "main starts a playing level")
	check(game.current_scene.resource_path == "res://scenes/levels/city_prologue.tscn", "new run starts city prologue")
	check(not game.current_level.sensory_required and not game.sight_sacrificed and not game.sonar.blind, "city begins in normal vision")
	check(not game.sonar.preview_when_sighted, "normal vision has no sonar preview")
	check(is_equal_approx(game.player.speed_multiplier, 1.0), "city uses unmodified speed")
	check(not game.sacrifice_sight(), "city cannot trade sight")
	var baseline_speed: float = game.player.tuning.move_speed
	var baseline_dash: float = game.player.tuning.dash_speed
	var baseline_resource: Resource = game.player.tuning
	key(KEY_D, true)
	await frames(8)
	check(is_equal_approx(game.player.velocity.x, baseline_speed), "D produces baseline movement speed")
	key(KEY_D, false)
	await frames(2)
	var city_id: int = game.current_level.get_instance_id()
	var city_bounds: Rect2 = game.current_level.camera_bounds
	await press(KEY_E)
	check(game.current_level.get_instance_id() == city_id, "E away from city exit does not transition")
	place_player(game.current_level.get_node("GateAnchor").global_position)
	await wait_interact()
	check(game.current_level.get_instance_id() == city_id, "standing at city exit alone does not transition")
	await press(KEY_E)
	check(game.current_scene.resource_path == "res://scenes/levels/arcology_one.tscn", "E near city exit loads arcology")
	check(not is_instance_id_valid(city_id), "transition frees the old level instance")
	check(game.level_number == 2 and game.current_level.sensory_required, "second level requires sensory trade")
	check(game.current_level.camera_bounds != city_bounds and game.current_level.camera_bounds.size.y >= 1000, "arcology has distinct vertical bounds")
	check(not game.has_next_level(), "arcology is the terminal second level")
	check(not game.sight_sacrificed and not game.sonar.blind, "arcology enters sighted")
	await wait_interact()
	var arcology_id: int = game.current_level.get_instance_id()
	await press(KEY_E)
	check(not game.sight_sacrificed, "E at arcology spawn does not trade sight")
	place_player(game.current_level.get_node("GateAnchor").global_position)
	await wait_interact()
	await press(KEY_E)
	check(game.state == "playing" and not game.sight_sacrificed, "terminal exit rejects completion before trade")
	var station: Node2D = game.current_level.get_node("SacrificeAnchor")
	place_player(station.global_position + Vector2(-90, 0))
	await wait_interact()
	await press(KEY_E)
	check(not game.sight_sacrificed, "station rejects E outside interaction radius")
	check(not game.sacrifice_sight(), "station API also enforces proximity")
	place_player(station.global_position + Vector2(0, 19))
	await wait_interact()
	check(not game.sight_sacrificed, "station requires E even at contact")
	var hit_before := barrier_hit()
	check(not hit_before.is_empty() and hit_before.collider == game.current_level.get_node("GateBarrier"), "closed ascent barrier blocks a real physics ray")
	await press(KEY_E)
	check(game.sight_sacrificed and game.sonar.blind, "E at station trades sight and enables blind renderer")
	check(is_equal_approx(game.player.speed_multiplier, 1.25), "sight trade applies exactly 1.25 speed multiplier")
	check(is_equal_approx(game.player.tuning.move_speed, baseline_speed) and is_equal_approx(game.player.tuning.dash_speed, baseline_dash), "sight trade leaves baseline movement and dash tuning unchanged")
	check(game.player.tuning == baseline_resource, "baseline shared tuning resource identity is retained")
	check(game.current_level.get_node("SacrificeVisual").spent, "station visibly marks trade spent")
	check(game.current_level.get_node("GateBarrier").open and barrier_hit().is_empty(), "trade opens physical barrier")
	var sacrifice_events: Array = bus.event_history.filter(func(record): return record.kind == &"sacrifice")
	check(sacrifice_events.size() == 1, "trade emits one initial station pulse")
	if sacrifice_events.size() == 1:
		check(sacrifice_events[0].origin.is_equal_approx(station.global_position) and sacrifice_events[0].source_id == station.get_instance_id(), "initial pulse has station world position and source")
	check(game.sonar.pulses.any(func(pulse): return pulse.kind == &"sacrifice"), "initial station noise reaches bound sonar")
	await wait_interact()
	await press(KEY_E)
	check(is_equal_approx(game.player.speed_multiplier, 1.25), "repeated E at spent station does not compound speed")
	check(not game.sacrifice_sight(), "repeat trade API safely rejects")
	check(bus.event_history.filter(func(record): return record.kind == &"sacrifice").size() == 1, "repeat trade produces no extra sacrifice event")
	key(KEY_A, true)
	await frames(8)
	check(is_equal_approx(absf(game.player.velocity.x), baseline_speed * 1.25), "post-trade movement actually runs 25 percent faster")
	key(KEY_A, false)
	await frames(2)

	# Continuous Q input exercises the actor's cooldown rather than calling tap.
	tap_records.clear()
	key(KEY_Q, true)
	await frames(ceili(game.player.tuning.tap_cooldown * 3.4 * Engine.physics_ticks_per_second))
	key(KEY_Q, false)
	await frames(2)
	check(tap_records.size() >= 3, "holding Q repeats real weapon taps", "%d taps" % tap_records.size())
	var taps_at_contact := true
	var taps_near_weapon := true
	var tap_gap_ok := true
	var max_tip_distance := 0.0
	for i in range(tap_records.size()):
		var record: Dictionary = tap_records[i]
		taps_at_contact = taps_at_contact and record.origin.is_equal_approx(record.contact) and record.source_id == game.player.get_instance_id()
		max_tip_distance = maxf(max_tip_distance, record.origin.distance_to(record.tip))
		taps_near_weapon = taps_near_weapon and record.origin.distance_to(record.tip) < 6.0
		if i > 0: tap_gap_ok = tap_gap_ok and record.frame - tap_records[i - 1].frame >= floori(game.player.tuning.tap_cooldown * Engine.physics_ticks_per_second) - 1
	check(taps_at_contact, "Q noise originates at measured weapon contact with player provenance")
	check(taps_near_weapon, "Q contact stays at the visible weapon tip", "largest distance %.3f px" % max_tip_distance)
	check(tap_gap_ok, "held Q obeys cooldown")
	check(game.sonar.event_history.any(func(record): return record.kind == &"weapon_tap"), "held Q noise reaches sonar")
	var held_tap_count := tap_records.size()
	await frames(80)
	check(step_records.size() > 0, "live level enemies emit footsteps", "%d steps" % step_records.size())
	check(step_records.all(func(record): return record.origin.is_equal_approx(record.feet)), "enemy step origins match emitting enemies' feet")
	check(step_records.any(func(record): return record.origin.distance_to(game.player.global_position) > 150), "enemy step origin is independent of player position")

	key(KEY_Q, true)
	await frames(3)
	await press(KEY_ESCAPE)
	check(game.state == "paused", "Escape pauses the run")
	var frozen_positions := actor_positions()
	var paused_elapsed: float = game.sonar.elapsed
	var paused_room_time: float = game.room_time
	var paused_events: int = bus.event_count
	var paused_pulses: Array = game.sonar.debug_snapshot().pulses
	key(KEY_D, true)
	await frames(35)
	check(actor_positions() == frozen_positions, "pause freezes players, enemies and rigid props")
	check(is_equal_approx(game.sonar.elapsed, paused_elapsed) and game.sonar.debug_snapshot().pulses == paused_pulses, "pause freezes sonar propagation and decay")
	check(bus.event_count == paused_events and is_equal_approx(game.room_time, paused_room_time), "pause suppresses actor noise and run timer")
	key(KEY_D, false)
	key(KEY_Q, false)
	await press(KEY_ESCAPE)
	await frames(5)
	check(game.state == "playing" and game.player.simulation_enabled and game.sonar.simulation_enabled, "Escape resumes actors and sonar")
	check(game.sonar.elapsed > paused_elapsed and game.room_time > paused_room_time, "resume advances sonar and run timer")

	# Isolate camera follow from combat/falling while observing real camera frames.
	var lower_camera: Vector2 = game.camera.position
	game.player.simulation_enabled = false
	game.player.global_position = game.current_level.get_node("GateAnchor").global_position
	await frames(60)
	var upper_camera: Vector2 = game.camera.position
	var bounds: Rect2 = game.current_level.camera_bounds
	check(upper_camera.y < lower_camera.y - 500.0, "camera follows vertical ascent", "lower %s upper %s" % [lower_camera, upper_camera])
	check(upper_camera.x >= bounds.position.x + 320 and upper_camera.x <= bounds.end.x - 320 and upper_camera.y >= bounds.position.y + 180 and upper_camera.y <= bounds.end.y - 180, "camera stays within viewport-adjusted level bounds")
	check(game._clamped_camera(Vector2(-9999, -9999)) == bounds.position + Vector2(320, 180) and game._clamped_camera(Vector2(9999, 9999)) == bounds.end - Vector2(320, 180), "camera clamps all four edges")
	game.player.simulation_enabled = true

	# A real death signal is induced with lethal damage; R remains parsed input.
	game.player.invuln = 0
	game.player.take_damage(game.player.max_hp + 1, 0)
	await frames(3)
	check(game.state == "dead" and game.player.dead, "lethal actor damage enters dead state")
	check(not game.player.simulation_enabled and not game.sonar.simulation_enabled, "death stops actor and sonar simulation")
	await press(KEY_R)
	check(game.state == "playing" and game.current_scene.resource_path == "res://scenes/levels/arcology_one.tscn", "R retries the current arcology room")
	check(not is_instance_id_valid(arcology_id), "retry frees the previous arcology")
	check(not game.player.dead and game.player.hp == game.player.max_hp, "retry restores living full-health player")
	check(not game.sight_sacrificed and not game.sonar.blind and is_equal_approx(game.player.speed_multiplier, 1.0), "retry resets normal vision and speed")
	check(not game.current_level.get_node("SacrificeVisual").spent and not game.current_level.get_node("GateBarrier").open, "retry resets station and physical barrier")
	check(game.sonar.event_history.all(func(record): return record.source_id != arcology_id), "retry contains no old level event provenance")
	var old_source_ids: Array = []
	for actor in get_nodes_in_group("actors"):
		if game.current_level.is_ancestor_of(actor): old_source_ids.append(actor.get_instance_id())
	key(KEY_Q, true)
	await frames(4)
	key(KEY_Q, false)
	check(not game.sonar.pulses.is_empty(), "reload setup creates a live pulse")
	key(KEY_R, true)
	check(game.sonar.pulses.is_empty() and game.sonar.event_history.is_empty() and bus.event_history.is_empty(), "R synchronously clears pulses and both event histories")
	key(KEY_R, false)
	await frames(3)
	check(game.sonar.event_history.all(func(record): return not old_source_ids.has(record.source_id)), "reloaded room does not retain old actor sources")
	check(game.sonar.geometry.all(func(record): return is_instance_valid(record.anchor.get_ref()) and game.current_level.is_ancestor_of(record.anchor.get_ref())), "reloaded sonar geometry belongs only to current room")

	# Complete the terminal room with focused setup and real E events.
	place_player(game.current_level.get_node("SacrificeAnchor").global_position + Vector2(0, 19))
	await wait_interact()
	await press(KEY_E)
	place_player(game.current_level.get_node("GateAnchor").global_position)
	await wait_interact()
	await press(KEY_E)
	check(game.state == "won", "traded sight plus E at terminal exit completes ascent")
	var won_id: int = game.current_level.get_instance_id()
	await press(KEY_E)
	check(game.state == "won" and game.current_level.get_instance_id() == won_id, "repeated terminal interaction is safe")
	check(not game.player.simulation_enabled and not game.sonar.simulation_enabled, "terminal completion freezes simulation")
	await press(KEY_N)
	check(game.state == "playing" and game.current_scene.resource_path == "res://scenes/levels/city_prologue.tscn", "N starts a fresh city run from terminal state")
	check(not game.sight_sacrificed and not game.sonar.blind and is_equal_approx(game.player.speed_multiplier, 1.0), "new run resets sight and speed")
	check(game.kills == 0 and game.prop_hits == 0 and game.prop_kills == 0 and game.run_time < 0.2, "new run resets progression counters and timer")
	observations = {"baseline_move_speed": baseline_speed, "baseline_dash_speed": baseline_dash, "q_taps_during_hold": held_tap_count, "enemy_steps": step_records.size(), "max_tap_tip_distance": max_tip_distance}
	game.free()
	await frames(2)
	var direct_scene: PackedScene = load("res://arcology_run.tscn")
	check(direct_scene != null, "direct arcology editor-run scene loads")
	if direct_scene != null:
		game = direct_scene.instantiate()
		root.add_child(game)
		await frames(3)
		check(game.current_scene.resource_path == "res://scenes/levels/arcology_one.tscn", "direct arcology editor-run scene starts indoors")
		await press(KEY_N)
		check(game.current_scene.resource_path == "res://scenes/levels/city_prologue.tscn" and game.state == "playing", "N from direct arcology editor-run returns to city")
		game.free()
		await frames(2)
	finish()

func finish() -> void:
	var failures := checks.filter(func(record): return not record.pass)
	var report := {"engine": Engine.get_version_info().string, "suite": "flow_regression", "scope": "Focused real-input integration; interaction/camera teleports and lethal-damage setup; not a full native playthrough", "checks": checks, "observations": observations, "passed": checks.size() - failures.size(), "failed": failures.size()}
	var file := FileAccess.open("res://tests/flow_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("FLOW RESULT ", checks.size() - failures.size(), "/", checks.size(), " passed")
	quit(1 if not failures.is_empty() else 0)
