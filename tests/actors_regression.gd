extends SceneTree
## Real body/scene regressions; run with --headless --fixed-fps 120 --script.

const PLAYER = preload("res://scenes/actors/player.tscn")
const ENEMY = preload("res://scenes/actors/enemy.tscn")
const CRATE = preload("res://scenes/props/crate.tscn")
var failures: Array[String] = []
var checks := 0
var room: Node2D
var bus: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("FAIL: " + label)
	else: print("PASS: ", label)

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func fresh_room() -> void:
	for action in [&"left", &"right", &"jump", &"dash", &"attack", &"tap"]: Input.action_release(action)
	if is_instance_valid(room):
		room.queue_free()
		await frames()
	room = Node2D.new()
	root.add_child(room)
	bus.clear_history()

func body(scene: PackedScene, at: Vector2, manual: bool = true) -> Node2D:
	var actor = scene.instantiate()
	actor.position = at
	room.add_child(actor)
	actor.set_physics_process(not manual)
	return actor

func terrain(at: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.position = at
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	wall.add_child(collision)
	room.add_child(wall)
	return wall

func events(kind: StringName, source_id: int = 0) -> Array:
	return bus.event_history.filter(func(event): return event.kind == kind and (source_id == 0 or event.source_id == source_id))

func run() -> void:
	seed(20261002)
	bus = root.get_node("NoiseBus")
	await test_input_buffers()
	await test_attack_cancellation()
	await test_melee_contacts()
	await test_motion_and_taps()
	await test_prop_contacts()
	await test_enemy_motion()
	await fresh_room()
	print("ACTOR REGRESSION: ", checks - failures.size(), "/", checks, " passed")
	quit(0 if failures.is_empty() else 1)

func test_input_buffers() -> void:
	for action in [&"jump", &"dash", &"attack"]:
		await fresh_room()
		var p = body(PLAYER, Vector2(200, 100))
		await frames()
		p.apply_hitpause(0.2)
		Input.action_press(action)
		p._physics_process(0.01)
		check(p.jump_buffer > 0 if action == &"jump" else p.dash_buffer > 0 if action == &"dash" else p.attack_buffer > 0, "%s intent captured inside hitpause" % action)
		Input.action_release(action)
		await frames()
		p._physics_process(0.21)
		p._physics_process(1.0 / 120.0)
		check(p.velocity.y < 0 if action == &"jump" else p.dash_time > 0 if action == &"dash" else p.attack_phase == p.AttackPhase.STARTUP, "%s buffered tap executes after hitpause longer than buffer" % action)
	await fresh_room()
	var p = body(PLAYER, Vector2(200, 100))
	p.jump_buffer = 0.1
	p.dash_buffer = 0.1
	p.attack_buffer = 0.1
	p.simulation_enabled = false
	check(p.jump_buffer == 0 and p.dash_buffer == 0 and p.attack_buffer == 0, "real pause clears stale input immediately")
	p.apply_hitpause(0.1)
	p.simulation_enabled = true
	Input.action_press(&"left")
	p._physics_process(0.01)
	check(p.facing == -1, "facing responds during local hitpause")
	Input.action_release(&"left")

func test_attack_cancellation() -> void:
	for reason in ["dash", "damage", "death"]:
		await fresh_room()
		var p = body(PLAYER, Vector2(200, 100))
		var strikes: Array[int] = []
		p.attack_requested.connect(func(_actor, combo): strikes.append(combo))
		p.attack_buffer = 0.14
		p._physics_process(0.008)
		check(p.attack_phase == p.AttackPhase.STARTUP, "%s case starts in explicit startup" % reason)
		if reason == "dash":
			p.dash_buffer = 0.12
			p._physics_process(0.008)
		else: p.take_damage(1 if reason == "damage" else 99, 1)
		for i in range(40): p._physics_process(0.008)
		check(strikes.is_empty() and p.attack_phase == p.AttackPhase.IDLE, "%s cancels pending strike without late hit" % reason)
	await fresh_room()
	var p = body(PLAYER, Vector2(200, 100))
	p._start_attack()
	p._advance_attack(0.045)
	check(p.attack_phase == p.AttackPhase.ACTIVE, "light attack has explicit active phase after 40ms startup")
	p._advance_attack(0.07)
	check(p.attack_phase == p.AttackPhase.RECOVERY, "light attack enters explicit recovery")
	p._advance_attack(0.1)
	check(p.attack_phase == p.AttackPhase.IDLE, "attack recovers to idle")

func test_melee_contacts() -> void:
	await fresh_room()
	var p = body(PLAYER, Vector2(200, 150))
	var front = body(ENEMY, Vector2(245, 150))
	var behind = body(ENEMY, Vector2(190, 150))
	var high = body(ENEMY, Vector2(238, 80))
	await frames()
	p.get_node("StrikeComponent").resolve_attack(p, 1)
	check(front.hp == front.max_hp - 1, "forward melee contacts actual 40px torso collider")
	check(behind.hp == behind.max_hp, "melee never hits behind facing")
	check(high.hp == high.max_hp, "melee does not reach vertically distant body")
	await fresh_room()
	p = body(PLAYER, Vector2(200, 150))
	front = body(ENEMY, Vector2(245, 150))
	terrain(Vector2(222, 125), Vector2(2, 70))
	await frames()
	p.get_node("StrikeComponent").resolve_attack(p, 3)
	check(front.hp == front.max_hp, "thin terrain blocks finisher melee")
	await fresh_room()
	p = body(PLAYER, Vector2(200, 150))
	front = body(ENEMY, Vector2(235, 150))
	terrain(Vector2(208, 125), Vector2(2, 70))
	await frames()
	p.get_node("StrikeComponent").resolve_attack(p, 1)
	check(front.hp == front.max_hp, "wall immediately against player body still blocks melee")
	front.target = p
	front.facing = -1
	front.windup = 0.145
	front._physics_process(0.01)
	check(p.hp == p.max_hp, "enemy attack also respects thin terrain obstruction")
	await fresh_room()
	p = body(PLAYER, Vector2(200, 150))
	front = body(ENEMY, Vector2(245, 150))
	var prop = body(CRATE, Vector2(228, 135))
	prop.freeze = true
	await frames()
	p.get_node("StrikeComponent").resolve_attack(p, 3)
	check(front.hp == front.max_hp - 2, "finisher preserves increased damage")
	check(prop.charge > 0 and prop.hit_count == 1, "forward contact launches hittable props")

	await fresh_room()
	p = body(PLAYER, Vector2(200, 150))
	front = body(ENEMY, Vector2(245, 150))
	await frames()
	p._start_attack()
	p._advance_attack(0.045)
	p.hitpause = 0
	var strike = p.get_node("StrikeComponent")
	for i in range(5): strike._physics_process(0.008)
	check(front.hp == front.max_hp - 1, "active melee window damages each body only once")
	var late = body(ENEMY, Vector2(250, 150))
	await frames()
	strike._physics_process(0.008)
	check(late.hp == late.max_hp - 1, "active melee window catches a body entering after startup")
	p.cancel_attack()
	var cancelled = body(ENEMY, Vector2(250, 150))
	await frames()
	p.hitpause = 0
	strike._physics_process(0.008)
	check(cancelled.hp == cancelled.max_hp, "cancel closes an already-active contact window")

func test_motion_and_taps() -> void:
	await fresh_room()
	terrain(Vector2(400, 210), Vector2(800, 20))
	var p = body(PLAYER, Vector2(100, 200))
	await frames()
	p._physics_process(0.01)
	var shared_speed: float = p.tuning.move_speed
	var p2 = body(PLAYER, Vector2(500, 200))
	p.speed_multiplier = 1.25
	Input.action_press(&"right")
	p._physics_process(0.05)
	check(is_equal_approx(p.velocity.x, shared_speed * 1.25), "sight sacrifice scales movement by 1.25")
	check(p2.tuning == p.tuning and p2.tuning.move_speed == shared_speed, "speed modifier does not mutate shared tuning")
	Input.action_release(&"right")
	p.jump_buffer = 0.12
	p._physics_process(0.008)
	check(p.velocity.y < -300 and p.jumps == 1, "ground jump produces upward motion")
	p.jump_buffer = 0.12
	p._physics_process(0.008)
	check(p.jumps == 2 and p.velocity.y < -280, "double jump remains available")
	await fresh_room()
	terrain(Vector2(400, 210), Vector2(800, 20))
	terrain(Vector2(150, 120), Vector2(2, 160))
	p = body(PLAYER, Vector2(100, 200))
	p.tuning = p.tuning.duplicate()
	p.tuning.dash_speed = 10000
	p.speed_multiplier = 1.25
	await frames()
	p.dash_buffer = 0.12
	p._physics_process(1.0 / 120.0)
	check(p.global_position.x < 143 and p.global_position.x > 100, "extreme-speed dash sweeps into a 2px wall without tunneling")
	check(p.dash_time > 0 and p.invuln > 0, "dash preserves roll duration and invulnerability")
	await fresh_room()
	terrain(Vector2(400, 210), Vector2(800, 20))
	terrain(Vector2(172, 158), Vector2(44, 6))
	p = body(PLAYER, Vector2(100, 200))
	p.tuning = p.tuning.duplicate()
	p.tuning.dash_speed = 10000
	await frames()
	p.dash_buffer = 0.12
	p._physics_process(1.0 / 120.0)
	check(p.global_position.x < 150 and p.global_position.y > 195, "high-speed dash cannot climb through an overhead ledge corner")
	await fresh_room()
	terrain(Vector2(400, 210), Vector2(800, 20))
	p = body(PLAYER, Vector2(250, 200))
	await frames()
	Input.action_press(&"tap")
	for i in range(65): p._physics_process(1.0 / 120.0)
	Input.action_release(&"tap")
	var taps := events(&"weapon_tap", p.get_instance_id())
	check(taps.size() == 2, "held Q/C action repeats at the tap cooldown")
	check(not taps.is_empty() and absf(taps[0].origin.y - 200) < 1.0 and taps[0].origin.x > p.global_position.x + 15, "weapon tap noise begins at actual ground contact")

func test_prop_contacts() -> void:
	await fresh_room()
	terrain(Vector2(750, 350), Vector2(500, 20))
	var crate = body(CRATE, Vector2(700, 180), false)
	crate.rotation = 0.25
	crate.tuning = crate.tuning.duplicate()
	crate.tuning.hard_impacts_to_break = 99
	var crate_id: int = crate.get_instance_id()
	await frames(85)
	var impacts := events(&"prop_impact", crate_id)
	check(not impacts.is_empty(), "falling physical prop emits impact noise")
	if not impacts.is_empty():
		check(impacts[0].origin.x > 670 and impacts[0].origin.x < 740 and absf(impacts[0].origin.y - 340) < 7, "translated rotated prop impact retains true world contact provenance")
	await fresh_room()
	terrain(Vector2(750, 350), Vector2(500, 20))
	crate = body(CRATE, Vector2(700, 180), false)
	crate.tuning = crate.tuning.duplicate()
	crate.tuning.hard_impacts_to_break = 1
	crate_id = crate.get_instance_id()
	await frames(85)
	var breaks := events(&"prop_break", crate_id)
	check(not is_instance_valid(crate) and breaks.size() == 1, "hard physical collision breaks prop and emits one break")
	check(not breaks.is_empty() and breaks[0].origin.distance_to(Vector2(700, 326)) < 35, "break provenance is the physical prop location")
	await fresh_room()
	terrain(Vector2(700, 350), Vector2(700, 20))
	var enemy = body(ENEMY, Vector2(710, 340))
	enemy.hp = 9
	crate = body(CRATE, Vector2(610, 312), false)
	crate.tuning = crate.tuning.duplicate()
	crate.tuning.launch_lift = 0
	crate.tuning.hard_impacts_to_break = 99
	var damage_log: Array[bool] = []
	enemy.damaged.connect(func(_actor, _damage, _direction, prop_hit): damage_log.append(prop_hit))
	await frames()
	crate.launch(1)
	await frames(55)
	check(enemy.hp == 6 and damage_log == [true], "real launched rigid-body contact deals prop damage exactly once")
	check(not is_instance_valid(crate), "enemy contact consumes launched prop")
	await fresh_room()
	terrain(Vector2(750, 350), Vector2(800, 20))
	var first = body(CRATE, Vector2(600, 325), false)
	var second = body(CRATE, Vector2(650, 325), false)
	first.tuning = first.tuning.duplicate()
	first.tuning.launch_lift = 0
	first.tuning.hard_impacts_to_break = 99
	second.tuning = second.tuning.duplicate()
	second.tuning.hard_impacts_to_break = 99
	await frames(10)
	first.launch(1)
	await frames(28)
	check(second.charge > 0 and second.global_position.x > 660, "real prop chain transfers charge and physical momentum")

	await fresh_room()
	terrain(Vector2(750, 350), Vector2(800, 20))
	first = body(CRATE, Vector2(600, 325), false)
	second = body(CRATE, Vector2(650, 325), false)
	enemy = body(ENEMY, Vector2(695, 340))
	enemy.hp = 20
	for box in [first, second]:
		box.tuning = box.tuning.duplicate()
		box.tuning.launch_lift = 0
		box.tuning.launch_spin_range = Vector2(12, 12)
		box.tuning.hard_impacts_to_break = 99
	var chain_hits: Array[int] = []
	var second_id: int = second.get_instance_id()
	second.impacted.connect(func(prop, _target, _damage, _direction): chain_hits.append(prop.get_instance_id()))
	await frames(10)
	first.launch(1)
	await frames(100)
	check(chain_hits == [second_id] and enemy.hp <= 17, "chain-launched second prop reaches and damages a real enemy")
	check(events(&"prop_break", second_id).size() == 1, "chain kill prop emits its own single break source")

func test_enemy_motion() -> void:
	await fresh_room()
	terrain(Vector2(170, 210), Vector2(140, 20))
	var enemy = body(ENEMY, Vector2(220, 200), false)
	enemy.phase = 2.0
	await frames(180)
	check(enemy.global_position.x < 237 and enemy.global_position.y < 201, "patrolling guard stays on a platform ledge")
	await fresh_room()
	terrain(Vector2(350, 210), Vector2(600, 20))
	terrain(Vector2(257, 160), Vector2(2, 80))
	enemy = body(ENEMY, Vector2(248, 200), false)
	enemy.phase = 2.0
	await frames(100)
	check(events(&"enemy_step", enemy.get_instance_id()).is_empty(), "blocked enemy emits no footsteps without real movement")
