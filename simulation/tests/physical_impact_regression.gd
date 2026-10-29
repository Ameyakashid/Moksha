extends SceneTree
const PC = preload("res://simulation/actors/impact_player.tscn")
const NPC = preload("res://simulation/actors/impact_npc.tscn")
const Cargo = preload("res://simulation/components/physical_cargo.tscn")
const Receiver = preload("res://simulation/components/physical_impact_receiver.gd")
var world: Node2D
var actor: Node2D
var cargo: RigidBody2D
var receiver: Node
var health: Node
var checks := 0
var failures: Array[String] = []
var hz := 120
var receipts: Array[Dictionary] = []
var label := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()
func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func _until(predicate: Callable, seconds := 1.5) -> bool:
	for i in ceili(hz * seconds):
		await _frames(1)
		if predicate.call(): return true
	return false
func _check(value: bool, detail: String) -> void:
	checks += 1
	if not value: failures.append(label + ": " + detail)
func _surface(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	body.add_child(shape)
	world.add_child(body)
	return body
func _begin(kind: String, test_label: String, callback_npc := false) -> void:
	label = kind + " / " + test_label
	receipts = []
	world = Node2D.new()
	root.add_child(world)
	_surface(Vector2(300, 220), Vector2(1000, 40))
	actor = (PC if kind == "PC" else NPC).instantiate()
	if callback_npc: actor.set_script(preload("res://simulation/tests/impact_callback_npc.gd"))
	actor.position = Vector2(220,200)
	if kind == "NPC":
		actor.ai_enabled = false
		actor.max_health = 30.0
	else: actor.initial_facing = -1
	world.add_child(actor)
	receiver = actor.get_node("PhysicalImpactReceiver")
	health = actor.get_node("Health" if kind == "PC" else "StrikeHealth/Health")
	receiver.impact_resolved.connect(func(receipt: Dictionary): receipts.append(receipt.duplicate(true)))
	await _frames(5)
	_check(receiver.capture_generation() >= 0, "receiver binds actual host health")
func _spawn(at: Vector2, velocity := Vector2.ZERO, intercept := false, query_probe := false) -> void:
	cargo = Cargo.instantiate()
	if intercept: cargo.set_script(preload("res://simulation/tests/impact_intercept_cargo.gd"))
	if query_probe: cargo.set_script(preload("res://simulation/tests/impact_query_cargo.gd"))
	cargo.position = at
	cargo.tuning = cargo.tuning.duplicate(true)
	cargo.tuning.hard_impacts_to_break = 100
	cargo.tuning.body_gravity_scale = 0.0 if not velocity.is_zero_approx() else 1.0
	cargo.linear_velocity = velocity
	world.add_child(cargo)
func _finish() -> void:
	world.queue_free()
	await _frames(3)
func _key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
func _run() -> void:
	for kind in ["PC", "NPC"]:
		await _begin(kind, "actual side contact")
		_spawn(Vector2(100,180), Vector2(260,0))
		_check(await _until(func(): return not receipts.is_empty()), "rigid solver contact reaches shared receiver")
		if not receipts.is_empty():
			_check(receipts[0].accepted and receipts[0].outcome == &"hurt", "same unguarded outcome")
			_check(is_equal_approx(health.current_health,27.0), "same three damage exactly once")
			_check(receipts[0].normal_speed >= 80.0 and receipts[0].contact_position.x > 200, "actual contact evidence retained")
			_check(actor.velocity.x > 0.0, "motion owner receives real directional response")
		await _frames(hz)
		_check(receipts.size() == 1 and health.current_health == 27.0, "rest/bounce cannot repeat source epoch")
		await _finish()
		await _begin(kind, "passive gravity contact")
		_spawn(Vector2(220,65))
		_check(await _until(func(): return not receipts.is_empty()), "unlaunched falling cargo makes actual contact")
		_check(cargo.impact_epoch == 1 and health.current_health == 27.0, "passive epoch one applies same damage")
		await _finish()
		await _begin(kind, "disabled capability")
		receiver.enabled = false
		_spawn(Vector2(100,180),Vector2(260,0))
		await _frames(hz)
		_check(receipts.is_empty() and health.current_health == 30.0, "disabled receiver rejects real contacts")
		await _finish()
	await _begin("PC", "raw held guard")
	_key(KEY_K,true)
	await _frames(ceili(hz*0.3))
	_check(actor.shield_phase == &"hold", "raw K enters held guard")
	_spawn(Vector2(100,180), Vector2(260,0))
	_check(await _until(func(): return not receipts.is_empty()), "actual cargo reaches shield host")
	if not receipts.is_empty():
		_check(receipts[0].outcome == &"guarded" and is_equal_approx(health.current_health,29.25), "stock guard keeps 75 percent absorption")
	_key(KEY_K,false)
	await _finish()
	await _additional_cases()
	await _identity_and_input_cases()
	await _relative_motion_case()
	await _extension_and_mask_cases()
	await _configuration_cases()
	await _terminal_health_callback_case()
	print("SHARED PHYSICAL IMPACT %d Hz: %d checks, %d failures" % [hz,checks,failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _additional_cases() -> void:
	for kind in ["PC", "NPC"]:
		await _begin(kind, "rotation only actual contact")
		_spawn(Vector2(194,180))
		cargo.gravity_scale = 0.0
		cargo.angular_velocity = 25.0
		_check(await _until(func(): return not receipts.is_empty(), 0.6), "rotating corner admits actual contact without initial COM motion")
		if not receipts.is_empty():
			_check(receipts[0].source_contact_velocity.length() > 80.0, "angular contact point velocity retained")
		await _finish()
		await _begin(kind, "wall obstruction")
		_surface(Vector2(165,160),Vector2(12,80))
		_spawn(Vector2(100,180),Vector2(260,0))
		await _frames(hz)
		_check(health.current_health == 30.0 and receipts.is_empty(), "real wall prevents cargo touching host")
		await _finish()
		await _begin(kind, "slow resting contact")
		_spawn(Vector2(192,180),Vector2(10,0))
		await _frames(hz)
		_check(health.current_health == 30.0 and receipts.is_empty(), "subthreshold physical touch stays harmless")
		await _finish()
		await _begin(kind, "lethal contact")
		_spawn(Vector2(100,180),Vector2(260,0))
		cargo.impact_profile.damage = 40.0
		_check(await _until(func(): return health.current_health == 0.0), "actual cargo depletes the existing health store")
		_check(receiver.capture_generation() == -1, "dead/depleted host rejects future impacts")
		_check(actor.is_defeated() if kind == "PC" else actor.dead, "existing defeat policy owns terminal state")
		_check(receipts.size() == 1 and receipts[0].accepted and receipts[0].amount == 30.0 and cargo.resolved_contacts == 1, "completed lethal debit reports equally through both host adapters")
		await _finish()
		for action in ["receiver_disable", "receiver_toggle", "receiver_unbind", "host_reset", "source_disable", "source_toggle", "source_launch", "source_free", "pause_cycle", "receiver_replace", "foreign_world"]:
			await _begin(kind, "captured-contact boundary / " + action)
			_spawn(Vector2(100,180),Vector2(260,0),true)
			var interrupted: Array[bool] = []
			cargo.before_delivery = func(_target_ref, _receiver_ref, _packet):
				if not interrupted.is_empty(): return
				interrupted.append(true)
				match action:
					"receiver_disable": receiver.enabled = false
					"receiver_toggle":
						receiver.enabled = false
						receiver.enabled = true
					"receiver_unbind": receiver.unbind()
					"host_reset":
						if kind == "PC": actor.reset_actor(actor.position,-1)
						else: actor.reset_at(actor.position)
					"source_disable": cargo.set_impact_simulation_enabled(false)
					"source_toggle":
						cargo.set_impact_simulation_enabled(false)
						cargo.set_impact_simulation_enabled(true)
					"source_launch": cargo.launch(-1)
					"source_free": cargo.queue_free()
					"pause_cycle":
						paused = true
						paused = false
					"receiver_replace":
						receiver.unbind()
						var replacement := Receiver.new()
						replacement.response = receiver.response
						replacement.health_path = receiver.health_path
						replacement.provider_path = receiver.provider_path
						replacement.required_host_flag = receiver.required_host_flag
						actor.add_child(replacement)
					"foreign_world":
						var viewport := SubViewport.new()
						viewport.world_2d = World2D.new()
						world.add_child(viewport)
						cargo.reparent(viewport)
			_check(await _until(func(): return not interrupted.is_empty()), "real contact reached deferred delivery boundary")
			await _frames(4)
			_check(health.current_health == 30.0 and receipts.is_empty(), "interrupted contact cannot damage a new lifecycle")
			await _finish()
	# Active source scope is not itself proof of physical capture. A distant
	# source cannot fabricate a packet or use the inherited compatibility API.
	await _begin("NPC", "fabricated and legacy API rejection")
	_spawn(Vector2(600,180))
	cargo.gravity_scale = 0.0
	var fabricated := {"source": cargo, "epoch": 1, "packet_id": 999, "target_generation": receiver.capture_generation(),
		"receiver_binding": receiver._binding, "lifecycle": cargo._lifecycle, "physics_frame": Engine.get_physics_frames(),
		"origin": cargo.position, "contact_position": actor.position + Vector2(8,-20), "incoming_velocity": Vector2(-200,0),
		"source_contact_velocity": Vector2(-200,0), "target_contact_velocity": Vector2.ZERO,
		"normal": Vector2.RIGHT, "impulse": Vector2(-180,-80), "normal_speed": 200.0, "amount": 3.0,
		"stun_seconds": 0.42, "hitpause": 0.0, "blockable": true, "parryable": true, "rollable": true}
	cargo._deliver(weakref(actor),weakref(receiver),fabricated)
	_check(health.current_health == 30.0 and actor.stun_left == 0.0, "uncaptured source packet has no authority")
	receiver.enabled = false
	cargo.impact_enemy(actor)
	_check(health.current_health == 30.0 and cargo.alive, "retired legacy take_hit entry cannot bypass capability")
	await _finish()
	await _begin("NPC", "motion callback resets host",true)
	actor.after_impulse = func(): actor.reset_at(actor.position)
	_spawn(Vector2(100,180),Vector2(260,0))
	_check(await _until(func(): return cargo.captured_contacts > 0), "actual contact initiates callback probe")
	await _frames(4)
	_check(health.current_health == 30.0 and receipts.is_empty(), "generation fence prevents damage after motion resets host")
	await _finish()
	for kind in ["PC", "NPC"]:
		await _begin(kind, "health callback resets host")
		var reset_count: Array[bool] = []
		health.health_changed.connect(func(current, _maximum):
			if current < 30.0 and reset_count.is_empty():
				reset_count.append(true)
				if kind == "PC": actor.reset_actor(actor.position,-1)
				else: actor.reset_at(actor.position))
		_spawn(Vector2(100,180),Vector2(260,0))
		_check(await _until(func(): return not reset_count.is_empty()), "real damage triggers reset listener")
		_check(health.current_health == 30.0 and receipts.is_empty() and cargo.last_impact.is_empty(), "no old receipt or damage leaks into reset host")
		await _finish()
	await _begin("NPC", "source callback rearm")
	_spawn(Vector2(100,180),Vector2(260,0))
	receiver.impact_resolved.connect(func(_receipt): cargo.launch(-1))
	_check(await _until(func(): return health.current_health < 30.0), "first epoch contact applies")
	_check(cargo.impact_epoch == 2 and cargo.last_impact.is_empty(), "new launch retires old source feedback")
	await _finish()
	await _begin("NPC", "receipt immutability and duplicate scope")
	_spawn(Vector2(100,180),Vector2(260,0))
	var immutable: Array[bool] = []
	var nested: Array[Dictionary] = []
	receiver.impact_resolved.connect(func(receipt):
		immutable.append(receipt.is_read_only())
		nested.append(receiver.receive_physical_impact(cargo._delivery_scope.packet)))
	_check(await _until(func(): return not receipts.is_empty()), "physical contact reaches receipt observer")
	_check(immutable == [true] and nested[0].reason == &"reentrant" and health.current_health == 27.0, "signal immutable and nested delivery cannot duplicate damage")
	var copy: Dictionary = receiver.last_receipt
	copy.amount = 900
	_check(receiver.last_receipt.amount == 3.0, "diagnostic copy cannot mutate history")
	await _finish()
	# Actual parry via a raw key near a physically approaching crate.
	await _begin("PC", "raw timed parry")
	_spawn(Vector2(100,184),Vector2(260,0))
	await _until(func(): return cargo.position.x >= 175.0)
	_key(KEY_K,true)
	_check(await _until(func(): return not receipts.is_empty()), "incoming crate reaches timed shield")
	_check(not receipts.is_empty() and receipts[0].outcome == &"parried" and health.current_health == 30.0, "stock parry negates health damage")
	_check(actor.get_node("ShieldContactAdapter").confirmed_reflections == 0, "unimplemented reflection is never advertised")
	_key(KEY_K,false)
	await _finish()

func _identity_and_input_cases() -> void:
	for kind in ["PC", "NPC"]:
		await _begin(kind, "second production launch rearms once")
		_spawn(Vector2(100,184),Vector2(260,0))
		cargo.tuning.launch_lift = 0.0
		cargo.tuning.launch_spin_range = Vector2.ZERO
		_check(await _until(func(): return health.current_health == 27.0), "first real contact debits epoch one")
		await _frames(ceili(hz * 0.55))
		var epoch: int = cargo.impact_epoch
		cargo.launch(1, NAN)
		_check(cargo.impact_epoch == epoch, "invalid launch cannot rearm")
		cargo.launch(1)
		_check(cargo.impact_epoch == epoch + 1, "successful launch advances source identity")
		_check(await _until(func(): return health.current_health == 24.0), "second real approach can affect same receiver once")
		await _frames(ceili(hz * 0.4))
		_check(receipts.size() == 2 and health.current_health == 24.0, "two launch epochs produce exactly two admissions")
		await _finish()
	await _begin("NPC", "raw PC strike launches actual cargo")
	actor.reset_at(Vector2(230,200))
	var launcher = PC.instantiate()
	launcher.position = Vector2(100,200)
	world.add_child(launcher)
	_spawn(Vector2(136,183))
	# This is a contact-admission fixture, not a test that every randomized
	# launch angle must hit. Keep the raw-input trajectory deterministic.
	cargo.tuning.launch_lift = 0.0
	cargo.tuning.launch_spin_range = Vector2.ZERO
	await _frames(5)
	_key(KEY_J,true)
	await _frames(2)
	_key(KEY_J,false)
	_check(await _until(func(): return cargo.impact_epoch > 1), "raw J strike goes through production ContactAdapter to launch")
	_check(await _until(func(): return health.current_health < 30.0), "launched cargo reaches actual NPC collider")
	_check(health.current_health == 27.0 and receipts.size() == 1, "raw-input path uses shared receiver once")
	await _finish()
	# Malformed/edited copies cannot consume the legitimate pending capture.
	await _begin("NPC", "mutated capture rejected before genuine delivery")
	_spawn(Vector2(100,180),Vector2(260,0),true)
	var probes: Array[bool] = []
	cargo.before_delivery = func(target_ref, receiver_ref, packet):
		if not probes.is_empty(): return
		probes.append(true)
		var forged: Dictionary = packet.duplicate()
		forged.amount = 900.0
		cargo._deliver(target_ref,receiver_ref,forged)
		_check(health.current_health == 30.0, "changed packet cannot consume pending authority")
	_check(await _until(func(): return health.current_health == 27.0), "unmodified captured packet remains eligible")
	_check(receipts.size() == 1, "malformed attempt does not consume valid later contact")
	await _finish()
	# This is an explicit API-history boundary test after genuine physical
	# admission, not a fabricated gameplay contact. Source-query fixture grants
	# scope solely to test the receiver's independent replay barrier.
	await _begin("NPC", "receiver replacement retained replay barrier")
	_spawn(Vector2(100,180),Vector2(260,0),true)
	var captured: Array[Dictionary] = []
	cargo.before_delivery = func(_t,_r,packet): captured.append(packet)
	_check(await _until(func(): return health.current_health == 27.0), "actual contact establishes receiver history")
	var retained_history: Variant = actor.get_meta(Receiver.HISTORY)
	receiver.unbind()
	var replacement := Receiver.new()
	replacement.response = 1
	replacement.health_path = NodePath("../StrikeHealth/Health")
	replacement.provider_path = NodePath("../StrikeHealth")
	replacement.required_host_flag = &"enabled"
	actor.add_child(replacement)
	_check(replacement._history == retained_history and replacement._history.sources.size() == 1, "replacement retains weak consumed source epoch")
	actor.reset_at(actor.position)
	_check(replacement._history.sources.size() == 1 and replacement._history.sources[0].epoch == cargo.impact_epoch, "actor reset does not erase module replay barrier")
	var stale: Dictionary = captured[0].duplicate()
	stale.receiver_binding = replacement._binding
	stale.target_generation = replacement.capture_generation()
	var result: Dictionary = replacement.receive_physical_impact(stale)
	_check(not result.accepted and health.current_health == 30.0, "stale packet has no source scope after replacement/reset")
	await _finish()

func _relative_motion_case() -> void:
	await _begin("PC", "actual target-relative closing speed")
	_key(KEY_D,true)
	await _frames(ceili(hz*0.5))
	var speed: float = actor.velocity.x
	_spawn(Vector2(actor.position.x-25,180),Vector2(speed+40.0,0))
	cargo.linear_damp = 0.0
	var contacts: Array[int] = []
	cargo.body_entered.connect(func(body):
		if body == actor: contacts.append(body.get_instance_id()))
	_check(await _until(func(): return not contacts.is_empty(),0.7), "moving PC and cargo actually collide")
	_check(health.current_health == 30.0 and receipts.is_empty(), "high absolute cargo speed with low relative normal speed does not hurt")
	_key(KEY_D,false)
	await _finish()

func _extension_and_mask_cases() -> void:
	for kind in ["PC", "NPC"]:
		await _begin(kind, "off-mask real motion")
		_spawn(Vector2(100,180),Vector2(260,0))
		cargo.collision_mask = 1
		actor.collision_mask &= ~8
		await _frames(hz)
		_check(health.current_health == 30.0 and receipts.is_empty(), "excluded collision layers cannot generate gameplay contact")
		await _finish()
		await _begin(kind, "extension query reentrancy")
		_spawn(Vector2(100,180),Vector2(260,0),false,true)
		var nested: Array[Dictionary] = []
		cargo.before_query = func(packet,_target,count):
			if count == 1: nested.append(receiver.receive_physical_impact(packet))
		_check(await _until(func(): return health.current_health == 27.0), "outer real contact remains accepted")
		_check(nested.size() == 1 and nested[0].reason == &"reentrant" and receipts.size() == 1, "source confirmation cannot recursively enter receiver")
		await _finish()
		await _begin(kind, "extension final query resets host")
		_spawn(Vector2(100,180),Vector2(260,0),false,true)
		var reset_count: Array[bool] = []
		cargo.before_query = func(_packet,_target,count):
			if count == (2 if kind == "PC" else 3):
				reset_count.append(true)
				if kind == "PC": actor.reset_actor(actor.position,-1)
				else: actor.reset_at(actor.position)
		_check(await _until(func(): return not reset_count.is_empty()), "final source-query callback executed")
		_check(health.current_health == 30.0 and receipts.is_empty() and cargo.last_impact.is_empty(), "post-query recheck blocks old receipt in reset generation")
		await _finish()
	await _begin("NPC", "invalid fields and registration boundary")
	var resource := Resource.new()
	actor.set_meta(Receiver.REGISTRATION,weakref(resource))
	_check(Receiver.registered(actor) == null, "non-node weak registration rejected safely")
	actor.set_meta(Receiver.REGISTRATION,weakref(receiver))
	_spawn(Vector2(100,180),Vector2(260,0),true)
	var results: Array[Dictionary] = []
	cargo.before_delivery = func(_target_ref,_receiver_ref,packet):
		var incomplete: Dictionary = packet.duplicate()
		incomplete.erase("physics_frame")
		results.append(receiver.receive_physical_impact(incomplete))
		_check(health.current_health == 30.0, "missing identity rejected before health side effect")
	_check(await _until(func(): return health.current_health == 27.0), "complete actual contact follows malformed packet")
	_check(results.size() == 1 and results[0].reason == &"invalid_identity", "missing frame rejects safely")
	await _finish()

func _configuration_cases() -> void:
	for kind in ["PC", "NPC"]:
		for mode in ["disabled_profile", "invalid_profile", "no_receiver", "paused_host", "queued_host"]:
			await _begin(kind,"configuration / " + mode)
			_spawn(Vector2(100,180),Vector2(260,0))
			match mode:
				"disabled_profile": cargo.impact_profile.enabled = false
				"invalid_profile": cargo.impact_profile.minimum_normal_speed = NAN
				"no_receiver": receiver.unbind()
				"paused_host": actor.process_mode = Node.PROCESS_MODE_DISABLED
				"queued_host":
					health.health_changed.connect(func(current,_maximum):
						if current < 30.0: actor.queue_free())
			if mode == "queued_host":
				_check(await _until(func(): return not is_instance_valid(actor)), "actual damage may queue host removal safely")
				_check(cargo.last_impact.is_empty(), "queued host suppresses stale follow-on feedback")
			else:
				await _frames(hz)
				_check(health.current_health == 30.0 and receipts.is_empty(), "configuration rejects damage without changing the world")
			await _finish()
	await _begin("PC", "guard disabled by source capability")
	_key(KEY_K,true)
	await _frames(ceili(hz*0.3))
	_spawn(Vector2(100,184),Vector2(260,0))
	cargo.impact_profile.blockable = false
	_check(await _until(func(): return not receipts.is_empty()), "unblockable actual cargo still resolves")
	_check(health.current_health == 27.0 and receipts[0].outcome == &"hurt", "blockable flag controls actual defense eligibility")
	_key(KEY_K,false)
	await _finish()
	for kind in ["PC", "NPC"]:
		await _begin(kind,"configured hitpause response")
		_spawn(Vector2(100,180),Vector2(260,0))
		cargo.impact_profile.hitpause_seconds = 0.08
		_check(await _until(func(): return not receipts.is_empty()),"configured pause follows actual contact")
		_check((actor.hitpause_remaining if kind == "PC" else actor.pause_left) > 0.0,"configured host pause API applied")
		await _finish()
	var first = Cargo.instantiate()
	var second = Cargo.instantiate()
	first.impact_profile.damage = 17.0
	_check(second.impact_profile.damage == 3.0,"cargo scene profile is instance-local")
	first.free()
	second.free()

func _terminal_health_callback_case() -> void:
	await _begin("NPC","terminal query restores scalar health")
	_spawn(Vector2(100,180),Vector2(260,0),false,true)
	cargo.impact_profile.damage = 40.0
	var restored: Array[bool] = []
	cargo.before_query = func(_packet,_target,count):
		if count == 3:
			restored.append(true)
			health.reset_to_full()
	_check(await _until(func(): return not restored.is_empty()),"terminal extension query executes after lethal scalar receipt")
	_check(health.current_health == 30.0 and receipts.is_empty() and cargo.last_impact.is_empty(),"terminal health witness rechecked after source callback")
	await _finish()
