extends SceneTree
## Standalone actual-physics component test. No mission room/core edits required.
const RECEIVER = preload("res://demo/components/freight_receiver.gd")
const CRADLE = preload("res://demo/components/freight_cradle.gd")
const CRATE = preload("res://scenes/props/crate.tscn")
const PLAYER = preload("res://combat_pc/player.tscn")
const GEOMETRY = preload("res://scripts/sensory/sonar_geometry.gd")
const SONAR = preload("res://demo/components/mission_sonar.gd")

class Driver extends Node:
	var player: CharacterBody2D
	var input: Dictionary = {}
	var steps := 0
	func _physics_process(dt: float) -> void:
		if is_instance_valid(player):
			player.physics_tick(dt, input)
			steps += 1

var hz := 60
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var trials: Array[Dictionary] = []
var world: Node2D
var receiver
var cradle
var bus: Node
var events: Array[Dictionary] = []
var latch_count := 0
var preserved: Dictionary = {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	run.call_deferred()
func check(ok: bool, label: String, detail: String = "") -> void:
	checks.append({"passed": ok, "label": label, "detail": detail})
	if not ok: failures.append(label + (": " + detail if detail else ""))
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func until(test: Callable, seconds: float = 6.0) -> bool:
	for i in ceili(seconds * hz):
		await frames(1)
		if test.call(): return true
	return false
func solid(rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)
	return body
func fixture() -> void:
	if is_instance_valid(world):
		world.queue_free()
		await frames(2)
	world = Node2D.new()
	world.name = "FreightComponentFixture"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.add_child(world)
	receiver = RECEIVER.new()
	receiver.position = Vector2(500, 300)
	world.add_child(receiver)
	cradle = CRADLE.new()
	cradle.position = Vector2(254, 270)
	cradle.bind_receiver(receiver)
	world.add_child(cradle)
	receiver.latched.connect(func(_prop): latch_count += 1)
	latch_count = 0
	events.clear()
	await frames(hz / 2)
func noise(origin: Vector2, kind: StringName, loudness: float, source: Node) -> void:
	if is_instance_valid(receiver) and source == receiver:
		events.append({"origin": origin, "kind": str(kind), "loudness": loudness, "source_id": source.get_instance_id(), "latched": receiver.is_latched})
func run() -> void:
	bus = root.get_node("NoiseBus")
	bus.noise_emitted.connect(noise)
	for path in ["res://prop.gd", "res://combat_pc/player.gd", "res://combat_pc/components/contact_adapter.gd", "res://resources/tuning/crate_default.tres", "res://demo/components/mission_prop.gd"]:
		preserved[path] = FileAccess.get_sha256(path)
	await basic_contract()
	await rejection_contract()
	await replacement_contract()
	await pause_contract()
	await charged_and_loss_contract()
	await backstop_pullup_contract()
	for blind in [false, true]: await player_launch(blind)
	await spin_trials()
	await reload_contract()
	for path in preserved: check(FileAccess.get_sha256(path) == preserved[path], "preserved core " + path)
	var report := {"suite": "detachable freight components", "hz": hz, "checks": checks, "failures": failures, "launch_trials": trials, "preserved_hashes": preserved,
		"verified_layout": {"receiver_floor_center": [500,300], "cradle_floor_center": [254,270], "cradle_support_width": 52, "basin_interior_width":160, "floor_gap":140, "receiving_floor_drop":30, "lip_height":8, "backstop_height":68, "backstop_width":40},
		"execution": "Actual Godot rigid-body solver at requested tick rate, original prop launch/tuning, production PC physics_tick and contact adapter; geometry and noise provenance assertions. Fast render pacing changes wall clock only."}
	FileAccess.open("res://demo/evidence/freight_component_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("FREIGHT COMPONENT %d Hz: %d checks, %d failures" % [hz, checks.size(), failures.size()])
	for failure in failures: printerr(failure)
	if is_instance_valid(world): world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func basic_contract() -> void:
	await fixture()
	check(is_instance_valid(cradle.cargo) and cradle.cargo.alive and cradle.cargo.is_in_group("props"), "cradle creates real intact ordinary launchable prop")
	check(receiver.cargo == cradle.cargo and not receiver.is_latched, "one designated bound cargo starts unlatched")
	check(cradle.cargo.get_script() == preload("res://demo/components/mission_prop.gd"), "cargo reuses exact production mission prop")
	var contours := GEOMETRY.collect(world, null, 8, 4000)
	var real_basin := 0
	for record in contours:
		var body = record.body.get_ref()
		if body.get_parent() == receiver: real_basin += 1
	check(real_basin == 3, "all three basin solids produce real sonar contours")
	check(contours.filter(func(record): return record.body.get_ref() == receiver.detector).is_empty(), "Area detector does not masquerade as sonar geometry")
	await frames(hz)
	check(not receiver.is_latched and events.is_empty(), "waiting/E-near cradle cannot deliver cargo remotely")

func rejection_contract() -> void:
	await fixture()
	var player = PLAYER.instantiate()
	player.automatic_physics = false
	player.position = Vector2(500,300)
	world.add_child(player)
	var enemy := CharacterBody2D.new()
	enemy.collision_layer = 8 # Deliberately hits the detector, still not a prop.
	enemy.position = Vector2(500,285)
	var enemy_shape := CollisionShape2D.new()
	var enemy_box := RectangleShape2D.new()
	enemy_box.size = Vector2(20,28)
	enemy_shape.shape = enemy_box
	enemy.add_child(enemy_shape)
	enemy.add_to_group("enemies")
	world.add_child(enemy)
	await frames(hz)
	check(not receiver.is_latched, "player/enemy overlap cannot satisfy receiver")
	player.queue_free()
	enemy.queue_free()
	var ordinary = CRATE.instantiate()
	ordinary.position = Vector2(500,284)
	world.add_child(ordinary)
	await frames(hz)
	check(not receiver.is_latched, "unbound ordinary crate cannot replace designated freight")
	ordinary.queue_free()
	await frames(2)
	cradle.cargo.queue_free()
	await frames(2)
	var freight = CRATE.instantiate()
	freight.position = Vector2(500,277)
	world.add_child(freight)
	freight.gravity_scale = 0
	receiver.bind_cargo(freight)
	await frames(hz)
	check(receiver.detector.overlaps_body(freight) and not receiver.is_latched, "slow airborne overlap without floor support is rejected", str([freight.global_position, receiver.detector.overlaps_body(freight), receiver.is_latched]))
	freight.queue_free()
	await frames(2)
	freight = CRATE.instantiate()
	freight.position = Vector2(500,286)
	freight.freeze = true
	world.add_child(freight)
	receiver.bind_cargo(freight)
	await frames(hz / 2)
	check(not receiver.is_latched, "frozen body posing on basin is rejected")
	freight.queue_free()
	await frames(2)
	freight = CRATE.instantiate()
	freight.position = Vector2(390,265)
	world.add_child(freight)
	freight.gravity_scale = 0
	freight.linear_velocity = Vector2(800,0)
	receiver.bind_cargo(freight)
	await frames(hz / 3)
	check(not receiver.is_latched, "fast airborne fly-through is rejected")
	freight.queue_free()
	await frames(2)
	freight = CRATE.instantiate()
	freight.position = Vector2(500,285)
	world.add_child(freight)
	freight.alive = false
	receiver.bind_cargo(freight)
	await frames(hz)
	check(not receiver.is_latched, "broken prop cannot latch even on floor")

func replacement_contract() -> void:
	await fixture()
	for i in 12:
		var old = cradle.cargo
		var old_id: int = old.get_instance_id()
		old.launch(-1)
		await frames(3)
		cradle.cargo_spawned.connect(func(_new):
			check(not is_instance_valid(old) or (not old.alive and old.collision_layer == 0 and old.collision_mask == 0), "old collision retired before new body announcement")
			check(get_nodes_in_group("freight_cargo").size() == 1, "exactly one live freight at spawn commit")
		, CONNECT_ONE_SHOT)
		check(cradle.replace_cargo(), "replacement accepted " + str(i))
		check(not old.alive and not old.get_meta("freight_valid") and old.is_in_group("sonar_ignore") and receiver.cargo == null, "previous freight invalidated before replacement spawn " + str(i))
		check(not cradle.replace_cargo(), "same-flush replacement coalesced " + str(i))
		var now := GEOMETRY.collect(world, null, 8, 4000)
		check(now.filter(func(record): return record.body_id == old_id).is_empty(), "retired cargo has no collected contour " + str(i))
		await frames(2)
		check(not is_instance_valid(old) and is_instance_valid(cradle.cargo) and receiver.cargo == cradle.cargo and get_nodes_in_group("freight_cargo").size() == 1, "exactly one live freight after commit " + str(i))
	check(not receiver.is_latched, "repeated E replacement never completes delivery")
	cradle.cargo._break_apart()
	await frames(2)
	check(receiver.status == "missing" and not receiver.is_latched, "destroyed cargo reports missing")
	check(cradle.replace_cargo(), "destroyed cargo can be locally replaced")
	await frames(2)
	check(get_nodes_in_group("freight_cargo").size() == 1, "destruction recovery has one freight")

func pause_contract() -> void:
	await fixture()
	seed(205)
	cradle.cargo.launch(1)
	await frames(hz / 6)
	var prop = cradle.cargo
	var at: Vector2 = prop.global_position
	var velocity: Vector2 = prop.linear_velocity
	paused = true
	await frames(hz / 2)
	check(prop.global_position == at and prop.linear_velocity == velocity and not receiver.is_latched, "global pause preserves flight momentum and prevents latch")
	paused = false
	check(await until(func(): return receiver.is_latched), "resumed unmodified flight reaches receiver")
	check(latch_count == 1 and events.size() == 1 and Vector2(events[0].origin) == receiver.global_position and events[0].latched, "one completion noise at actual receiver with committed latch")
	check(not cradle.replacement_enabled and not cradle.replace_cargo(), "replacement disabled after success")
	prop._break_apart()
	await frames(hz / 2)
	receiver.bind_cargo(null)
	check(receiver.is_latched and latch_count == 1, "latch stays permanent after cargo removed/destroyed")

func charged_and_loss_contract() -> void:
	for index in 12:
		await fixture()
		seed(index + 700)
		cradle.cargo.launch(1, 1.25)
		check(await until(func(): return receiver.is_latched), "production charged/finisher-strength launch captured seed=" + str(index+700))
	await fixture()
	var lost = cradle.cargo
	lost.launch(-1)
	await frames(hz * 2)
	check(lost.global_position.x < 0 and not receiver.is_latched, "wrong-way cargo is genuinely lost without false completion")
	check(cradle.replace_cargo(), "lost cargo replaced without full room reset")
	await frames(hz / 2)
	cradle.cargo.launch(1)
	check(await until(func(): return receiver.is_latched), "replacement after wrong-way loss remains deliverable")

func backstop_pullup_contract() -> void:
	await fixture()
	var backstop: StaticBody2D = receiver.get_node("Backstop")
	var shape: CollisionShape2D = backstop.get_child(0)
	check(shape.shape.size == Vector2(40,80) and backstop.position == Vector2(100,-28), "backstop widens only rightward, retaining capture face/top")
	var player = PLAYER.instantiate()
	player.automatic_physics = false
	world.add_child(player)
	player.reset_actor(Vector2(530,300),1)
	var driver := Driver.new()
	driver.player = player
	world.add_child(driver)
	await frames(3)
	driver.input = {"right":1.0,"jump":true}
	var caught := await until(func(): return player.main_action == &"ledge", 1.0)
	check(caught and player._ledge_body == backstop, "actual PC running jump catches physical receiver backstop")
	driver.input = {}
	await frames(ceili(hz * (player.profile.ledge_catch_seconds + 0.05)))
	driver.input = {"up":1.0}
	var pulled := await until(func(): return player.grounded and absf(player.global_position.y - 232.0) < 0.2, 2.0)
	check(pulled and player._support == backstop, "actual PC completes swept pull-up onto same widened backstop body", str([player.global_position,player.main_action,player.action_phase]))
	driver.input = {}

func player_launch(blind: bool) -> void:
	await fixture()
	seed(210)
	solid(Rect2(120,270,160,20))
	var player = PLAYER.instantiate()
	player.automatic_physics = false
	world.add_child(player)
	player.reset_actor(Vector2(218,270),1)
	var driver := Driver.new()
	driver.player = player
	world.add_child(driver)
	var sonar = SONAR.new()
	world.add_child(sonar)
	sonar.bind_level(world, player)
	sonar.set_blind(blind)
	await frames(hz / 3)
	driver.input = {"attack":true}
	await frames(1)
	driver.input = {}
	var launched := await until(func(): return is_instance_valid(cradle.cargo) and cradle.cargo.hit_count > 0, 1.0)
	check(launched, "ordinary production PC attack launches cargo, blind=" + str(blind))
	var seated := await until(func(): return receiver.is_latched)
	check(seated, "production PC launched cargo physically settles, blind=" + str(blind))
	check(driver.steps > 0 and player.get_node("ContactAdapter").confirmed_contacts > 0, "real strike contact receipt, blind=" + str(blind))
	check(sonar.blind == blind and sonar.geometry.size() > 0, "same physical route has live sonar in sight state=" + str(blind))

func spin_trials() -> void:
	for index in 48:
		await fixture()
		seed(index + 500)
		var prop = cradle.cargo
		prop.launch(1)
		var spin: float = prop.angular_velocity
		var start: Vector2 = prop.global_position
		var seated := await until(func(): return receiver.is_latched)
		var row := {"seed": index + 500, "initial_spin": spin, "start": start, "seated": seated, "end": prop.global_position if is_instance_valid(prop) else Vector2.INF, "hard_impacts": prop.hard_impacts if is_instance_valid(prop) else -1}
		trials.append(row)
		check(seated and is_instance_valid(prop) and prop.alive, "randomized physical launch seed=" + str(index+500), str(row))

func reload_contract() -> void:
	var previous_receiver = receiver
	var previous_cargo = cradle.cargo
	await fixture()
	check(not is_instance_valid(previous_receiver) and not is_instance_valid(previous_cargo), "death/reload room destruction leaves no previous freight nodes")
	check(not receiver.is_latched and cradle.replacement_enabled and get_nodes_in_group("freight_cargo").size() == 1, "fresh room reload resets local objective and exactly one cargo")
