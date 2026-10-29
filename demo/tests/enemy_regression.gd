extends SceneTree
## Isolated actual-physics integration suite. Explicit boundary probes are named.
const ENEMY = preload("res://demo/components/enemy.tscn")
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
var checks := 0
var failures: Array[String] = []
var receipts: Array[Dictionary] = []
var defeats := 0
var scenarios: Array[String] = []
var hz := 120
var sources := ["res://combat_pc/player.gd", "res://combat_pc/components/contact_adapter.gd", "res://combat_pc/components/health_component.gd", "res://combat_pc/components/strike_health.gd", "res://combat_pc/components/strike_knockback.gd", "res://movement/components/movement_motor.gd", "res://prop.gd"]
var hashes := {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()

func _run() -> void:
	for path in sources: hashes[path] = FileAccess.get_sha256(path)
	await _physical_hurt()
	await _guard()
	await _parry()
	await _lethal_parry()
	await _out_of_range()
	await _occluded()
	await _melee_health()
	await _stagger_and_reset()
	await _dead_attack()
	await _edge_and_hearing()
	await _prop_hit()
	for path in sources: _check(hashes[path] == FileAccess.get_sha256(path), "preserved source unchanged: " + path)
	var report := {"suite": "demo enemy", "hz": hz, "checks": checks, "failures": failures, "scenarios": scenarios, "preserved_hashes": hashes, "execution": "Actual Godot physics callbacks and production PC, contact adapter, motor, strike health and rigid-body prop. Explicit lifecycle probes labeled."}
	FileAccess.open("res://demo/tests/enemy_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("DEMO ENEMY %d Hz: %d scenarios, %d checks, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _begin(label: String, kind_value := "sentinel", px := 100.0, ex := 136.0, floor_width := 800.0) -> void:
	scenarios.append(label)
	receipts = []
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
	enemy.kind = kind_value
	enemy.position = Vector2(ex, 200)
	enemy.ai_enabled = false
	world.add_child(enemy)
	enemy.configure(player, root.get_node("NoiseBus"))
	enemy.defeated.connect(func(_who): defeats += 1)
	await _frames(6)

func _surface(at: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = at
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	world.add_child(body)

func _finish() -> void:
	world.queue_free()
	await process_frame
	await physics_frame

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

func _physical_hurt() -> void:
	await _begin("physical melee hit and once-per-swing")
	_attack()
	_check(await _until(func(): return not receipts.is_empty()), "real overlap resolves incoming damage")
	if not receipts.is_empty(): _check(receipts[0].outcome == &"hurt" and receipts[0].amount == 1.0, "sentinel damage is one")
	var serial: int = enemy.attack_serial
	await _seconds(0.19)
	_check(receipts.size() == 1 and enemy.attack_serial == serial, "active frames cannot repeat a hit")
	_check(root.get_node("NoiseBus").event_history.any(func(e): return e.source_id == enemy.get_instance_id() and e.kind == &"enemy_windup"), "warning has actual enemy provenance")
	await _finish()

func _guard() -> void:
	await _begin("front guard from physical melee")
	driver.frame = {"shield": true}
	await _seconds(0.23)
	_check(player.shield_phase == &"hold", "player enters preserved hold")
	_attack()
	_check(await _until(func(): return not receipts.is_empty()), "physical hit reaches guard")
	if not receipts.is_empty(): _check(receipts[0].outcome == &"guarded" and is_equal_approx(receipts[0].amount, 0.25), "guard uses preserved 75 percent absorption")
	await _finish()

func _parry() -> void:
	await _begin("timed parry physical counter", "warden")
	_attack()
	await _until(func(): return enemy.ai_state == &"windup" and enemy._phase_elapsed >= enemy._windup - 0.10)
	driver.frame = {"shield": true}
	_check(await _until(func(): return not receipts.is_empty()), "incoming physical swing resolves")
	if not receipts.is_empty(): _check(receipts[0].outcome == &"parried" and receipts[0].amount == 0, "timed shield negates incoming hit")
	_check(enemy.health == 5.0 and enemy.stun_left > 0.0, "stock physical counter deals three and staggers warden")
	_check(player.get_node("ShieldContactAdapter").confirmed_counters == 1, "stock shield adapter confirms counter")
	await _finish()

func _lethal_parry() -> void:
	await _begin("physical parry lethal defeat lifecycle")
	_attack()
	await _until(func(): return enemy.ai_state == &"windup" and enemy._phase_elapsed >= enemy._windup - 0.10)
	driver.frame = {"shield": true}
	_check(await _until(func(): return enemy.dead), "real shield counter depletes sentinel")
	_check(enemy.health == 0.0 and defeats == 1, "real damage triggers one defeat")
	_check(not receipts.is_empty() and receipts[0].outcome == &"parried", "lethal synchronous counter preserves defender receipt")
	await _frames(2)
	_check(enemy.get_node("BodyShape").disabled and enemy.get_node("Hurtbox/Shape").disabled, "dead collider and sonar anchors are disabled")
	await _seconds(0.7)
	_check(receipts.size() == 1, "no post-death strike")
	await _finish()

func _out_of_range() -> void:
	await _begin("swing misses escaped player")
	_attack()
	await _until(func(): return enemy.ai_state == &"windup")
	player.reset_actor(Vector2(10, 200), 1)
	await _seconds(0.85)
	_check(receipts.is_empty(), "committed windup cannot hit absent body")
	await _finish()

func _occluded() -> void:
	await _begin("solid wall blocks enemy contact")
	_surface(Vector2(118, 165), Vector2(8, 70))
	await _frames(3)
	_attack()
	await _seconds(1.0)
	_check(receipts.is_empty() and enemy.attack_serial == 0, "terrain blocks sight and melee")
	await _finish()

func _melee_health() -> void:
	await _begin("real PC ContactAdapter health and knockback")
	driver.frame = {"attack": true}
	_check(await _until(func(): return enemy.health < 3.0, 1.0), "real PC swing debits StrikeHealth")
	_check(enemy.health == 2.0, "one PC strike debits exactly one, no body duplicate")
	_check(enemy.get_node("Knockback").applied_count == 1, "preserved strike knockback accepted")
	_check(enemy.get_node("StrikeHealth").resolved_count == 1, "preserved health accepted once")
	await _finish()

func _stagger_and_reset() -> void:
	await _begin("windup interrupted by physical player attack")
	_attack()
	await _until(func(): return enemy.ai_state == &"windup")
	driver.frame = {"attack": true}
	_check(await _until(func(): return enemy.health < 3.0, 0.5), "player interrupts charging enemy")
	_check(enemy.ai_state == &"stagger" and enemy.stun_left > 0.0, "real impulse cancels windup immediately")
	await _seconds(0.5)
	_check(receipts.is_empty(), "canceled windup produces no ghost hit")
	enemy.reset()
	_check(enemy.health == 3.0 and not enemy.dead and enemy.ai_state == &"patrol", "reset restores independent composition")
	_check(enemy.get_node("Hurtbox").collision_layer == 4 and enemy.collision_layer == 32, "reset restores both physical receivers")
	await _finish()

func _dead_attack() -> void:
	await _begin("explicit depletion boundary and no ghost attack")
	_attack()
	await _until(func(): return enemy.ai_state == &"windup")
	enemy.take_hit(99.0, 1.0, true)
	_check(enemy.dead and defeats == 1, "depletion owns a single defeated signal")
	_check(enemy.get_node("Hurtbox").collision_layer == 0 and enemy.collision_layer == 0, "dead body cannot receive contacts")
	await _seconds(1.2)
	_check(receipts.is_empty(), "dead windup never dispatches")
	enemy.take_hit(99.0, 1.0, true)
	_check(defeats == 1, "dead repeated API hit cannot defeat twice")
	var old_serial: int = enemy.attack_serial
	enemy.reset()
	await _frames(2)
	_check(enemy.health == 3.0 and enemy.attack_serial >= old_serial, "reset keeps attack identity monotonic")
	await _finish()

func _edge_and_hearing() -> void:
	await _begin("listener sound pursuit and platform edge", "listener", 450, 110, 180)
	enemy.ai_enabled = true
	enemy.hear_noise(Vector2(420, 200), &"prop_impact", 1.2, player)
	await _seconds(1.4)
	_check(enemy.ai_state == &"investigate" and enemy.position.x > 120, "listener moves toward remembered sound")
	_check(enemy.position.x < 170 and enemy.position.y < 201, "listener brakes before platform lip")
	enemy.set_blind_mode(true)
	enemy._emit_noise(enemy.global_position, &"enemy_step", 0.4)
	_check(enemy.reveal_remaining > 0.0, "own real sound opens local visual reveal")
	await _finish()

func _prop_hit() -> void:
	await _begin("real launched rigid-body prop impact", "warden", 30, 170)
	var crate = CRATE.instantiate()
	crate.position = Vector2(95, 183)
	crate.collision_mask = 33
	world.add_child(crate)
	await _frames(3)
	crate.launch(1)
	_check(await _until(func(): return enemy.health < 8.0, 1.0), "actual moving crate collides with enemy body32")
	_check(enemy.health == 5.0 and enemy.stun_left > 0, "legacy three-argument prop hit debits shared health once")
	await _finish()
