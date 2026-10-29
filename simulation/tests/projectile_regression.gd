extends SceneTree
## All successful shots below start ordinary raw input and hit real Godot bodies.
## Direct calls are explicitly negative/lifecycle probes, never successful shots.
const Actor = preload("res://simulation/actors/shared_ranged_actor.tscn")
const Receiver = preload("res://simulation/components/projectile_receiver.gd")
const Emitter = preload("res://simulation/components/projectile_emitter.gd")
const PlayerSource = preload("res://simulation/components/player_input_source.gd")
const NPCSource = preload("res://simulation/components/npc_input_source.gd")
const Cargo = preload("res://simulation/components/physical_cargo.tscn")
class RawSource extends Node:
	var raw := {}
	func sample_raw(_actor: Node,_dt: float) -> Dictionary: return raw.duplicate(true)
	func reset_intent() -> void: raw.clear()
class Policy extends Node:
	var intent := {}
	func sample_intent(_actor: Node,_dt: float) -> Dictionary: return intent.duplicate(true)
	func reset_intent() -> void: intent.clear()
var hz := 120
var checks := 0
var failures: Array[String] = []
var scenarios: Array[String] = []
var label := ""
var world: Node2D
var left: Node2D
var right: Node2D
var shots: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var noises: Array[Dictionary] = []
var carriers: Array[Node] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()
func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func _until(predicate: Callable, seconds := 2.4) -> bool:
	for i in ceili(hz*seconds):
		await _frames(1)
		if predicate.call(): return true
	return false
func _check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok: failures.append(label+": "+detail)
func _surface(at: Vector2,size: Vector2,layer := 1) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = layer
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	world.add_child(body)
	return body
func _actor(at: Vector2,mode: String,facing := 1) -> Node2D:
	var actor := Actor.instantiate() as Node2D
	actor.position = at
	actor.initial_facing = facing
	var source: Node = PlayerSource.new() if mode == "PC" else (NPCSource.new() if mode == "NPC" else RawSource.new())
	source.name = "InputSource"
	actor.add_child(source)
	actor.set_meta("mode",mode)
	if mode == "NPC":
		var policy := Policy.new()
		policy.name = "PatrolPolicy"
		actor.add_child(policy)
	world.add_child(actor)
	actor.get_node("ProjectileEmitter").projectile_emitted.connect(func(receipt: Dictionary):
		shots.append(receipt.duplicate(true))
		carriers.append(instance_from_id(receipt.carrier_id)))
	actor.get_node("ProjectileReceiver").projectile_resolved.connect(func(receipt: Dictionary): contacts.append(receipt.duplicate(true)))
	actor.noise_committed.connect(func(receipt: Dictionary): noises.append(receipt.duplicate(true)))
	return actor
func _begin(next: String,lm := "RAW",rm := "RAW",distance := 180.0) -> void:
	label = next
	scenarios.append(next)
	shots = []
	contacts = []
	noises = []
	carriers = []
	world = Node2D.new()
	root.add_child(world)
	_surface(Vector2(350,220),Vector2(1800,40))
	left = _actor(Vector2(200,200),lm)
	right = _actor(Vector2(200+distance,200),rm,-1)
	left.get_node("ProjectileAim").target_path = right.get_path()
	right.get_node("ProjectileAim").target_path = left.get_path()
	await _frames(5)
func _key(code: int,value: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = value
	Input.parse_input_event(event)
func _request(actor: Node,buttons: Dictionary) -> void:
	match actor.get_meta("mode"):
		"PC":
			for pair in [["attack",KEY_J],["shield",KEY_K],["roll",KEY_SHIFT],["jump",KEY_SPACE],["left",KEY_A],["right",KEY_D]]: _key(pair[1],buttons.get(pair[0],false)==true)
		"NPC": actor.get_node("PatrolPolicy").intent = buttons.duplicate(true)
		_: actor.get_node("InputSource").raw = buttons.duplicate(true)
func _attack(actor: Node) -> void:
	_request(actor,{"attack":true})
	await _frames(1)
	_request(actor,{})
func _health(actor: Node) -> float: return actor.get_node("Health").current_health
func _emitter(actor: Node) -> Node: return actor.get_node("ProjectileEmitter")
func _end() -> void:
	for key in [KEY_J,KEY_K,KEY_SHIFT,KEY_SPACE,KEY_A,KEY_D]: _key(key,false)
	paused = false
	if is_instance_valid(world): world.queue_free()
	await _frames(3)
	_check(get_nodes_in_group("shared_projectiles").is_empty(),"no orphan carriers after world exit")
func _fire_contact(actor: Node) -> bool:
	await _attack(actor)
	return await _until(func(): return not contacts.is_empty())
func _run() -> void:
	for mode in ["PC","NPC"]:
		await _begin("ordinary "+mode+" shot",mode)
		var start := Engine.get_physics_frames()
		await _attack(left)
		_check(left.weapon_phase == &"windup" and shots.is_empty(),"ordinary input starts warning without release")
		await _frames(floori(hz*0.60))
		_check(shots.is_empty() and _health(right)==30,"no early shot or melee damage")
		_check(await _until(func(): return not contacts.is_empty()),"real swept contact resolves")
		_check(shots.size()==1 and contacts.size()==1 and _health(right)==29,"exact one shot/Health debit")
		_check(not left.get_node("ContactAdapter").enabled,"melee admission disabled")
		_check(float(shots[0].physics_frame-start)/hz >= 0.70,"full authored warning respected")
		_check(contacts[0].amount==1 and contacts[0].outcome==&"hurt","actual Health receipt")
		_check(_emitter(left).profile != _emitter(right).profile and left.melee_chain != right.melee_chain,"per-instance data ownership")
		await _end()
	await _begin("fresh held input emits once","PC")
	_request(left,{"attack":true})
	await _frames(ceili(hz*3.2))
	_check(shots.size()==1,"FRESH_ONLY hold cannot repeat")
	_request(left,{})
	await _frames(2)
	await _attack(left)
	_check(await _until(func(): return shots.size()==2),"fresh repress rearms")
	await _end()
	await _begin("canonical sample negative probes")
	await _attack(left)
	left.strike_sample.emit(left,left.strike_snapshot())
	_check(shots.is_empty(),"out of scope windup sample rejected")
	_check(left.active_action_sample_snapshot().is_empty(),"accessor empty outside real scope")
	var forged := func(actor: Node2D,snapshot: Dictionary):
		var altered := snapshot.duplicate(true)
		altered.damage = 999.0
		_emitter(actor)._on_sample(actor,altered)
	left.strike_sample.disconnect(_emitter(left)._on_sample)
	left.strike_sample.connect(forged)
	left.strike_sample.connect(_emitter(left)._on_sample)
	_check(await _until(func(): return not shots.is_empty()),"genuine sample still releases")
	left.strike_sample.emit(left,left.strike_snapshot())
	_check(shots.size()==1 and shots[0].damage==1,"altered/repeated samples cannot multiply damage or shots")
	await _end()
	await _begin("locked aim from current muzzle")
	await _attack(left)
	var locked: Vector2 = _emitter(left)._pending.aim
	_request(right,{"right":1.0})
	_check(await _until(func(): return not shots.is_empty()),"release after target moves")
	_request(right,{})
	_check(shots[0].aim==locked,"aim remains original world point")
	_check(Vector2(shots[0].velocity).is_equal_approx((locked-Vector2(shots[0].muzzle)).normalized()*245),"release direction uses current muzzle to old aim")
	await _end()
	for obstacle in ["thin wall","cargo","muzzle cargo","door closure"]:
		await _begin(obstacle)
		if obstacle != "door closure": _surface(Vector2(215 if obstacle=="muzzle cargo" else 290,178),Vector2(1 if obstacle=="thin wall" else 18,70),8 if "cargo" in obstacle else 1)
		await _attack(left)
		if obstacle=="door closure":
			await _frames(ceili(hz*0.8))
			_surface(Vector2(300,178),Vector2(1,70))
		await _frames(ceili(hz*1.5))
		_check(_health(right)==30 and contacts.is_empty(),"actual obstruction prevents damage")
		_check(shots.is_empty() if obstacle=="muzzle cargo" else shots.size()==1,"blocked muzzle does not invent release")
		await _end()
	await _begin("absent receiver has no damage fallback")
	right.get_node("ProjectileReceiver").queue_free()
	await _frames(2)
	await _attack(left)
	await _frames(ceili(hz*1.8))
	_check(_health(right)==30 and contacts.is_empty(),"unregistered body only intercepts")
	await _end()
	await _begin("held guard fractional damage")
	_request(right,{"shield":true})
	await _frames(ceili(hz*0.35))
	_check(await _fire_contact(left),"physical held guard contact")
	_check(contacts[0].outcome==&"guarded" and contacts[0].amount==0.25 and _health(right)==29.75,"shared guard/Health math")
	await _end()
	await _begin("real timed reflection and return")
	await _attack(left)
	await _until(func(): return not shots.is_empty())
	await _until(func(): return is_instance_valid(carriers[0]) and carriers[0].position.x>right.position.x-38)
	_request(right,{"shield":true})
	_check(await _until(func(): return contacts.size()>=2),"parry then actual return collider")
	_check(contacts.size()>=2 and contacts[0].outcome==&"parried" and contacts[0].reflection_confirmed,"truthful completed reflection")
	_check(_health(right)==30 and _health(left)==28,"return minimum2 through shared Health")
	_check(contacts.size()>=2 and contacts[1].reflected and contacts[1].amount==2,"one reflected collision receipt")
	await _end()
	for retirement in ["reset","emitter disable","emitter removal","source removal","profile mutation"]:
		await _begin("flying lease "+retirement,dummy_mode(),dummy_mode(),350)
		await _attack(left)
		await _until(func(): return not shots.is_empty())
		match retirement:
			"reset": left.reset_actor(Vector2(200,200),1)
			"emitter disable": _emitter(left).enabled=false
			"emitter removal": _emitter(left).queue_free()
			"source removal": left.queue_free()
			"profile mutation": _emitter(left).profile.speed=246
		await _frames(ceili(hz*1.7))
		_check(_health(right)==30 and get_nodes_in_group("shared_projectiles").is_empty(),"retirement removes owned siblings before hit")
		await _end()
	await _begin("nonlethal source hurt preserves launched shot",dummy_mode(),dummy_mode(),350)
	await _attack(left)
	await _until(func(): return not shots.is_empty())
	# Explicit lifecycle boundary probe, not projectile success fabrication.
	left.receive_attack({"amount":1,"impulse":Vector2.ZERO,"rollable":false})
	_check(await _until(func(): return _health(right)==29),"existing shot survives ordinary nonlethal cancellation")
	await _end()
	await _begin("pre-release hurt cancels pending shot")
	await _attack(left)
	left.receive_attack({"amount":1,"impulse":Vector2.ZERO,"rollable":false})
	await _frames(hz)
	_check(shots.is_empty(),"cancelled warning cannot release")
	await _end()
	await _begin("in-flight global pause freezes")
	await _attack(left)
	await _until(func(): return not shots.is_empty())
	var carrier := carriers[0]
	var position: Vector2 = carrier.position
	paused=true
	await _frames(12)
	_check(carrier.position==position and _health(right)==30,"pause freezes real flight")
	paused=false
	_check(await _until(func(): return _health(right)==29),"resume preserves launched lease")
	await _end()
	await _begin("forged reflection rejected")
	await _attack(left)
	await _until(func(): return not shots.is_empty())
	var result: Dictionary = carriers[0].reflect_from_shield({"defender":right,"reflect_direction":Vector2.LEFT,"reflect_speed":360})
	_check(not result.accepted and not carriers[0].reflected,"direct reflection has no genuine shield scope")
	await _end()
	await _begin("lethal actual contact completes Health fact")
	left.melee_chain.steps[0].damage=45
	_check(await _fire_contact(left),"real lethal collision")
	_check(_health(right)==0 and right.is_defeated() and contacts[0].amount==30,"lethal clamp and Defeat confirmed")
	await _end()
	await _begin("positive sound only on genuine release")
	await _attack(left)
	await _frames(ceili(hz*0.5))
	_check(noises.filter(func(n): return n.kind==&"projectile_warning").size()==1,"one genuine warning")
	_check(noises.filter(func(n): return n.kind in [&"strike",&"projectile_release"]).is_empty(),"no early phase/release sound")
	await _until(func(): return not shots.is_empty())
	_check(noises.filter(func(n): return n.kind==&"projectile_release").size()==1 and noises.filter(func(n): return n.kind==&"strike").is_empty(),"one release committed sound, no inherited melee sound")
	await _end()
	await _begin("ordinary physical roll evasion")
	await _attack(left)
	await _until(func(): return not shots.is_empty())
	await _until(func(): return is_instance_valid(carriers[0]) and carriers[0].position.x>right.position.x-55)
	_request(right,{"roll":true})
	_check(await _until(func(): return not contacts.is_empty()),"real swept collision during roll")
	_check(_health(right)==30 and contacts[0].outcome==&"evaded" and contacts[0].amount==0,"controller owns configured invulnerability")
	await _end()
	await _begin("no-shield capability remains damageable")
	var capabilities = right.get_node("IntentDriver").capabilities.duplicate(true)
	capabilities.can_shield=false
	right.get_node("IntentDriver").configure_capabilities(capabilities)
	_request(right,{"shield":true})
	await _frames(ceili(hz*0.3))
	_check(await _fire_contact(left) and _health(right)==29,"role-independent shield capability")
	await _end()
	await _begin("moving physical cargo intercepts flight")
	await _attack(left)
	await _until(func(): return not shots.is_empty())
	var moving := Cargo.instantiate()
	moving.position=Vector2(300,140)
	moving.linear_velocity=Vector2(0,130)
	world.add_child(moving)
	await _frames(hz)
	_check(_health(right)==30 and contacts.is_empty(),"actual moving rigid cargo blocks outgoing shot")
	await _end()
	await _begin("reflected cargo interception")
	await _attack(left)
	await _until(func(): return not shots.is_empty())
	await _until(func(): return is_instance_valid(carriers[0]) and carriers[0].position.x>right.position.x-38)
	_request(right,{"shield":true})
	await _until(func(): return not contacts.is_empty())
	_surface(Vector2(280,178),Vector2(18,60),8)
	await _frames(hz)
	_check(_health(left)==30 and _health(right)==30 and contacts.size()==1,"cargo blocks genuine reflected return")
	await _end()
	await _begin("return can hit another registered actor")
	await _attack(left)
	await _until(func(): return not shots.is_empty())
	await _until(func(): return is_instance_valid(carriers[0]) and carriers[0].position.x>right.position.x-38)
	_request(right,{"shield":true})
	await _until(func(): return not contacts.is_empty())
	var third := _actor(Vector2(285,200),"RAW")
	_check(await _until(func(): return _health(third)==28),"new eligible physical collider receives returned shot")
	_check(_health(left)==30 and contacts.size()==2,"no owner-only immunity or repeated return")
	await _end()
	await _begin("canonical twelve damage preserved on return")
	left.melee_chain.steps[0].damage=12
	await _attack(left)
	await _until(func(): return not shots.is_empty())
	await _until(func(): return is_instance_valid(carriers[0]) and carriers[0].position.x>right.position.x-38)
	_request(right,{"shield":true})
	_check(await _until(func(): return contacts.size()==2),"twelve-damage reflection physically returns")
	_check(_health(left)==18 and contacts[1].amount==12,"return uses max shot damage/minimum, never clamps twelve to two")
	await _end()
	await _begin("lethal reflected source retirement preserves receipt")
	left.melee_chain.steps[0].damage=40
	await _attack(left)
	await _until(func(): return not shots.is_empty())
	await _until(func(): return is_instance_valid(carriers[0]) and carriers[0].position.x>right.position.x-38)
	_request(right,{"shield":true})
	_check(await _until(func(): return contacts.size()==2),"lethal return completed fact remains observable")
	_check(_health(left)==0 and left.is_defeated() and contacts[1].accepted and contacts[1].amount==30,"source defeat/shot retirement cannot erase applied Health receipt")
	await _end()
	for change in ["receiver disabled","receiver replacement","body disabled","body moved"]:
		await _begin("inflight target "+change)
		await _attack(left)
		await _until(func(): return not shots.is_empty())
		match change:
			"receiver disabled": right.get_node("ProjectileReceiver").enabled=false
			"receiver replacement":
				var old := right.get_node("ProjectileReceiver")
				old.unbind()
				old.queue_free()
				var replacement := Receiver.new()
				replacement.name="ReplacementProjectileReceiver"
				right.add_child(replacement)
			"body disabled": right.get_node("BodyShape").disabled=true
			"body moved": right.get_node("BodyShape").position.y-=100
		await _frames(ceili(hz*1.6))
		_check(_health(right)==(29 if change=="receiver replacement" else 30),"fresh receiver may admit future real contact; retired/absent body cannot")
		await _end()
	for change in ["emitter rebound","emitter replaced","profile replaced","attack configuration replaced"]:
		await _begin("pending action "+change)
		await _attack(left)
		match change:
			"emitter rebound":
				_emitter(left).unbind()
				_emitter(left).bind(left)
			"emitter replaced":
				var old := _emitter(left)
				old.unbind()
				old.queue_free()
				var replacement := Emitter.new()
				replacement.name="ReplacementEmitter"
				left.add_child(replacement)
			"profile replaced": _emitter(left).profile=_emitter(left).profile.duplicate(true)
			"attack configuration replaced": left.melee_chain=left.melee_chain.duplicate(true)
		await _frames(hz)
		_check(shots.is_empty(),"old start/sample cannot be inherited after replacement")
		await _end()
	await _begin("source expiry and ordinary recovery","RAW","RAW",900)
	await _attack(left)
	await _until(func(): return not shots.is_empty())
	await _frames(ceili(hz*1.2))
	_check(left.weapon_phase==&"idle" and not get_nodes_in_group("shared_projectiles").is_empty(),"flight outlives ordinary action recovery")
	await _frames(ceili(hz*1.2))
	_check(get_nodes_in_group("shared_projectiles").is_empty() and _health(right)==30,"authored lifetime expires shot without hit")
	await _end()
	var report := {"hz":hz,"checks":checks,"scenarios":scenarios,"failures":failures,"successes_require":"ordinary raw input and real Godot swept collisions"}
	var file := FileAccess.open("res://simulation/evidence/projectile_%d.json"%hz,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("PROJECTILE: %d scenarios / %d checks / %d failures"%[scenarios.size(),checks,failures.size()])
	for failure in failures: printerr("FAIL "+failure)
	quit(0 if failures.is_empty() else 1)
func dummy_mode() -> String: return "RAW"
