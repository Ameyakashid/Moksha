extends SceneTree
## A continuous arcology route using real parsed keyboard input from spawn to exit.
## Guards and props remain active, and player/actor state is never teleported,
## healed, made invulnerable, or disabled by this test. The route deliberately
## bypasses guards using the near ledge edges, which is a supported choice.
## Scripted coordinates and jump timing prove connected traversal, not whether
## an unfamiliar human can read the black view or discover the route unaided.

var game: Node
var failures: Array[String] = []
var checks := 0
var route_jumps := 0
var tap_count := 0
var enemy_step_count := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS: ", label)
	else:
		failures.append(label)
		push_error("FAIL: " + label)

func frames(count: int) -> void:
	for _i in range(count):
		await physics_frame
		await process_frame

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func release_controls() -> void:
	for code in [KEY_A, KEY_D, KEY_SPACE, KEY_Q, KEY_E, KEY_R]: key(code, false)

func walk_to(x: float, max_frames := 240) -> bool:
	var code := KEY_D if x > game.player.global_position.x else KEY_A
	key(code, true)
	var arrived := false
	for _frame in range(max_frames):
		await frames(1)
		if game.state != "playing": break
		if absf(x - game.player.global_position.x) < 3.0:
			arrived = true
			break
	key(code, false)
	await frames(4)
	return arrived

func on_noise(_origin: Vector2, kind: StringName, _loudness: float, _source: Node) -> void:
	if kind == &"weapon_tap": tap_count += 1
	elif kind == &"enemy_step": enemy_step_count += 1

func run() -> void:
	seed(20261003)
	release_controls()
	game = load("res://arcology_run.tscn").instantiate()
	root.add_child(game)
	root.get_node("NoiseBus").noise_emitted.connect(on_noise)
	await frames(60)
	check(game.state == "playing" and game.current_level.sensory_required, "route starts naturally at arcology spawn")
	check(not game.sight_sacrificed and is_equal_approx(game.player.speed_multiplier, 1.0), "arrival begins sighted at base movement speed")
	check(not game.first_ascent_landed and game.navigation_hint().is_empty(), "first-landing tutorial begins uncompleted and hidden while sighted")
	check(game.current_level.get_node("Actors/Enemies").get_child_count() == 4, "all four placed guards are present")
	var actors_active := true
	for actor in get_nodes_in_group("actors"):
		if game.current_level.is_ancestor_of(actor): actors_active = actors_active and actor.simulation_enabled
	check(actors_active, "all placed actors are simulated during the route")
	check(await walk_to(253.0), "natural movement reaches sensory station")
	key(KEY_E, true)
	await frames(2)
	key(KEY_E, false)
	await frames(2)
	check(game.sight_sacrificed and game.sonar.blind, "actual E input trades sight before climbing")
	check(game.current_level.get_node("GateBarrier/CollisionShape2D").disabled, "trade opens physical ascent barrier")
	if not game.sight_sacrificed:
		finish()
		return
	var first_landing_hint: String = game.navigation_hint()
	check(not game.first_ascent_landed and first_landing_hint.contains("HOLD SPACE") and first_landing_hint.contains("PRESS AGAIN"), "sight trade presents the hold-and-repeat jump instruction")
	key(KEY_Q, true)
	check(await walk_to(350.0), "blind player walks through opened barrier toward first ledge")
	check(not game.first_ascent_landed and game.navigation_hint() == first_landing_hint, "walking toward first ledge preserves jump instruction")
	var airborne_above_first := false
	var tutorial_waited_for_landing := true
	for number in range(1, 10):
		var takeoff_x := 350.0 if number == 1 else (740.0 if number % 2 == 0 else 830.0)
		var landing_x := 443.0 if number == 1 else (834.0 if number % 2 == 0 else 736.0)
		var source_y := 1000.0 - (number - 1) * 96.0
		var target_y := source_y - 96.0
		var reached := await walk_to(takeoff_x)
		check(reached and game.player.is_on_floor() and absf(game.player.global_position.y - source_y) < 2.0, "jump %d reaches takeoff from previous landing without repositioning" % number)
		if not reached or game.state != "playing": break
		var code := KEY_D if landing_x > takeoff_x else KEY_A
		key(code, true)
		key(KEY_SPACE, true)
		var landed := false
		for frame in range(160):
			await frames(1)
			if game.state != "playing": break
			if number == 1 and not game.player.is_on_floor() and game.player.global_position.y <= target_y + 2.0:
				airborne_above_first = true
				tutorial_waited_for_landing = tutorial_waited_for_landing and not game.first_ascent_landed and game.navigation_hint() == first_landing_hint
			if (code == KEY_D and game.player.global_position.x >= landing_x) or (code == KEY_A and game.player.global_position.x <= landing_x):
				key(code, false)
			if frame == 35: key(KEY_SPACE, false)
			if frame == 36: key(KEY_SPACE, true)
			if frame > 40 and game.player.is_on_floor() and absf(game.player.global_position.y - target_y) < 2.0:
				landed = true
				break
		key(KEY_SPACE, false)
		key(code, false)
		await frames(8)
		check(landed and game.player.is_on_floor() and absf(game.player.global_position.y - target_y) < 2.0, "continuous jump %d settles on its intended ledge" % number)
		if number == 1:
			check(airborne_above_first and tutorial_waited_for_landing, "crossing first-ledge height in the air does not prematurely complete tutorial")
			check(game.first_ascent_landed and game.navigation_hint() != first_landing_hint and game.navigation_hint().contains("DRAW"), "actual first landing replaces jump instruction with threat-reading hint")
		print("ROUTE LANDING ", number, " ", game.player.global_position, " health=", game.player.hp)
		if not landed or game.state != "playing": break
		route_jumps += 1
	check(route_jumps == 9, "all nine ascent landings connect in one live run")
	if route_jumps == 9:
		check(await walk_to(550.0), "last landing connects to exit interaction range")
		key(KEY_E, true)
		await frames(2)
		key(KEY_E, false)
		await frames(2)
		check(game.state == "won", "actual E input completes the first ascent")
	check(game.player.hp == game.player.max_hp, "supported near-edge bypass route finishes with full health")
	check(game.kills == 0, "completion does not require defeating guards")
	check(tap_count > 10, "held Q generates repeated real navigation noises during the route")
	check(enemy_step_count > 0, "live guards emit their own movement noises during the route")
	check(game.first_ascent_landed, "tutorial completion stays remembered throughout ascent")
	key(KEY_Q, false)
	var completed_level_id: int = game.current_level.get_instance_id()
	key(KEY_R, true)
	await frames(2)
	key(KEY_R, false)
	await frames(6)
	check(game.state == "playing" and game.current_level.get_instance_id() != completed_level_id, "actual R input starts a fresh version of the same room")
	check(not game.sight_sacrificed and not game.first_ascent_landed and game.navigation_hint().is_empty(), "room retry clears sensory tutorial completion")
	check(game.player.global_position.distance_to(Vector2(112, 1000)) < 2.0, "room retry restores natural spawn")
	check(await walk_to(253.0), "retried player can naturally reach station again")
	key(KEY_E, true)
	await frames(2)
	key(KEY_E, false)
	await frames(2)
	check(game.sight_sacrificed and not game.first_ascent_landed and game.navigation_hint() == first_landing_hint, "trading after retry restores hold-and-repeat instruction")
	finish()

func finish() -> void:
	release_controls()
	print("POLISH ROUTE: ", checks - failures.size(), "/", checks, " checks; ", route_jumps, "/9 continuous jumps; ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
