extends SceneTree
## Actual production PC/contact/shield/motor callbacks at both physics rates.
## Direct lifecycle/setup probes are labeled; no test writes combat hit results.
const WARDEN = preload("res://demo/components/warden.tscn")
const PLAYER = preload("res://combat_pc/player.tscn")
const HEALTH = preload("res://combat_pc/components/health_component.tscn")
class Driver extends Node:
	var player: Node
	var frame := {}
	func _physics_process(dt: float) -> void:
		if is_instance_valid(player): player.physics_tick(dt, frame)

var world: Node2D
var enemy: Node2D
var player: Node2D
var driver: Driver
var player_health: Node
var hz := 120
var checks := 0
var failures: Array[String] = []
var scenarios: Array[String] = []
var receipts: Array[Dictionary] = []
var health_receipts: Array[Dictionary] = []
var defeats := 0
var phase_events := 0
var duel_seconds := 0.0
var sources := ["res://demo/components/enemy.gd", "res://combat_pc/player.gd", "res://combat_pc/components/contact_adapter.gd", "res://combat_pc/components/shield_contact_adapter.gd", "res://combat_pc/components/health_component.gd", "res://combat_pc/components/strike_health.gd", "res://combat_pc/components/strike_knockback.gd", "res://movement/components/movement_motor.gd", "res://prop.gd"]
var hashes := {}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()

func _run() -> void:
	for path in sources: hashes[path] = FileAccess.get_sha256(path)
	await _windup_brace()
	await _active_brace()
	await _parry(false)
	await _parry(true)
	await _guard()
	await _recovery_opening()
	await _lethal_brace()
	await _reset_windup()
	await _phase_threshold()
	await _alternating_reach()
	await _escaped()
	await _late_wall()
	await _roll()
	await _forged_counter()
	await _input_duel()
	for path in sources: _check(hashes[path] == FileAccess.get_sha256(path), "preserved source unchanged: " + path)
	var report := {"suite": "demo Warden climax", "hz": hz, "checks": checks, "failures": failures, "scenarios": scenarios,
		"input_only_duel_seconds": duel_seconds, "preserved_hashes": hashes, "execution": "Actual Godot physics callbacks and production PC/ContactAdapter/ShieldContactAdapter/health/motor. Direct lifecycle and setup probes explicitly labeled."}
	FileAccess.open("res://demo/tests/warden_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("DEMO WARDEN %d Hz: %d scenarios, %d checks, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _begin(label: String, capacity := 16.0) -> void:
	scenarios.append(label)
	receipts = []
	health_receipts = []
	defeats = 0
	phase_events = 0
	world = Node2D.new()
	root.add_child(world)
	_surface(Vector2(400, 220), Vector2(800, 40))
	player = PLAYER.instantiate()
	player.automatic_physics = false
	player.position = Vector2(100, 200)
	player_health = HEALTH.instantiate()
	player_health.maximum_health = 60.0
	player.add_child(player_health)
	world.add_child(player)
	player.damage_resolved.connect(func(receipt: Dictionary): receipts.append(receipt.duplicate(true)))
	driver = Driver.new()
	driver.player = player
	world.add_child(driver)
	enemy = WARDEN.instantiate()
	enemy.position = Vector2(136, 200)
	enemy.max_health = capacity
	enemy.ai_enabled = false
	world.add_child(enemy)
	enemy.configure(player, root.get_node("NoiseBus"))
	enemy.defeated.connect(func(_who): defeats += 1)
	enemy.phase_changed.connect(func(_who, _phase): phase_events += 1)
	enemy.get_node("StrikeHealth/Health").damage_processed.connect(func(r): health_receipts.append(r.duplicate(true)))
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

func _windup_brace() -> void:
	await _begin("physical melee during committed windup")
	_attack()
	_check(await _until(func(): return enemy.ai_state == &"windup"), "AI begins windup")
	var serial: int = enemy.attack_serial
	var start: Vector2 = enemy.position
	driver.frame = {"attack": true}
	_check(await _until(func(): return enemy.health < 16.0), "real PC strike reaches shared health")
	driver.frame = {}
	_check(enemy.health == 15.0 and health_receipts[0].applied == 1.0, "brace takes full confirmed strike damage")
	_check(enemy.is_braced() and enemy.ai_state == &"windup" and enemy.stun_left == 0.0, "ordinary strike cannot cancel windup")
	_check(enemy.braced_contacts == 1 and enemy.position.distance_to(start) < 0.2, "brace stays physically planted")
	_check(enemy.get_node("Knockback").applied_count == 1 and enemy.get_node("StrikeHealth").resolved_count == 1, "original contact adapters each admit the hit once")
	_check(await _until(func(): return not receipts.is_empty()), "braced attack still reaches actual overlapping player")
	_check(receipts.size() == 1 and receipts[0].amount == 18.0 and player_health.current_health == 42.0, "host-scale hit deals full eighteen of sixty")
	await _seconds(0.22)
	_check(receipts.size() == 1 and enemy.attack_serial == serial, "active frames deliver exactly once")
	for noise_kind in [&"enemy_windup", &"enemy_attack", &"enemy_damage"]:
		_check(root.get_node("NoiseBus").event_history.any(func(e): return e.source_id == enemy.get_instance_id() and e.kind == noise_kind), "canonical provenance: " + String(noise_kind))
	await _finish()

func _active_brace() -> void:
	await _begin("physical rear melee during active brace")
	_attack()
	await _until(func(): return enemy.ai_state == &"windup")
	# Repositioning is an explicit setup probe; the following strike is real.
	player.reset_actor(Vector2(172, 200), -1)
	_check(await _until(func(): return enemy.ai_state == &"active"), "committed facing does not track a crossed player")
	driver.frame = {"attack": true}
	_check(await _until(func(): return enemy.health < 16.0, 0.4), "actual rear strike connects during active window")
	_check(enemy.health == 15.0 and enemy.ai_state == &"active" and enemy.stun_left == 0.0, "active brace retains state and full damage")
	_check(receipts.is_empty(), "left-facing committed box cannot hit behind its owner")
	await _finish()

func _parry(sweep: bool) -> void:
	await _begin("physical timed parry and counter " + ("sweep" if sweep else "cut"))
	# Selecting the second pattern is setup only; all contact remains physical.
	if sweep: enemy.committed_attacks = 1
	_attack()
	await _until(func(): return enemy.ai_state == &"windup" and enemy._phase_elapsed >= enemy._windup - 0.10)
	driver.frame = {"shield": true}
	_check(await _until(func(): return not receipts.is_empty()), "real attack reaches shield")
	_check(receipts[0].outcome == &"parried" and receipts[0].amount == 0.0, "timed parry negates all eighteen damage")
	_check(player_health.current_health == 60.0, "parry preserves player health")
	_check(enemy.health == 13.0 and enemy.stun_left > 0.0 and enemy.ai_state == &"stagger", "stock confirmed three-damage counter breaks brace")
	_check(not enemy.is_braced() and player.get_node("ShieldContactAdapter").confirmed_counters == 1, "real shield contact owns interruption")
	await _seconds(0.4)
	_check(receipts.size() == 1, "interrupted active swing cannot dispatch again")
	await _finish()

func _guard() -> void:
	await _begin("held frontal guard remains physical")
	driver.frame = {"shield": true}
	await _seconds(0.23)
	_attack()
	_check(await _until(func(): return not receipts.is_empty()), "real contact reaches held shield")
	_check(receipts[0].outcome == &"guarded" and receipts[0].amount == 4.5, "ordinary guard retains stock seventy-five percent absorption")
	_check(enemy.health == 16.0 and enemy.stun_left == 0.0, "holding guard does not grant a free counter")
	await _finish()

func _recovery_opening() -> void:
	await _begin("physical recovery punish remains interruptible")
	_attack()
	await _until(func(): return enemy.ai_state == &"windup")
	player.reset_actor(Vector2(172, 200), -1)
	_check(await _until(func(): return enemy.ai_state == &"recover"), "miss opens normal recovery")
	_check(not enemy.is_braced(), "brace ends before recovery")
	driver.frame = {"attack": true}
	_check(await _until(func(): return enemy.health < 16.0), "physical recovery punish deals damage")
	_check(enemy.health == 15.0 and enemy.ai_state == &"stagger" and enemy.stun_left > 0.0, "ordinary recovery strike gets stock knockback and stagger")
	await _finish()

func _lethal_brace() -> void:
	await _begin("physical lethal strike through brace", 1.0)
	_attack()
	await _until(func(): return enemy.ai_state == &"windup")
	driver.frame = {"attack": true}
	_check(await _until(func(): return enemy.dead), "real confirmed strike is lethal while braced")
	_check(enemy.health == 0.0 and defeats == 1 and not enemy.is_braced(), "depletion ends brace and defeats once")
	await _frames(2)
	_check(enemy.get_node("BodyShape").disabled and enemy.get_node("Hurtbox/Shape").disabled, "dead body and hurtbox are disabled")
	await _seconds(1.2)
	_check(receipts.is_empty(), "lethal braced windup cannot produce a ghost hit")
	await _finish()

func _reset_windup() -> void:
	await _begin("explicit reset during committed windup")
	_attack()
	await _until(func(): return enemy.ai_state == &"windup")
	var serial: int = enemy.attack_serial
	enemy.reset()
	enemy.ai_enabled = false
	_check(enemy.health == 16.0 and not enemy.is_braced() and enemy.ai_state == &"patrol", "reset restores full health and retires brace")
	_check(enemy.attack_style == &"cut" and enemy.committed_attacks == 0, "reset restores readable opening pattern")
	await _seconds(1.2)
	_check(receipts.is_empty(), "reset windup never produces a ghost hit")
	_attack()
	_check(await _until(func(): return enemy.ai_state == &"windup"), "new life can attack")
	_check(enemy.attack_serial > serial, "new attack keeps monotonic identity")
	await _finish()

func _phase_threshold() -> void:
	await _begin("below-half pressure from physical strike")
	# Explicit setup damage establishes the exact-half boundary. The threshold
	# crossing itself must come through the production PC ContactAdapter.
	enemy.take_hit(8.0, 1.0, true)
	_check(enemy.health == 8.0 and not enemy.pressure_phase, "exact half does not trigger below-half phase")
	await _seconds(0.6)
	enemy.position = Vector2(136, 200)
	_attack()
	await _until(func(): return enemy.ai_state == &"windup")
	var warning: float = enemy._windup
	driver.frame = {"attack": true}
	_check(await _until(func(): return enemy.health < 8.0), "real strike crosses the threshold")
	_check(enemy.health == 7.0 and enemy.pressure_phase and phase_events == 1, "phase neither heals nor adds a second health bar")
	_check(enemy._windup == warning and enemy._recovery == 0.64, "warning stays readable and recovery alone accelerates")
	_check(enemy.ai_state == &"windup" and enemy.stun_left == 0.0, "phase crossing does not cancel committed attack")
	enemy.reset()
	enemy.ai_enabled = false
	driver.frame = {}
	_check(not enemy.pressure_phase and enemy.health == 16.0 and enemy._recovery == 0.90, "reset restores first-phase cadence")
	await _finish()

func _alternating_reach() -> void:
	await _begin("alternating cut and sweep with honest visible reach")
	_attack()
	await _until(func(): return enemy.ai_state == &"windup")
	var cut_rect: Rect2 = enemy.attack_rect_local()
	_check(enemy.attack_style == &"cut" and cut_rect.size == Vector2(57, 27), "opening cut preview matches inherited shape")
	player.reset_actor(Vector2(60, 200), 1)
	await _until(func(): return enemy.ai_state == &"recover")
	_check(receipts.is_empty(), "player body beyond the cut rectangle is safe")
	player.reset_actor(Vector2(100, 200), 1)
	_check(await _until(func(): return enemy.attack_serial == 2 and enemy.ai_state == &"windup"), "second attack naturally alternates to sweep")
	var sweep_rect: Rect2 = enemy.attack_rect_local()
	_check(enemy.attack_style == &"sweep" and sweep_rect.size == Vector2(73, 27) and enemy._windup > 1.0, "longer reach has longer warning")
	player.reset_actor(Vector2(60, 200), 1)
	_check(await _until(func(): return not receipts.is_empty()), "longer visible sweep reaches the actual same player body")
	_check(receipts[0].amount == 18.0, "sweep uses the same full damage rather than an invisible bonus")
	await _finish()

func _escaped() -> void:
	await _begin("escape outside committed reach")
	_attack()
	await _until(func(): return enemy.ai_state == &"windup")
	player.reset_actor(Vector2(10, 200), 1)
	await _seconds(1.1)
	_check(receipts.is_empty(), "committed swing misses a body outside its rectangle")
	await _finish()

func _late_wall() -> void:
	await _begin("terrain inserted during committed windup")
	_attack()
	await _until(func(): return enemy.ai_state == &"windup")
	_surface(Vector2(118, 165), Vector2(8, 70))
	await _seconds(1.15)
	_check(receipts.is_empty(), "physical line-of-contact rejects a newly occluded target")
	await _finish()

func _roll() -> void:
	await _begin("timed stock roll against braced cut")
	_attack()
	await _until(func(): return enemy.ai_state == &"windup" and enemy._phase_elapsed >= enemy._windup - 0.08)
	driver.frame = {"roll": true}
	_check(await _until(func(): return not receipts.is_empty(), 0.35), "physical attack intersects rolling player")
	if not receipts.is_empty(): _check(receipts[0].outcome == &"evaded" and receipts[0].amount == 0.0, "stock roll window adjudicates evasion")
	_check(player_health.current_health == 60.0, "timed roll preserves health")
	await _finish()

func _forged_counter() -> void:
	await _begin("explicit stale-counter boundary")
	_attack()
	await _until(func(): return enemy.ai_state == &"windup")
	var result: Dictionary = enemy.receive_shield_counter({"defender": player, "target_id": enemy.get_instance_id(), "damage": 3.0, "impulse": Vector2(-100, -50), "shield_serial": -1, "attack_key": "retired"})
	_check(not result.accepted and enemy.is_braced() and enemy.health == 16.0, "unconfirmed counter cannot bypass physical shield authority")
	await _finish()

func _input_duel() -> void:
	await _begin("complete input-only duel through repeated real parries")
	_attack()
	# From here until defeat, only actual player input changes. No teleports,
	# health edits, synthetic receipts, phase writes, or forced enemy states.
	for tick in hz * 40:
		if enemy.dead:
			duel_seconds = float(tick) / hz
			break
		var raw := {}
		var dx: float = enemy.position.x - player.position.x
		if enemy.ai_state == &"windup" and enemy._phase_elapsed >= enemy._windup - 0.10:
			raw.shield = true
		elif not enemy.is_braced() and absf(dx) > 32.0:
			raw["right" if dx > 0.0 else "left"] = 1.0
		driver.frame = raw
		await _frames(1)
	_check(enemy.dead and defeats == 1, "six physical counters finish the sixteen-health climax within forty seconds")
	_check(enemy.health == 0.0 and phase_events == 1, "duel crosses phase once and ends at zero health")
	_check(player.get_node("ShieldContactAdapter").confirmed_counters == 6, "exactly six real three-damage counters own the win")
	_check(player_health.current_health == 60.0, "clean defense can win with no unavoidable damage")
	var count := receipts.size()
	driver.frame = {}
	await _seconds(1.2)
	_check(receipts.size() == count and defeats == 1, "final lethal counter produces no post-victory ghost attack")
	await _finish()
