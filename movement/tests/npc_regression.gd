extends SceneTree
var failures: Array[String] = []
var world: Node2D
var npc: MokshaMovementMotor
var brain: Node
var target: Node2D
func _initialize() -> void:
	_run.call_deferred()
func _fixture(spawn: float, target_x: float = 900.0) -> void:
	if is_instance_valid(world): world.free()
	world = Node2D.new()
	root.add_child(world)
	target = Node2D.new()
	target.position = Vector2(target_x, 100)
	target.add_to_group("movement_players")
	world.add_child(target)
	npc = load("res://movement/actors/npc.tscn").instantiate()
	npc.position = Vector2(spawn, 100)
	world.add_child(npc)
	brain = npc.get_node("Intent")
func _rect(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center
	body.collision_layer = 1
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)
func _ticks(count: int) -> void:
	for i in count: await physics_frame
func _check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
	print("PASS " if ok else "FAIL ", label, " x=", npc.position.x, " y=", npc.position.y, " state=", brain.brain_state, " reason=", brain.reason)
func _run() -> void:
	_fixture(120)
	_rect(Vector2(200, 120), Vector2(400, 40))
	brain.chase_enabled = false
	brain.patrol_left = 80.0
	brain.patrol_right = 220.0
	var minimum := 1000.0
	var maximum := -1000.0
	var turns := 0
	var previous_facing := npc.facing
	for i in 360:
		await physics_frame
		minimum = minf(minimum, npc.position.x)
		maximum = maxf(maximum, npc.position.x)
		if npc.facing != previous_facing: turns += 1
		previous_facing = npc.facing
	_check(minimum >= 74 and maximum <= 226 and turns >= 3, "bounded patrol and facing")
	_fixture(100, 250)
	_rect(Vector2(400, 120), Vector2(800, 40))
	await _ticks(150)
	_check(brain.brain_state == "HOLD" and absf(250 - npc.position.x - 38) < 8, "chase stopping distance")
	var stopped_x := npc.position.x
	target.position.x += 8
	await _ticks(30)
	_check(brain.brain_state == "HOLD" and absf(npc.position.x - stopped_x) < 1, "hold hysteresis")
	target.position.x = 280
	await _ticks(90)
	_check(brain.brain_state == "HOLD" and npc.position.x > stopped_x + 15, "resume chase beyond hysteresis")
	target.position.x = 750
	await _ticks(2)
	_check(brain.brain_state == "PATROL" or brain.brain_state == "TURN", "target loss distance")
	_fixture(100, 270)
	_rect(Vector2(350, 120), Vector2(700, 40))
	_rect(Vector2(210, 40), Vector2(20, 120))
	brain.patrol_left = 60.0
	brain.patrol_right = 600.0
	maximum = -1000.0
	turns = 0
	previous_facing = npc.facing
	for i in 240:
		await physics_frame
		maximum = maxf(maximum, npc.position.x)
		if npc.facing != previous_facing: turns += 1
		previous_facing = npc.facing
	_check(maximum < 191 and turns >= 2 and not brain._tracking, "world LOS and wall turns")
	_fixture(100)
	_rect(Vector2(100, 120), Vector2(200, 40))
	brain.chase_enabled = false
	brain.patrol_left = 40.0
	brain.patrol_right = 500.0
	maximum = -1000.0
	var fell := false
	for i in 360:
		await physics_frame
		maximum = maxf(maximum, npc.position.x)
		fell = fell or npc.position.y > 102
	_check(maximum < 190 and not fell, "patrol edge safety without teleport")
	_fixture(100, 270)
	_rect(Vector2(100, 120), Vector2(200, 40))
	_rect(Vector2(325, 120), Vector2(150, 40))
	maximum = -1000.0
	fell = false
	for i in 240:
		await physics_frame
		maximum = maxf(maximum, npc.position.x)
		fell = fell or npc.position.y > 102
	_check(maximum < 190 and not fell and brain.brain_state == "BLOCKED", "chase waits safely at gap")
	brain.active = false
	await _ticks(3)
	_check(brain.brain_state == "DISABLED" and npc.axis == 0, "AI toggle clears intent")
	brain.reset(-1)
	_check(brain.brain_state == "PATROL" and brain._patrol_direction == -1, "brain reset")
	world.free()
	print("NPC_CHECK_FAILURES=", failures.size())
	quit(0 if failures.is_empty() else 1)
