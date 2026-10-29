extends SceneTree
## M12 focused integration acceptance. Each tick is one real engine callback.
## Reports contain assertions and bounded measurements, never per-tick dumps.
const PLAYER = preload("res://combat_pc/player.tscn")
const HEALTH = preload("res://combat_pc/components/health_component.tscn")
const MELEE = preload("res://combat_pc/fixtures/guard_melee_fixture.tscn")
const PROJECTILE = preload("res://combat_pc/fixtures/guard_projectile.gd")
const SOURCES = ["res://combat_pc/player.gd", "res://combat_pc/player.tscn", "res://combat_pc/components/health_component.gd", "res://combat_pc/components/health_component.tscn", "res://combat_pc/fixtures/guard_melee_fixture.gd", "res://combat_pc/fixtures/guard_projectile.gd"]

class Driver extends Node:
	var actors: Array[Node] = []
	var frame: Dictionary = {}
	var ticks := 0
	var last_frame := -1
	var repeated_frames := 0
	var wrong_delta := 0
	var expected_delta := 1.0 / 60.0
	func _physics_process(delta: float) -> void:
		var engine_frame := Engine.get_physics_frames()
		if engine_frame == last_frame: repeated_frames += 1
		if absf(delta - expected_delta) > 0.0000001: wrong_delta += 1
		last_frame = engine_frame
		for actor in actors:
			if is_instance_valid(actor) and actor.is_inside_tree(): actor.physics_tick(delta, frame)
		ticks += 1

var hz := 60
var dt := 1.0 / 60.0
var world: Node2D
var actor: Node
var health: Node
var driver: Driver
var receipts: Array[Dictionary] = []
var processed: Array[Dictionary] = []
var health_changes: Array[Vector2] = []
var depletions := 0
var movement: Array[String] = []
var order: Array[String] = []
var checks: Array[Dictionary] = []
var scenarios: Array[Dictionary] = []
var failures: Array[String] = []
var label := ""
var scenario_check_start := 0
var hashes := {}
var total_ticks := 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): hz = int(argument.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	dt = 1.0 / hz
	_run.call_deferred()

func _run() -> void:
	for path in SOURCES: hashes[path] = FileAccess.get_sha256(path)
	await _outcomes()
	await _identity()
	await _legacy_and_invalid()
	await _reset_during_resolution()
	await _commit_and_actor_lifetime()
	await _reset_before_observer()
	await _nested_receipts()
	await _health_callback_reset()
	await _queued_component_lifetime()
	await _processed_callback_reset()
	await _detach_and_rebind()
	await _depletion_and_capacity()
	await _fixture_contact()
	await _motor_parity()
	var stable := true
	for path in SOURCES: stable = stable and hashes[path] == FileAccess.get_sha256(path)
	_check(stable, "production sources stayed unchanged during run")
	var report := {"milestone": 12, "physics_hz": hz, "execution": "Real Godot physics callbacks and real player scene, optional component, swept melee/projectile fixtures", "generated_utc": Time.get_datetime_string_from_system(true), "engine": Engine.get_version_info().string, "checks": checks.size(), "failures": failures, "scenarios": scenarios, "total_physics_ticks": total_ticks, "production_hash_stable_during_run": stable, "source_hashes": hashes, "limitations": ["Headless integration checks; parent owns native visual review", "No death, healing, persistence, combat AI, or exact Dead Cells numerical parity claim"]}
	FileAccess.open("res://combat_pc/tests/health_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("HEALTH_M12 %dHz: %d checks, %d scenarios, %d failures" % [hz, checks.size(), scenarios.size(), failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _check(passed: bool, text_: String, details: Dictionary = {}) -> void:
	checks.append({"passed": passed, "assertion": text_, "details": details})
	if not passed:
		failures.append(label + ": " + text_ + (" " + str(details) if not details.is_empty() else ""))
		printerr("FAIL ", failures.back())

func _near(actual: float, expected: float, text_: String) -> void:
	_check(absf(actual - expected) <= 0.000001, text_, {"actual": actual, "expected": expected})

func _begin(name_: String, attach := true) -> void:
	label = name_
	scenario_check_start = checks.size()
	receipts = []; processed = []; health_changes = []; depletions = 0; movement = []; order = []
	world = Node2D.new()
	root.add_child(world)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 220)
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(4000, 40)
	floor_body.add_child(shape)
	world.add_child(floor_body)
	actor = _new_actor()
	actor.movement_event.connect(func(kind: StringName, _payload: Dictionary):
		movement.append(String(kind)); order.append(String(kind)))
	actor.damage_resolved.connect(func(receipt: Dictionary): receipts.append(receipt); order.append("damage_resolved"))
	driver = Driver.new()
	driver.actors.append(actor)
	driver.expected_delta = dt
	driver.process_physics_priority = 20
	world.add_child(driver)
	health = null
	if attach: _attach_health()
	await _step({}, 3)
	_check(actor.grounded, "real actor settles on the physical floor")

func _new_actor(at := Vector2(100, 200)) -> Node:
	var result: Node = PLAYER.instantiate()
	result.position = at
	result.automatic_physics = false
	result.shield_profile = result.shield_profile.duplicate(true)
	world.add_child(result)
	return result

func _attach_health(target: Node = null) -> Node:
	var result: Node = HEALTH.instantiate()
	result.health_changed.connect(func(current: float, maximum: float): health_changes.append(Vector2(current, maximum)))
	result.damage_processed.connect(func(receipt: Dictionary): processed.append(receipt))
	result.depleted.connect(func(): depletions += 1)
	(target if target != null else actor).add_child(result)
	health = result
	return result

func _step(frame: Dictionary = {}, count := 1) -> void:
	driver.frame = frame
	for _index in count:
		var target := driver.ticks + 1
		while driver.ticks < target:
			await physics_frame
			await process_frame

func _until(predicate: Callable, frame: Dictionary = {}, seconds := 1.0) -> bool:
	for _index in ceili(seconds / dt):
		if predicate.call(): return true
		await _step(frame)
	return bool(predicate.call())

func _finish(details: Dictionary = {}) -> void:
	_check(driver.repeated_frames == 0 and driver.wrong_delta == 0, "one driver sample per real engine callback at requested delta")
	scenarios.append({"name": label, "assertions": checks.slice(scenario_check_start), "physics_ticks": driver.ticks, "measurements": details})
	total_ticks += driver.ticks
	driver.set_physics_process(false)
	world.queue_free()
	await process_frame
	world = null; actor = null; health = null; driver = null

func _source(name_ := "Source") -> Node2D:
	var source := Node2D.new()
	source.name = name_
	source.position = actor.position + Vector2(35, -17)
	world.add_child(source)
	return source

func _attack(source: Node, identifier: int, amount := 10.0, extra: Dictionary = {}) -> Dictionary:
	var state: Dictionary = actor.telemetry()
	var point: Vector2 = state.shield_center
	var body_front: float = actor.profile.body_width * 0.5
	var inner: float = body_front + actor.shield_profile.contact_forward_offset - actor.shield_profile.contact_width * 0.5
	point.x = actor.position.x + actor.facing * (maxf(0, inner) + body_front) * 0.5
	return {"attack_id": identifier, "source": source, "kind": &"melee", "origin": actor.position + Vector2(35 * actor.facing, -17), "contact_position": point, "incoming_velocity": Vector2(-200 * actor.facing, 0), "amount": amount, "impulse": Vector2(-120 * actor.facing, -50), "stun_seconds": 0.18, "hitpause": 0.0, "blockable": true, "parryable": true, "reflectable": false, "counterable": false, "rollable": true}.merged(extra, true)

func _enter(mode: String) -> void:
	if mode == "guard":
		await _step({"shield": true})
		_check(await _until(func(): return actor.shield_phase == &"hold", {"shield": true}), "real input enters held guard")
	elif mode == "parry":
		await _step({"shield": true})
		_check(await _until(func(): return actor.is_shield_parry_open(), {"shield": true}), "real input reaches open parry window")
	elif mode == "roll":
		await _step({"roll": true})
		_check(await _until(func(): return actor.is_roll_invulnerable()), "real input reaches roll invulnerability")

func _outcomes() -> void:
	for mode in ["hurt", "guard", "parry", "roll"]:
		await _begin("resolved " + mode + " and duplicate")
		await _enter(mode)
		var source := _source()
		var payload := _attack(source, 1, 20)
		var result: Dictionary = actor.receive_attack(payload)
		var expected: StringName = {"hurt": &"hurt", "guard": &"guarded", "parry": &"parried", "roll": &"evaded"}[mode]
		var amount: float = 20.0 if mode == "hurt" else 20.0 * (1.0 - actor.shield_profile.guard_absorption) if mode == "guard" else 0.0
		_check(result.outcome == expected and result.consumed, "defense result remains the phase-specific consumed outcome")
		_near(health.current_health, 100.0 - amount, "health applies only resolved residual damage")
		_check(receipts.size() == 1 and processed.size() == 1, "one accepted contact emits one damage receipt and one processed notification")
		var scalar := true
		for value in receipts[0].values(): scalar = scalar and (value is int or value is float or value is String or value is StringName)
		_check(receipts[0].is_read_only() and processed[0].is_read_only() and scalar, "public receipts are immutable scalar snapshots without actor/source references")
		_check(receipts[0].actor_id == actor.get_instance_id() and receipts[0].generation == actor.damage_generation(), "receipt carries the live actor and reset generation")
		_check(order.find("defense_resolved") < order.find("damage_resolved"), "old defense notification precedes appended health receipt")
		var move_count := movement.size()
		var repeat: Dictionary = actor.receive_attack(payload)
		_check(repeat.outcome == &"duplicate" and not repeat.consumed and movement.size() == move_count and receipts.size() == 1 and processed.size() == 1, "duplicate ID adds no health debit or old/new notifications")
		if mode == "guard": _check(actor.main_action != &"hurt" and actor.shield_phase == &"hold", "guard residual does not invoke full hurt ownership")
		if mode in ["parry", "roll"]: _check(health_changes.size() == 1, "zero damage does not emit a spurious health change")
		await _finish({"outcome": String(expected), "residual": amount, "health": health.current_health, "events": order})

func _identity() -> void:
	await _begin("reordered identities and source namespaces")
	var first := _source("FirstSource")
	var second := _source("SecondSource")
	var high: Dictionary = actor.receive_attack(_attack(first, 11, 3))
	var low: Dictionary = actor.receive_attack(_attack(first, 10, 4))
	var other: Dictionary = actor.receive_attack(_attack(second, 11, 5))
	_check(high.consumed and low.consumed and other.consumed, "fresh lower in-window ID and same ID from another source are accepted")
	_near(health.current_health, 88, "reordered and independent-source hits each debit once")
	var duplicate: Dictionary = actor.receive_attack(_attack(first, 10, 99))
	_check(duplicate.outcome == &"duplicate" and receipts.size() == 3, "reordered ID is still deduplicated on repeat")
	actor.shield_profile.incoming_history_window = 4
	actor.receive_attack(_attack(first, 30, 2))
	var stale: Dictionary = actor.receive_attack(_attack(first, 20, 99))
	_check(stale.outcome == &"rejected" and stale.get("reason") == &"stale_attack_id", "ID outside actor history window is rejected without debit")
	_near(health.current_health, 86, "stale contact preserves health")
	var first_carrier := _source("CarrierOne")
	var second_carrier := _source("CarrierTwo")
	actor.receive_attack(_attack(first, 1, 2, {"kind": &"projectile", "carrier": first_carrier}))
	actor.receive_attack(_attack(first, 1, 2, {"kind": &"projectile", "carrier": second_carrier}))
	_near(health.current_health, 82, "projectile identity uses each carrier even with shared owner and local ID")
	_check(receipts.size() == 6, "only six fresh identities produce receipts")
	await _finish({"health": health.current_health, "receipts": receipts.size()})

func _legacy_and_invalid() -> void:
	await _begin("legacy compatibility and invalid contacts")
	_check(actor.receive_hit({"amount": 7, "hitpause": 0.0}), "legacy receive_hit retains committed-hurt boolean")
	_check(actor.receive_hit({"amount": 7, "hitpause": 0.0}), "legacy contacts without identity remain independently applicable")
	actor.receive_attack({})
	_near(health.current_health, 85, "legacy default amount and explicit amounts reach health")
	var source := _source()
	for patch in [{"attack_id": 0}, {"attack_id": "1"}, {"source": null}, {"kind": &"unknown"}, {"contact_position": Vector2.INF}]:
		var rejected: Dictionary = actor.receive_attack(_attack(source, 5, 50, patch))
		_check(not rejected.consumed, "malformed identified contact is rejected", {"field": str(patch.keys()[0])})
	_near(health.current_health, 85, "invalid contacts do not debit")
	actor.receive_attack({"amount": -25.0, "hitpause": 0.0})
	_near(health.current_health, 85, "negative legacy amount cannot heal")
	var before_count := receipts.size()
	actor.receive_attack({"amount": INF, "hitpause": 0.0})
	actor.receive_attack({"amount": NAN, "hitpause": 0.0})
	_near(health.current_health, 85, "nonfinite amounts cannot corrupt stored health")
	_check(receipts.size() == before_count, "nonfinite residuals do not emit a damage receipt")
	await _finish({"health": health.current_health})

func _reset_during_resolution() -> void:
	for phase in ["hurt_started", "defense_resolved"]:
		await _begin("reset synchronously during " + phase)
		if phase == "defense_resolved": await _enter("guard")
		var captured := [false]
		actor.movement_event.connect(func(kind: StringName, _payload: Dictionary):
			if String(kind) == phase and not captured[0]: captured[0] = true; actor.reset_actor(Vector2(100, 200)))
		var generation: int = actor.damage_generation()
		var result: Dictionary = actor.receive_attack(_attack(_source(), 1, 150))
		_check(captured[0] and result.consumed and actor.damage_generation() > generation, "callback resets during the original consumed defense")
		_check(receipts.is_empty() and processed.is_empty() and depletions == 0, "old resolution emits no new-life damage or depletion")
		_near(health.current_health, 100, "actor reset leaves replacement life full")
		await _finish()

func _reset_before_observer() -> void:
	await _begin("reset during receipt emission before health observer", false)
	var did_reset := [false]
	actor.damage_resolved.connect(func(_receipt: Dictionary):
		if not did_reset[0]: did_reset[0] = true; actor.reset_actor(Vector2(100, 200)))
	_attach_health()
	actor.receive_attack(_attack(_source(), 1, 80))
	_check(receipts.size() == 1 and processed.is_empty(), "receipt emitted before reset is rejected by later observer generation check")
	_near(health.current_health, 100, "in-flight old receipt does not debit fresh generation")
	await _finish()

func _commit_and_actor_lifetime() -> void:
	for stage in ["action_changed", "hurt_started"]:
		await _begin("hurt ownership replaced at " + stage)
		var replaced := [false]
		var replace := func():
			if replaced[0]: return
			replaced[0] = true
			actor.begin_main_action(&"forced", {}, func(target, _delta, _frame): target.velocity = Vector2(17, -111); return true)
			actor.action_phase = &"host_owned"
			actor.velocity = Vector2(17, -111)
		actor.action_changed.connect(func(_old: StringName, next: StringName):
			if stage == "action_changed" and next == &"hurt": replace.call())
		actor.movement_event.connect(func(kind: StringName, _payload: Dictionary):
			if stage == "hurt_started" and kind == &"hurt_started": replace.call())
		var result: Dictionary = actor.receive_attack(_attack(_source(), 1, 10))
		var committed: bool = stage == "hurt_started"
		_check(replaced[0] and result.consumed and result.hurt_applied == committed, "original result distinguishes precommit replacement from committed hurt")
		_near(health.current_health, 90 if committed else 100, "only already-committed hurt can debit health after owner replacement")
		_check(receipts.size() == (1 if committed else 0) and actor.main_action == &"forced" and actor.action_phase == &"host_owned" and actor.velocity == Vector2(17, -111), "health notification preserves newer owner state and callback commitment")
		await _finish()
	for disposition in ["removed", "queued"]:
		await _begin("actor " + disposition + " during hurt callback")
		actor.movement_event.connect(func(kind: StringName, _payload: Dictionary):
			if kind == &"hurt_started":
				if disposition == "removed": world.remove_child(actor)
				else: actor.queue_free())
		var result: Dictionary = actor.receive_attack(_attack(_source(), 1, 10))
		_check(result.consumed and result.hurt_applied, "original committed defense result survives actor retirement")
		_check(receipts.is_empty() and processed.is_empty(), "retired actor never emits a health receipt after callback returns")
		_near(health.current_health, 100, "retired actor cannot debit its optional store")
		if disposition == "removed": actor.free()
		await _finish()

func _nested_receipts() -> void:
	await _begin("nested higher receipt precedes outer lower receipt", false)
	var source := _source()
	var entered := [false]
	actor.damage_resolved.connect(func(_receipt: Dictionary):
		if not entered[0]: entered[0] = true; actor.receive_attack(_attack(source, 2, 20)))
	_attach_health()
	actor.receive_attack(_attack(source, 1, 10))
	_near(health.current_health, 70, "both valid nested and outer receipts debit despite reverse delivery serials")
	_check(processed.size() == 2 and processed[0].serial > processed[1].serial, "health observes nested serial N+1 then outer serial N without highest-serial filtering")
	_check(processed[0].before == 100 and processed[0].after == 80 and processed[1].before == 80 and processed[1].after == 70, "processed snapshots describe the actual debit order")
	await _finish({"processed_serials": [processed[0].serial, processed[1].serial], "health": health.current_health})

func _health_callback_reset() -> void:
	await _begin("health_changed synchronously resets actor")
	health.health_changed.connect(func(current: float, _maximum: float):
		if current == 0: actor.reset_actor(Vector2(100, 200)))
	actor.receive_attack(_attack(_source(), 1, 150))
	_near(health.current_health, 100, "health_changed reset replaces the zero state with full health")
	_check(processed.is_empty() and depletions == 0, "outer damage/depleted notifications stop after synchronous reset")
	_check(health_changes == [Vector2(100, 100), Vector2(0, 100), Vector2(100, 100)], "health_changed exposes damage then reset values in order")
	await _finish()

func _processed_callback_reset() -> void:
	await _begin("damage_processed synchronously resets health")
	health.damage_processed.connect(func(_receipt: Dictionary): health.reset_to_full())
	actor.receive_attack(_attack(_source(), 1, 150))
	_near(health.current_health, 100, "processed observer may explicitly restore health")
	_check(processed.size() == 1 and depletions == 0, "no stale depletion after processed observer replaces zero state")
	await _finish()

func _queued_component_lifetime() -> void:
	for target in ["component", "actor"]:
		await _begin(target + " queued for deletion during health_changed")
		health.health_changed.connect(func(current: float, _maximum: float):
			if current == 0:
				if target == "component": health.queue_free()
				else: actor.queue_free())
		actor.receive_hit({"amount": 150, "hitpause": 0.0})
		var queued: bool = health.is_queued_for_deletion() if target == "component" else actor.is_queued_for_deletion()
		_check(queued and health.current_health == 0, "health_changed observer queues " + target + " after the zero debit")
		_check(processed.is_empty() and depletions == 0, "queued-for-deletion " + target + " suppresses later processed and depleted notifications", {"processed": processed.size(), "depletions": depletions})
		await _finish({"processed": processed.size(), "depletions": depletions})

func _detach_and_rebind() -> void:
	await _begin("component detach rebind and stale callbacks")
	var source := _source()
	actor.receive_attack(_attack(source, 1, 10))
	var old_callback: Callable = health._damage_callback
	var old_receipt: Dictionary = receipts.back()
	actor.remove_child(health)
	actor.receive_attack(_attack(source, 2, 20))
	_near(health.current_health, 90, "detached component no longer receives actor damage")
	actor.add_child(health)
	_check(health.bind_actor(actor), "reattached component explicitly rebinds to live actor")
	old_callback.call(old_receipt)
	_near(health.current_health, 90, "retained callback from old binding is stale")
	for _index in 3: health.bind_actor(actor)
	actor.receive_attack(_attack(source, 3, 10))
	_near(health.current_health, 80, "repeated bind creates one subscription and one debit")
	var replacement := _new_actor(Vector2(300, 200))
	_check(health.bind_actor(replacement), "component can observe a replacement actor")
	health._damage_callback.call(old_receipt)
	_near(health.current_health, 80, "old actor receipt is rejected on replacement binding")
	actor.receive_attack(_attack(source, 4, 10))
	_near(health.current_health, 80, "old actor no longer controls rebound component")
	replacement.receive_hit({"amount": 5, "hitpause": 0.0})
	_near(health.current_health, 75, "replacement actor can debit the existing store")
	_check(not health.bind_actor(source), "binding rejects nodes without actor receipt contract")
	replacement.receive_hit({"amount": 5, "hitpause": 0.0})
	_near(health.current_health, 75, "failed binding remains safely disconnected")
	await _finish()
	await _begin("unbind during health change suppresses stale notifications")
	health.health_changed.connect(func(current: float, _maximum: float):
		if current == 0: health.unbind_actor())
	actor.receive_hit({"amount": 150, "hitpause": 0.0})
	_check(health.current_health == 0 and processed.is_empty() and depletions == 0, "unbind during health_changed invalidates outer processed/depleted signals")
	await _finish()

func _depletion_and_capacity() -> void:
	await _begin("clamped health depletion and reset policy")
	health.maximum_health = 12
	health.reset_to_full()
	actor.receive_hit({"amount": 20, "hitpause": 0.0})
	_check(health.current_health == 0 and depletions == 1 and processed.back().applied == 12, "overkill clamps at zero and reports only actual health applied")
	actor.receive_hit({"amount": 20, "hitpause": 0.0})
	_check(health.current_health == 0 and depletions == 1 and processed.back().applied == 0, "further valid damage at zero never repeats depleted")
	_check(actor.main_action == &"hurt" and actor.allow_input and actor.is_inside_tree(), "depletion imposes no death, actor removal, or permanent input policy")
	health.reset_with_actor = false
	actor.reset_actor(Vector2(100, 200))
	_near(health.current_health, 0, "opted-out actor reset does not refill health")
	health.reset_with_actor = true
	actor.reset_actor(Vector2(100, 200))
	_near(health.current_health, 12, "default actor reset restores configured capacity")
	actor.receive_hit({"amount": 12, "hitpause": 0.0})
	_check(depletions == 2, "fresh full-to-zero transition emits one fresh depletion")
	for invalid_capacity in [0.0, -1.0, INF, NAN]:
		health.maximum_health = invalid_capacity
		health.reset_to_full()
		_check(health.current_health == 100 and health.capacity == 100, "invalid configured maximum resolves to finite default", {"input": str(invalid_capacity)})
	await _finish({"depletions": depletions, "health": health.current_health})

func _fixture_contact() -> void:
	for mode in ["hurt", "guard"]:
		await _begin("physical melee fixture " + mode)
		await _enter(mode)
		var fixture: Node = MELEE.instantiate()
		fixture.position = actor.position + Vector2(43, 0)
		fixture.telegraph_seconds = 0.05
		fixture.attack_damage = 20
		world.add_child(fixture)
		_check(fixture.trigger_attack(), "real melee fixture arms a fresh attack")
		_check(await _until(func(): return fixture.contacts > 0, {"shield": mode == "guard"}), "swept fixture blade contacts actual actor collision body")
		var amount: float = 20.0 if mode == "hurt" else 20.0 * (1.0 - actor.shield_profile.guard_absorption)
		_near(health.current_health, 100 - amount, "physical fixture result reaches optional health exactly once")
		_check(fixture.contacts == 1 and receipts.size() == 1 and fixture.last_result.outcome == (&"hurt" if mode == "hurt" else &"guarded"), "fixture defense result and health receipt agree")
		await _step({"shield": mode == "guard"}, ceili(0.2 / dt))
		_check(receipts.size() == 1, "retired fixture sweep does not repeat health debit")
		await _finish({"contacts": fixture.contacts, "outcome": String(fixture.last_result.outcome), "health": health.current_health})
	await _begin("physical projectile carrier contact")
	var source := _source()
	var projectile: Node = PROJECTILE.new()
	projectile.position = actor.position + Vector2(35, -17)
	projectile.attack_damage = 9
	world.add_child(projectile)
	projectile.configure(source, Vector2(-180, 0), 1)
	_check(await _until(func(): return not receipts.is_empty()), "live swept projectile collides and resolves damage")
	_near(health.current_health, 91, "projectile fixture debits configured amount")
	_check(receipts.size() == 1 and processed.size() == 1, "retired projectile leaves one immutable receipt")
	await _finish({"health": health.current_health})

func _motor_state(target: Node) -> Array:
	return [target.position, target.velocity, target.grounded, target.facing, target.main_action, target.action_phase, target.weapon_phase, target.shield_phase, target.roll_phase, target.body_height, target.hitpause_remaining, target.air_jumps_left, target.air_roll_available, target.weapon_permissions, target.main_capabilities]

func _motor_parity() -> void:
	await _begin("optional component preserves motor and defense behavior")
	var bare := _new_actor()
	driver.actors.append(bare)
	actor.reset_actor(Vector2(100, 200))
	bare.reset_actor(Vector2(100, 200))
	var bare_events: Array[String] = []
	bare.movement_event.connect(func(kind: StringName, _payload: Dictionary): bare_events.append(String(kind)))
	movement.clear()
	var mismatches: Array[int] = []
	var sampled := 0
	for segment in [{"frame": {"right": 1.0}, "seconds": 0.3}, {"frame": {"left": 1.0}, "seconds": 0.3}, {"frame": {"jump": true}, "seconds": 0.1}, {"frame": {}, "seconds": 0.6}, {"frame": {"roll": true}, "seconds": 0.4}, {"frame": {}, "seconds": 0.4}, {"frame": {"shield": true}, "seconds": 0.4}, {"frame": {}, "seconds": 0.4}, {"frame": {"attack": true}, "seconds": 0.2}, {"frame": {}, "seconds": 0.5}]:
		for _index in ceili(segment.seconds / dt):
			await _step(segment.frame)
			sampled += 1
			if _motor_state(actor) != _motor_state(bare): mismatches.append(sampled)
	_check(mismatches.is_empty(), "attached and absent actors have exact per-tick motor/permission parity across run turn jump roll shield melee", {"samples": sampled, "first_mismatches": mismatches.slice(0, 5)})
	_check(movement == bare_events, "component preserves original movement-event sequence")
	for mode in ["hurt", "guard", "parry", "roll"]:
		actor.reset_actor(Vector2(100, 200)); bare.reset_actor(Vector2(100, 200))
		await _step({}, 3)
		await _enter(mode)
		var source := _source()
		var payload := _attack(source, 1, 25)
		var attached_result: Dictionary = actor.receive_attack(payload)
		var bare_result: Dictionary = bare.receive_attack(payload)
		_check(attached_result == bare_result and _motor_state(actor) == _motor_state(bare), "attached and absent actors retain identical " + mode + " result and immediate motor state")
		for _index in ceili(0.2 / dt):
			await _step({"shield": mode == "guard"})
			if _motor_state(actor) != _motor_state(bare): mismatches.append(sampled)
	_check(mismatches.is_empty(), "post-contact recoil pause and recovery stay identical with health attached")
	await _finish({"motor_samples": sampled, "defense_modes": 4, "maximum_recorded_mismatches": mismatches.slice(0, 5)})
