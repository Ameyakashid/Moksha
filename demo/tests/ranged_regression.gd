extends SceneTree
## Real callback/sweep integration; deliberate lifecycle probes are labeled.
const ENEMY = preload("res://demo/components/ranged_enemy.tscn")
const PLAYER = preload("res://combat_pc/player.tscn")
const CRATE = preload("res://scenes/props/crate.tscn")
class Driver extends Node:
	var player: Node
	var frame := {}
	func _physics_process(dt: float) -> void:
		if is_instance_valid(player): player.physics_tick(dt, frame)

var world: Node2D
var enemy: Node2D
var player: Node2D
var driver: Driver
var hz := 120
var checks := 0
var failures: Array[String] = []
var scenarios: Array[String] = []
var receipts: Array[Dictionary] = []
var retirements: Array[StringName] = []
var health_receipts: Array[Dictionary] = []
var shots: Array[WeakRef] = []
var defeats := 0
var sources := ["res://combat_pc/fixtures/guard_projectile.gd", "res://combat_pc/player.gd", "res://combat_pc/components/shield_contact_adapter.gd", "res://combat_pc/components/health_component.gd", "res://combat_pc/components/strike_health.gd", "res://combat_pc/components/strike_knockback.gd", "res://movement/components/movement_motor.gd", "res://prop.gd"]
var hashes := {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()

func _run() -> void:
	for path in sources: hashes[path] = FileAccess.get_sha256(path)
	await _hurt()
	await _guard()
	await _reflection()
	await _wall()
	await _wall_after_launch()
	await _wall_during_windup()
	await _dodge()
	await _melee_interrupt()
	await _reset_inflight()
	await _death_inflight()
	await _death_windup()
	await _source_exit()
	await _scene_exit()
	await _lifetime()
	await _ledge()
	await _prop_hit()
	for path in sources: _check(hashes[path] == FileAccess.get_sha256(path), "preserved source unchanged: " + path)
	var report := {"suite": "demo ranged sentry", "hz": hz, "checks": checks, "failures": failures, "scenarios": scenarios,
		"preserved_hashes": hashes, "execution": "Actual Godot physics callbacks, swept production guard carrier and stock PC/ShieldContactAdapter. Direct lifecycle probes explicitly labeled."}
	FileAccess.open("res://demo/tests/ranged_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("DEMO RANGED %d Hz: %d scenarios, %d checks, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _begin(label: String, px := 100.0, ex := 300.0, floor_width := 800.0) -> void:
	scenarios.append(label)
	receipts = []
	health_receipts = []
	retirements = []
	shots = []
	defeats = 0
	world = Node2D.new()
	root.add_child(world)
	_surface(Vector2(floor_width * 0.5, 220), Vector2(floor_width, 40))
	player = PLAYER.instantiate()
	player.automatic_physics = false
	player.position = Vector2(px, 200)
	world.add_child(player)
	player.damage_resolved.connect(func(receipt: Dictionary): receipts.append(receipt.duplicate(true)))
	driver = Driver.new()
	driver.player = player
	world.add_child(driver)
	enemy = ENEMY.instantiate()
	enemy.position = Vector2(ex, 200)
	enemy.ai_enabled = false
	world.add_child(enemy)
	enemy.configure(player, root.get_node("NoiseBus"))
	enemy.defeated.connect(func(_who): defeats += 1)
	enemy.get_node("StrikeHealth/Health").damage_processed.connect(func(r): health_receipts.append(r.duplicate(true)))
	enemy.projectile_launched.connect(func(_who, shot):
		shots.append(weakref(shot))
		shot.retired.connect(func(_carrier, reason): retirements.append(reason)))
	await _frames(6)

func _surface(at: Vector2, size: Vector2) -> Node2D:
	var body := StaticBody2D.new()
	body.position = at
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	world.add_child(body)
	return body

func _finish() -> void:
	world.queue_free()
	await process_frame
	await physics_frame
	_check(get_nodes_in_group("demo_projectiles").is_empty(), "scene disposal leaves no projectile")

func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func _seconds(seconds: float) -> void:
	await _frames(ceili(seconds * hz))

func _until(predicate: Callable, seconds := 2.0) -> bool:
	for _i in ceili(seconds * hz):
		await _frames(1)
		if predicate.call(): return true
	return false

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(scenarios.back() + ": " + label)

func _attack() -> void:
	enemy.ai_enabled = true
	enemy._cooldown = 0.0

func _first_shot() -> Node2D:
	return shots[0].get_ref() as Node2D if not shots.is_empty() else null

func _launch() -> bool:
	_attack()
	var launched := await _until(func(): return not shots.is_empty())
	_check(launched, "windup releases a real carrier")
	return launched

func _hurt() -> void:
	await _begin("physical swept hit and once-only contact")
	await _launch()
	_check(await _until(func(): return not receipts.is_empty()), "travel reaches actual player body")
	if not receipts.is_empty(): _check(receipts[0].outcome == &"hurt" and receipts[0].amount == 1.0, "bolt deals one damage")
	enemy.ai_enabled = false
	await _seconds(0.5)
	_check(receipts.size() == 1 and retirements.size() == 1, "one carrier cannot double-hit")
	var events: Array = root.get_node("NoiseBus").event_history
	_check(events.any(func(e): return e.source_id == enemy.get_instance_id() and e.kind == &"enemy_windup"), "windup noise has shooter provenance")
	_check(events.any(func(e): return e.source_id == enemy.get_instance_id() and e.kind == &"enemy_attack" and e.origin.distance_to(enemy.global_position + Vector2(-15, -22)) < 1.0), "shot noise originates at real muzzle")
	await _finish()

func _guard() -> void:
	await _begin("preserved held guard absorbs projectile")
	driver.frame = {"shield": true}
	await _seconds(0.25)
	await _launch()
	_check(await _until(func(): return not receipts.is_empty()), "projectile reaches front shield")
	if not receipts.is_empty(): _check(receipts[0].outcome == &"guarded" and is_equal_approx(receipts[0].amount, 0.25), "stock guard absorbs 75 percent")
	await _finish()

func _reflection() -> void:
	await _begin("timed real reflection kills original shooter")
	await _launch()
	_check(await _until(func(): return is_instance_valid(_first_shot()) and _first_shot().global_position.x - player.global_position.x < 36.0), "physical projectile enters parry approach")
	driver.frame = {"shield": true}
	_check(await _until(func(): return not receipts.is_empty()), "actual shield resolves incoming shot")
	if not receipts.is_empty(): _check(receipts[0].outcome == &"parried" and receipts[0].amount == 0.0, "timed parry negates incoming damage")
	_check(player.get_node("ShieldContactAdapter").confirmed_reflections == 1, "stock adapter physically redirects exactly once")
	_check(await _until(func(): return enemy.dead), "returned swept carrier reaches original shooter")
	_check(enemy.health == 0.0 and defeats == 1, "returned bolt defeats fresh two-health sentry once")
	_check(health_receipts.size() == 1 and health_receipts[0].applied == 2.0, "same scalar health consumes one two-damage receipt")
	await _seconds(0.4)
	_check(receipts.size() == 1 and get_nodes_in_group("demo_projectiles").is_empty(), "lethal callback leaves no ghost or second hit")
	var events: Array = root.get_node("NoiseBus").event_history
	_check(events.any(func(e): return e.source_id == enemy.get_instance_id() and e.kind == &"enemy_damage"), "reflection publishes canonical damage noise")
	_check(events.any(func(e): return e.source_id == enemy.get_instance_id() and e.kind == &"enemy_death"), "reflection publishes canonical death noise")
	await _finish()

func _wall() -> void:
	await _begin("solid wall prevents target acquisition")
	_surface(Vector2(190, 160), Vector2(4, 100))
	await _frames(3)
	_attack()
	await _seconds(1.5)
	_check(shots.is_empty() and enemy.attack_serial == 0 and receipts.is_empty(), "no wall-penetrating fire or damage")
	await _finish()

func _wall_after_launch() -> void:
	await _begin("swept projectile hits thin terrain")
	await _launch()
	enemy.ai_enabled = false
	_surface(Vector2(200, 160), Vector2(1, 100))
	await _seconds(0.9)
	_check(receipts.is_empty() and retirements.has(&"terrain_contact"), "one-pixel wall intercepts real moving carrier")
	await _finish()

func _wall_during_windup() -> void:
	await _begin("door closes during committed telegraph")
	_attack()
	await _until(func(): return enemy.ai_state == &"windup")
	_surface(Vector2(200, 160), Vector2(4, 100))
	await _seconds(1.1)
	_check(shots.is_empty() and receipts.is_empty(), "release rechecks newly blocking terrain")
	await _finish()

func _dodge() -> void:
	await _begin("late physical jump evades committed horizontal shot")
	await _launch()
	enemy.ai_enabled = false
	_check(await _until(func(): return is_instance_valid(_first_shot()) and _first_shot().global_position.x - player.global_position.x < 90.0), "shot closes before late dodge")
	driver.frame = {"jump": true}
	_check(await _until(func(): return is_instance_valid(_first_shot()) and _first_shot().global_position.x < player.global_position.x - 40.0), "locked shot passes below jumping player")
	_check(receipts.is_empty(), "real vertical escape avoids contact")
	await _until(func(): return not is_instance_valid(_first_shot()), 3.0)
	_check(receipts.is_empty(), "missed shot stays harmless through expiry")
	await _finish()

func _melee_interrupt() -> void:
	await _begin("production sword interrupts ranged windup", 100, 136)
	_attack()
	await _until(func(): return enemy.ai_state == &"windup")
	driver.frame = {"attack": true}
	_check(await _until(func(): return enemy.health < 2.0, 0.5), "stock PC melee reaches preserved Hurtbox4")
	_check(enemy.health == 1.0 and enemy.stun_left > 0.0, "sword applies one damage and stagger")
	await _seconds(0.6)
	_check(shots.is_empty() and receipts.is_empty(), "stagger cancels telegraph without firing")
	await _finish()

func _reset_inflight() -> void:
	await _begin("explicit reset boundary retires in-flight shot")
	await _launch()
	var old_serial: int = enemy.attack_serial
	enemy.reset()
	enemy.ai_enabled = false
	await _seconds(1.0)
	_check(receipts.is_empty() and get_nodes_in_group("demo_projectiles").is_empty(), "reset prevents stale shot contact")
	_check(enemy.health == 2.0 and enemy.attack_serial >= old_serial, "reset restores life without reusing identity")
	_check(enemy.collision_layer == 32 and enemy.get_node("Hurtbox").collision_layer == 4, "reset retains enemy collision contract")
	await _finish()

func _death_inflight() -> void:
	await _begin("explicit death boundary retires in-flight shot")
	await _launch()
	enemy.take_hit(99.0, 1.0, true)
	await _seconds(1.0)
	_check(enemy.dead and defeats == 1 and receipts.is_empty(), "death cancels flying hazard and emits once")
	_check(get_nodes_in_group("demo_projectiles").is_empty(), "death leaves no carrier")
	await _finish()

func _death_windup() -> void:
	await _begin("explicit death during telegraph prevents release")
	_attack()
	await _until(func(): return enemy.ai_state == &"windup")
	enemy.take_hit(99.0, 1.0, true)
	await _seconds(1.1)
	_check(shots.is_empty() and enemy.dead, "dead enemy never fires")
	await _finish()

func _source_exit() -> void:
	await _begin("source removal retires sibling carrier")
	await _launch()
	enemy.queue_free()
	await _seconds(1.0)
	_check(receipts.is_empty() and get_nodes_in_group("demo_projectiles").is_empty(), "freed shooter leaves no orphan hazard")
	await _finish()

func _scene_exit() -> void:
	await _begin("scene removal clears carrier ownership")
	await _launch()
	var retained: WeakRef = shots[0]
	await _finish()
	_check(not is_instance_valid(retained.get_ref()), "encounter root owns projectile lifetime")

func _lifetime() -> void:
	await _begin("missed projectile expires within bounded lifetime")
	enemy.projectile_lifetime = 0.18
	await _launch()
	enemy.ai_enabled = false
	await _seconds(0.4)
	_check(receipts.is_empty() and retirements.has(&"expired"), "unresolved carrier expires before distant target")
	await _finish()

func _ledge() -> void:
	await _begin("retreat brakes before actual platform lip", 80, 155, 180)
	enemy.ai_enabled = true
	enemy._cooldown = 4.0
	await _seconds(1.5)
	_check(enemy.position.x < 170.0 and enemy.position.y < 201.0, "sentry retreats without leaving platform")
	_check(enemy.position.x > 155.0, "sentry tries to keep distance")
	await _finish()

func _prop_hit() -> void:
	await _begin("real rigid-body crate defeats ranged body32", 30, 170)
	var crate = CRATE.instantiate()
	crate.position = Vector2(95, 183)
	crate.collision_mask = 33
	world.add_child(crate)
	await _frames(3)
	crate.launch(1)
	_check(await _until(func(): return enemy.dead), "actual crate collision depletes sentry")
	_check(defeats == 1, "crate emits one defeat")
	await _finish()
