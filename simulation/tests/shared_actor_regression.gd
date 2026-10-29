extends SceneTree
const Actor = preload("res://simulation/actors/shared_actor.tscn")
const PlayerSource = preload("res://simulation/components/player_input_source.gd")
const NPCSource = preload("res://simulation/components/npc_input_source.gd")
const Patrol = preload("res://simulation/components/patrol_intent_policy.gd")
const Driver = preload("res://simulation/components/actor_intent_driver.gd")
const Capabilities = preload("res://simulation/resources/actor_capabilities.gd")
const Cargo = preload("res://simulation/components/physical_cargo.tscn")
const OFFSET := Vector2(1000, 0)
class RawSource extends Node:
	var raw := {}
	func sample_raw(_actor: Node, _dt: float) -> Dictionary: return raw.duplicate(true)
	func reset_intent() -> void: raw.clear()
class RetiringPolicy extends Node:
	var mode := ""
	func reset_intent() -> void: pass
	func sample_intent(actor: Node, _dt: float) -> Dictionary:
		var operation := mode
		mode = ""
		match operation:
			"disable": process_mode = Node.PROCESS_MODE_DISABLED
			"delete": queue_free()
			"switch": actor.get_node("InputSource").policy_path = NodePath("../Replacement")
			"reset": actor.get_node("InputSource").reset_intent()
		return {"move":Vector2.RIGHT} if not operation.is_empty() else {}
class IntentPolicy extends Node:
	var intent := {}
	func sample_intent(_actor: Node, _dt: float) -> Dictionary: return intent.duplicate(true)
	func reset_intent() -> void: intent.clear()
var hz := 120
var checks := 0
var failures: Array[String] = []
var label := ""
var world: Node2D
var pc: Node2D
var npc: Node2D
var pc_events: Array[StringName] = []
var npc_events: Array[StringName] = []
var position_error := 0.0
var velocity_error := 0.0
var paired_ticks := 0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()
func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func _check(value: bool, detail: String) -> void:
	checks += 1
	if not value: failures.append(label + ": " + detail)
func _begin(next: String) -> void:
	label = next
	world = Node2D.new()
	root.add_child(world)
	pc_events = []
	npc_events = []
func _end() -> void:
	world.queue_free()
	await _frames(3)
func _surface(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	return body
func _polygon(at: Vector2, points: PackedVector2Array) -> void:
	var body := StaticBody2D.new()
	body.position = at
	var shape := CollisionPolygon2D.new()
	shape.polygon = points
	body.add_child(shape)
	world.add_child(body)
func _actor(at: Vector2, source: Node, policy: Node = null) -> Node2D:
	var actor := Actor.instantiate() as Node2D
	actor.position = at
	source.name = "InputSource"
	actor.add_child(source)
	if policy != null:
		policy.name = "PatrolPolicy"
		actor.add_child(policy)
	world.add_child(actor)
	return actor
func _pair() -> void:
	pc = _actor(Vector2(80, 200), RawSource.new())
	npc = _actor(Vector2(80, 200) + OFFSET, NPCSource.new(), IntentPolicy.new())
	pc.movement_event.connect(func(kind: StringName, _payload: Dictionary): pc_events.append(kind))
	npc.movement_event.connect(func(kind: StringName, _payload: Dictionary): npc_events.append(kind))
	await _frames(5)
func _equal_input(move := Vector2.ZERO, buttons: Dictionary = {}) -> void:
	var raw := {"left": maxf(0,-move.x), "right": maxf(0,move.x), "up": maxf(0,-move.y), "down": maxf(0,move.y)}
	raw.merge(buttons)
	pc.get_node("InputSource").raw = raw
	var intent := {"move": move}
	intent.merge(buttons)
	npc.get_node("PatrolPolicy").intent = intent
func _compare() -> void:
	paired_ticks += 1
	position_error = maxf(position_error, pc.position.distance_to(npc.position - OFFSET))
	velocity_error = maxf(velocity_error, pc.velocity.distance_to(npc.velocity))
	_check(pc.position.distance_to(npc.position - OFFSET) < 0.05, "translated position agrees tick %d" % paired_ticks)
	_check(pc.velocity.distance_to(npc.velocity) < 0.025, "velocity agrees tick %d" % paired_ticks)
	_check(pc.grounded == npc.grounded and pc.main_action == npc.main_action and pc.weapon_phase == npc.weapon_phase and pc.shield_phase == npc.shield_phase, "support and action states agree tick %d" % paired_ticks)
func _key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func _run() -> void:
	# API-boundary conformance: manual raw input vs translated desired NPC intent.
	_begin("equal input motion/action trajectory")
	for offset in [Vector2.ZERO, OFFSET]: _surface(Vector2(300, 220) + offset, Vector2(900, 40))
	await _pair()
	_check(pc.get_script() == npc.get_script() and pc.scene_file_path == npc.scene_file_path, "exact same actor scene and controller script")
	_check(pc.profile != npc.profile and pc.combat_profile != npc.combat_profile and pc.shield_profile != npc.shield_profile, "motion/combat/defense resources are per instance")
	_check(pc.get_node("IntentDriver").capabilities != npc.get_node("IntentDriver").capabilities, "capability resources are per instance")
	for i in hz * 4:
		var t := float(i) / hz
		var move := Vector2(0.7 if t < 0.9 else (-0.7 if t < 1.5 else 0.0), 1.0 if t >= 1.5 and t < 1.7 else 0.0)
		var buttons := {"jump": (t >= 0.25 and t < 0.38) or (t >= 0.62 and t < 0.70), "roll": t >= 1.9 and t < 1.96, "attack": t >= 2.6 and t < 2.66, "shield": t >= 3.3 and t < 3.8}
		_equal_input(move, buttons)
		await _frames(1)
		_compare()
	_check(pc_events == npc_events, "identical committed movement/action events")
	for kind in [&"ground_jump", &"air_jump", &"landed", &"roll_started"]: _check(pc_events.has(kind), "exercise " + kind)
	_check(pc.attack_serial > 0 and npc.attack_serial == pc.attack_serial, "both ordinary attacks commit")
	_check(pc.shield_serial > 0 and npc.shield_serial == pc.shield_serial, "both ordinary shields commit")
	_check(pc.get_node("NoiseRelay").forwarded_count > 0 and pc.get_node("NoiseRelay").forwarded_count == npc.get_node("NoiseRelay").forwarded_count, "same committed source noises reach actual bus")
	await _end()

	_begin("translated slopes and solid wall")
	for offset in [Vector2.ZERO, OFFSET]:
		_surface(Vector2(300, 220) + offset, Vector2(900, 40))
		_polygon(Vector2(160,200) + offset, PackedVector2Array([Vector2(0,0),Vector2(60,-30),Vector2(60,0)]))
		_surface(Vector2(290,185) + offset, Vector2(140,30))
		_surface(Vector2(370,100) + offset, Vector2(20,200))
	await _pair()
	for i in hz * 2:
		_equal_input(Vector2.RIGHT)
		await _frames(1)
		_compare()
	_check(pc.position.x > 340 and pc.position.x < 353 and pc.grounded, "actual ramp ascent ends against solid wall")
	await _end()

	_begin("actual support removal")
	var support_a := _surface(Vector2(80,220),Vector2(180,40))
	var support_b := _surface(Vector2(80,220)+OFFSET,Vector2(180,40))
	await _pair()
	_check(pc.grounded and npc.grounded, "both grounded before support disappears")
	support_a.queue_free()
	support_b.queue_free()
	for i in ceili(hz * 0.35):
		await _frames(1)
		_compare()
	_check(not pc.grounded and pc.position.y > 220 and not npc.grounded, "both fall naturally after real support removal")
	await _end()

	_begin("same admitted impulse boundary")
	for offset in [Vector2.ZERO, OFFSET]: _surface(Vector2(80,220)+offset,Vector2(180,40))
	await _pair()
	# Explicit incoming-attack API fixture, not a claim of melee contact parity.
	pc.receive_hit({"amount":2.0,"impulse":Vector2(650,-90),"stun_seconds":0.6,"hitpause":0.0})
	npc.receive_hit({"amount":2.0,"impulse":Vector2(650,-90),"stun_seconds":0.6,"hitpause":0.0})
	for i in ceili(hz * 0.6):
		await _frames(1)
		_compare()
	_check(pc.position.x > 180 and pc.position.y > 205, "shared external response can carry either actor beyond support")
	_check(pc.get_node("Health").current_health == npc.get_node("Health").current_health, "shared scalar health response agrees")
	await _end()

	_begin("real falling cargo into same actor composition")
	for offset in [Vector2.ZERO, OFFSET]: _surface(Vector2(300,220)+offset,Vector2(900,40))
	await _pair()
	for offset in [Vector2.ZERO, OFFSET]:
		var cargo := Cargo.instantiate()
		cargo.position = Vector2(80,65)+offset
		cargo.tuning = cargo.tuning.duplicate(true)
		cargo.tuning.hard_impacts_to_break = 100
		world.add_child(cargo)
	await _frames(hz)
	_check(pc.get_node("PhysicalImpactReceiver").accepted_count == 1 and npc.get_node("PhysicalImpactReceiver").accepted_count == 1, "both receive one real rigid collision")
	_check(pc.get_node("Health").current_health == 27 and npc.get_node("Health").current_health == 27, "real contact debits same health quantity")
	_check(pc.get_node("PhysicalImpactReceiver").last_receipt.outcome == &"hurt" and npc.get_node("PhysicalImpactReceiver").last_receipt.outcome == &"hurt", "same defended-attack response path")
	_check(pc.get_node("HearingSensor").heard_count > 0 and npc.get_node("HearingSensor").heard_count > 0, "both common sensors receive actual contact noise")
	await _end()

	_begin("per-instance capability gates and reset")
	for offset in [Vector2.ZERO, OFFSET]: _surface(Vector2(300,220)+offset,Vector2(900,40))
	await _pair()
	var caps := Capabilities.new()
	caps.can_move = false; caps.can_jump = false; caps.can_roll = false; caps.can_attack = false; caps.can_shield = false; caps.can_hear = false
	npc.get_node("IntentDriver").configure_capabilities(caps)
	await _frames(2)
	_equal_input(Vector2.RIGHT,{"jump":true,"roll":true,"attack":true,"shield":true})
	await _frames(ceili(hz*0.1))
	_check(npc.position.distance_to(Vector2(80,200)+OFFSET) < 0.1 and npc.grounded, "disabled movement and jump leave collision/gravity live")
	_check(npc.attack_serial == 0 and npc.roll_serial == 0 and npc.shield_serial == 0, "disabled action capabilities reject raw requests")
	_check(pc.position.x > 90, "peer retains enabled movement capability")
	_check(not npc.get_node("HearingSensor").enabled and pc.get_node("HearingSensor").enabled, "hearing capability is local")
	caps.can_jump = true
	_check(not npc.get_node("IntentDriver").capabilities.can_jump, "caller resource mutation cannot change adopted configuration")
	npc.reset_actor(Vector2(80,200)+OFFSET)
	await _frames(3)
	_check(not npc.weapon_permissions.can_move and not npc.weapon_permissions.can_jump, "reset reapplies per-instance permissions")
	_check(npc.get_node("IntentDriver").capabilities != pc.get_node("IntentDriver").capabilities, "reset never aliases peer capabilities")
	await _end()

	_begin("actual InputMap and held-action rearming")
	_surface(Vector2(300,220),Vector2(1200,40))
	pc = _actor(Vector2(80,200),PlayerSource.new())
	await _frames(5)
	_key(KEY_D,true)
	await _frames(ceili(hz*0.2))
	_check(pc.position.x > 100, "real D key travels through player source and shared driver")
	_key(KEY_SPACE,true)
	await _frames(3)
	_check(not pc.grounded and pc.velocity.y < 0, "real Space key requests ordinary jump")
	_key(KEY_D,false); _key(KEY_SPACE,false)
	await _frames(hz)
	_key(KEY_J,true)
	await _frames(ceili(hz*0.1))
	var serial: int = pc.attack_serial
	_check(serial > 0, "real J commits ordinary attack")
	pc.get_node("IntentDriver").enabled = false
	await _frames(ceili(hz*0.7))
	pc.get_node("IntentDriver").enabled = true
	await _frames(ceili(hz*0.2))
	_check(pc.attack_serial == serial, "held attack cannot replay across driver disable/enable")
	pc.reset_actor(Vector2(80,200))
	await _frames(ceili(hz*0.2))
	_check(pc.weapon_phase == &"idle", "held attack cannot replay across actor reset")
	_key(KEY_J,false)
	await _frames(2)
	_key(KEY_J,true)
	await _frames(ceili(hz*0.1))
	_check(pc.weapon_phase != &"idle", "fresh release and press rearms after reset")
	_key(KEY_J,false)
	await _end()

	_begin("source switching, missing source and unique tick ownership")
	_surface(Vector2(300,220),Vector2(1200,40))
	pc = _actor(Vector2(80,200), RawSource.new())
	await _frames(5)
	var driver: Node = pc.get_node("IntentDriver")
	var extra := Driver.new()
	extra.name = "DuplicateDriver"
	pc.add_child(extra)
	await _frames(3)
	_check(extra.tick_count == 0, "second driver cannot acquire same actor")
	var previous_ticks: int = driver.tick_count
	_check(not driver.tick(1.0/hz) and driver.tick_count == previous_ticks, "same physics-frame duplicate tick rejected")
	_check(not driver.tick(NAN) and not driver.tick(-1), "invalid deltas cannot advance simulation")
	pc.get_node("InputSource").raw = {"right":NAN,"left":"bad","jump":false}
	await _frames(3)
	_check(pc.position.is_finite() and pc.velocity.is_finite() and absf(pc.velocity.x) < 0.1, "invalid raw strengths fail neutral")
	var copy: Dictionary = driver.last_frame
	copy.right = 1.0
	_check(driver.last_frame.right == 0, "diagnostic frame is a detached copy")
	pc.get_node("InputSource").queue_free()
	await _frames(3)
	_check(driver.tick_count > previous_ticks, "missing source still advances neutral gravity")
	var replacement := PlayerSource.new()
	replacement.name = "InputSource"
	_key(KEY_J,true)
	pc.add_child(replacement)
	await _frames(ceili(hz*0.2))
	_check(pc.attack_serial == 0, "new source does not inherit held input edge")
	_key(KEY_J,false)
	await _frames(2)
	_key(KEY_J,true)
	await _frames(ceili(hz*0.1))
	_check(pc.attack_serial == 1, "new source accepts fresh ordinary press")
	_key(KEY_J,false)
	await _end()

	_begin("pause and host processing lifecycle")
	_surface(Vector2(300,220),Vector2(1200,40))
	npc = _actor(Vector2(80,200),NPCSource.new(),IntentPolicy.new())
	await _frames(5)
	var lifecycle_driver: Node = npc.get_node("IntentDriver")
	var lifecycle_policy: Node = npc.get_node("PatrolPolicy")
	var original_ticks: int = lifecycle_driver.tick_count
	paused = true
	lifecycle_policy.intent = {"attack":true}
	await _frames(3)
	_check(lifecycle_driver.tick_count == original_ticks, "global pause cannot advance actor scheduler")
	paused = false
	lifecycle_policy.intent = {"attack":true}
	await _frames(ceili(hz*0.1))
	_check(npc.attack_serial == 0, "pause/resume discards held NPC action transition")
	lifecycle_policy.intent = {}
	await _frames(2)
	lifecycle_policy.intent = {"attack":true}
	await _frames(ceili(hz*0.1))
	_check(npc.attack_serial == 1, "fresh NPC intent rearms after pause")
	lifecycle_policy.intent = {}
	await _frames(hz)
	npc.set_physics_process(false)
	await _frames(2)
	original_ticks = lifecycle_driver.tick_count
	lifecycle_policy.intent = {"jump":true}
	await _frames(3)
	_check(lifecycle_driver.tick_count == original_ticks, "disabled host physics blocks its child scheduler")
	npc.set_physics_process(true)
	await _frames(ceili(hz*0.1))
	_check(npc.grounded, "host resume drops queued pre-resume jump")
	lifecycle_policy.intent = {}
	await _frames(2)
	lifecycle_policy.intent = {"jump":true}
	await _frames(2)
	_check(not npc.grounded and npc.velocity.y < 0, "fresh intent works after host resume")
	await _end()

	_begin("source processing lifecycle and queued tap")
	_surface(Vector2(300,220),Vector2(1200,40))
	pc = _actor(Vector2(80,200),RawSource.new())
	await _frames(5)
	var raw_source: Node = pc.get_node("InputSource")
	raw_source.process_mode = Node.PROCESS_MODE_DISABLED
	await _frames(2)
	raw_source.raw = {"attack":true}
	raw_source.process_mode = Node.PROCESS_MODE_INHERIT
	await _frames(ceili(hz*0.1))
	_check(pc.attack_serial == 0, "source reenable discards queued held request")
	raw_source.raw = {}
	await _frames(2)
	raw_source.raw = {"attack":true}
	await _frames(ceili(hz*0.1))
	_check(pc.attack_serial == 1, "fresh source request rearms after release")
	raw_source.raw = {}
	await _frames(hz)
	pc.reset_actor(Vector2(80,200))
	raw_source.raw = {"attack":false,"attack_pressed":true,"attack_released":true}
	await _frames(1)
	_check(pc.weapon_phase == &"idle", "queued full-tap edges cannot bypass reset quarantine")
	raw_source.raw = {}
	await _frames(2)
	raw_source.raw = {"attack":false,"attack_pressed":true,"attack_released":true}
	await _frames(1)
	_check(pc.weapon_phase != &"idle", "fresh raw tap accepted after neutral observation")
	await _end()

	_begin("foreign sources cannot be reset")
	for offset in [Vector2.ZERO, OFFSET]: _surface(Vector2(300,220)+offset,Vector2(900,40))
	await _pair()
	pc.name = "A"; npc.name = "B"
	npc.get_node("PatrolPolicy").intent = {"move":Vector2.RIGHT}
	pc.get_node("IntentDriver").source_path = NodePath("../../B/InputSource")
	await _frames(3)
	_check(not npc.get_node("PatrolPolicy").intent.is_empty() and npc.velocity.x > 0, "foreign source path cannot clear another actor intention")
	var foreign_source := NPCSource.new()
	foreign_source.name = "ForeignSource"
	pc.add_child(foreign_source)
	foreign_source.policy_path = NodePath("../../B/PatrolPolicy")
	foreign_source.reset_intent()
	_check(not npc.get_node("PatrolPolicy").intent.is_empty(), "foreign policy path cannot reset another actor policy")
	_check(foreign_source.sample_raw(pc,1.0/hz).is_empty(), "foreign policy cannot supply raw frame")
	await _end()
	for retirement in ["disable","delete","switch","reset"]:
		_begin("policy retires during sample " + retirement)
		_surface(Vector2(300,220),Vector2(1200,40))
		npc = _actor(Vector2(80,200),NPCSource.new(),RetiringPolicy.new())
		var replacement_policy := IntentPolicy.new()
		replacement_policy.name = "Replacement"
		npc.add_child(replacement_policy)
		await _frames(5)
		npc.get_node("PatrolPolicy").mode = retirement
		await _frames(1)
		_check(absf(npc.velocity.x) < 0.01 and absf(npc.position.x-80) < 0.01, "retired policy frame cannot move actor")
		await _end()

	_begin("same-frame scheduler replacement")
	var replace_floor := _surface(Vector2(300,220),Vector2(1200,40))
	pc = _actor(Vector2(80,200),RawSource.new())
	await _frames(5)
	pc.get_node("IntentDriver").queue_free()
	var new_driver := Driver.new()
	new_driver.name = "ReplacementDriver"
	pc.add_child(new_driver)
	_check(not new_driver.tick(1.0/hz), "replacement cannot double-step old owner physics frame")
	replace_floor.queue_free()
	await _frames(ceili(hz*0.4))
	_check(new_driver.tick_count > 0 and pc.position.y > 220 and not pc.grounded, "fresh replacement owns gravity after queued owner retires")
	await _end()

	_begin("explicit pause gate with always-process host")
	_surface(Vector2(300,220),Vector2(1200,40))
	npc = _actor(Vector2(80,200),NPCSource.new(),IntentPolicy.new())
	npc.process_mode = Node.PROCESS_MODE_ALWAYS
	await _frames(5)
	var pause_driver: Node = npc.get_node("IntentDriver")
	var pause_count: int = pause_driver.tick_count
	paused = true
	npc.get_node("PatrolPolicy").intent = {"attack":true}
	await _frames(3)
	_check(pause_driver.tick_count == pause_count, "always-process configuration still honors global physics pause")
	paused = false
	await _frames(3)
	_check(npc.attack_serial == 0, "always-process resume discards paused request")
	npc.get_node("PatrolPolicy").intent = {}
	await _frames(2)
	npc.get_node("PatrolPolicy").intent = {"attack":true}
	await _frames(2)
	_check(npc.attack_serial == 1, "fresh request works after always-process pause")
	await _end()

	_begin("independent autonomous local sensing")
	_surface(Vector2(140,220),Vector2(280,40))
	npc = _actor(Vector2(140,200), NPCSource.new(), Patrol.new())
	npc.get_node("PatrolPolicy").patrol_radius = 1000
	var min_x := 10000.0
	var max_x := -10000.0
	for i in hz*3:
		await _frames(1)
		min_x = minf(min_x,npc.position.x); max_x = maxf(max_x,npc.position.x)
	_check(max_x-min_x > 100, "autonomous policy produces ordinary movement")
	_check(min_x > 8 and max_x < 272 and npc.grounded, "local terrain observations brake and turn before real edges")
	_check(npc.get_node("NoiseRelay").forwarded_count > 0, "NPC motion produces controller footsteps without manual NPC emission")
	# A real impulse overrides policy neutrality through the common authority.
	npc.receive_hit({"amount":0.0,"impulse":Vector2(650,-60),"stun_seconds":0.7,"hitpause":0.0})
	await _frames(ceili(hz*0.7))
	_check(npc.position.x > 290 and npc.position.y > 220, "autonomous edge policy cannot cancel external motion")
	await _end()

	for direction in [-1,1]:
		_begin("autonomous recovery beyond patrol radius " + str(direction))
		_surface(Vector2(300,220),Vector2(4000,40))
		npc = _actor(Vector2(300,200),NPCSource.new(),Patrol.new())
		npc.get_node("PatrolPolicy").patrol_radius = 90.0
		await _frames(5)
		npc.receive_hit({"amount":0.0,"impulse":Vector2(direction*900,-60),"stun_seconds":0.8,"hitpause":0.0})
		await _frames(hz)
		var displaced_x: float = npc.position.x
		_check((displaced_x-300)*direction > 120, "real impulse moves actor beyond ordinary patrol boundary")
		await _frames(hz)
		_check((npc.position.x-displaced_x)*direction < -40, "local policy requests inward recovery instead of endless turns")
		await _frames(hz*6)
		_check(absf(npc.position.x-300) < 100 and npc.grounded, "same controller returns to patrol interval without teleport")
		await _end()

	_begin("real sight obstruction and reobservation")
	_surface(Vector2(300,220),Vector2(900,40))
	npc = _actor(Vector2(80,200),NPCSource.new(),Patrol.new())
	var target := Node2D.new()
	target.name = "ObservedTarget"; target.position = Vector2(250,200)
	world.add_child(target)
	var policy: Node = npc.get_node("PatrolPolicy")
	policy.target_path = NodePath("../../ObservedTarget")
	policy.move_strength = 0.2
	var wall := _surface(Vector2(170,160),Vector2(16,100))
	await _frames(8)
	_check(not policy.sees_target and policy.state != &"chasing", "real wall blocks sight before any chase decision")
	wall.queue_free()
	await _frames(8)
	_check(policy.sees_target and policy.state == &"chasing", "removed wall yields fresh clear-ray evidence")
	_check(npc.velocity.x > 0, "visible target requests ordinary rightward intent")
	await _end()

	_begin("shared melee composition smoke")
	_surface(Vector2(200,220),Vector2(400,40))
	pc = _actor(Vector2(80,200),RawSource.new())
	npc = _actor(Vector2(110,200),NPCSource.new(),IntentPolicy.new())
	await _frames(5)
	pc.get_node("InputSource").raw = {"attack":true}
	await _frames(ceili(hz*0.3))
	_check(pc.attack_serial == 1, "real raw attack executes near shared peer")
	_check(npc.get_node("Health").current_health == 29 and pc.get_node("ContactAdapter").confirmed_contacts == 1, "actual shared melee reaches existing Health once")
	_check(pc.collision_layer == 32 and npc.collision_layer == 32 and pc.is_in_group("simulation_actors") and not npc.is_in_group("combat_pc"), "generic shared layer and groups are configured equally")
	await _end()
	print("SHARED ACTOR %d Hz: %d checks, %d failures; paired ticks %d; max position error %.6f, velocity error %.6f" % [hz,checks,failures.size(),paired_ticks,position_error,velocity_error])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
