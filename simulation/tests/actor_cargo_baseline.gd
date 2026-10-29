extends SceneTree
## Prechange observational fixture. Only initial placement/material/velocity and
## labelled lifecycle callbacks are assigned; contacts/motion/launch are real.
const ACTOR = preload("res://simulation/actors/shared_actor.tscn")
const NPC = preload("res://simulation/components/npc_input_source.gd")
const CONTACT = preload("res://simulation/resources/actor_contact_profile.gd")
const CARGO = preload("res://scenes/props/crate.tscn")
const MISSION_CARGO = preload("res://demo/components/mission_prop.gd")
class RawSource extends Node:
	var raw := {}
	func sample_raw(_actor: Node, _dt: float) -> Dictionary: return raw.duplicate(true)
	func reset_intent() -> void: raw.clear()
class IntentPolicy extends Node:
	var intent := {}
	func sample_intent(_actor: Node, _dt: float) -> Dictionary: return intent.duplicate(true)
	func reset_intent() -> void: intent.clear()
var hz := 120
var world: Node2D
var actor: Node2D
var cargo: RigidBody2D
var records: Array[Dictionary] = []
var failures: Array[String] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func begin() -> void:
	world = Node2D.new(); root.add_child(world)
func finish() -> void:
	world.queue_free(); paused = false; await frames(3)
func surface(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new(); body.position = at
	var shape := CollisionShape2D.new(); var box := RectangleShape2D.new(); box.size = size
	shape.shape = box; body.add_child(shape); world.add_child(body)
	return body
func make_actor(role: String, at: Vector2, mask := 9) -> Node2D:
	var result := ACTOR.instantiate()
	result.set_script(preload("res://simulation/tests/actor_cargo_transport_probe.gd"))
	result.automatic_physics = false # Script replacement restores script defaults.
	result.position = at
	var config := CONTACT.new()
	config.body_layer = 2 if role == "PC" else 32
	config.body_mask = mask; config.terrain_mask = mask
	config.hurtbox_layer = 64 if role == "PC" else 4
	config.strike_target_mask = 12 if role == "PC" else 64
	result.get_node("ContactConfig").profile = config
	var source: Node = RawSource.new() if role == "PC" else NPC.new()
	source.name = "InputSource"; result.add_child(source)
	if role == "NPC":
		var policy := IntentPolicy.new(); policy.name = "PatrolPolicy"; result.add_child(policy)
	world.add_child(result)
	return result
func intent(role: String, move := Vector2.ZERO, attack := false) -> void:
	if role == "PC": actor.get_node("InputSource").raw = {"right":maxf(0,move.x),"left":maxf(0,-move.x),"attack":attack}
	else: actor.get_node("PatrolPolicy").intent = {"move":move,"attack":attack}
func make_cargo(at: Vector2, size := Vector2(28,28), velocity := Vector2.ZERO, spin := 0.0, friction := 0.7) -> RigidBody2D:
	var box := CARGO.instantiate(); box.set_script(MISSION_CARGO); box.collision_mask = 43
	box.position = at; box.linear_velocity = velocity; box.angular_velocity = spin
	box.tuning = box.tuning.duplicate(true); box.tuning.hard_impacts_to_break = 1000; box.tuning.friction = friction
	box.get_node("CollisionShape2D").shape = box.get_node("CollisionShape2D").shape.duplicate(true)
	box.get_node("CollisionShape2D").shape.size = size
	world.add_child(box)
	return box
func snapshot() -> Dictionary:
	return {"actor_position":actor.position,"actor_velocity":actor.velocity,"grounded":actor.grounded,
		"support_is_cargo":actor._support == cargo,"support_displacement":actor._support_displacement,
		"cargo_position":cargo.position,"cargo_velocity":cargo.linear_velocity,"cargo_spin":cargo.angular_velocity,
		"cargo_rotation":cargo.rotation,"cargo_frozen":cargo.freeze,"launches":cargo.hit_count,"charge":cargo.charge}
func support(role: String, mask: int) -> void:
	begin(); surface(Vector2(300,220),Vector2(800,40))
	cargo = make_cargo(Vector2(200,186)); actor = make_actor(role,Vector2(200,105),mask)
	await frames(hz*2)
	records.append({"scenario":"standing","role":role,"mask":mask,"observed":snapshot()})
	await finish()
func push(role: String) -> void:
	begin(); surface(Vector2(400,220),Vector2(1200,40))
	cargo = make_cargo(Vector2(180,186)); actor = make_actor(role,Vector2(120,200))
	await frames(12); var start := cargo.position; intent(role,Vector2.RIGHT)
	var min_gap := INF; var max_speed := 0.0
	for i in hz:
		await frames(1); min_gap = minf(min_gap,cargo.position.x-actor.position.x); max_speed = maxf(max_speed,cargo.linear_velocity.length())
	records.append({"scenario":"sidewalk","role":role,"cargo_displacement":cargo.position-start,"minimum_center_gap":min_gap,"maximum_cargo_speed":max_speed,"observed":snapshot()})
	await finish()
func moving_support(role: String, rotation := false) -> void:
	begin(); surface(Vector2(400,420 if rotation else 220),Vector2(1200,40))
	if not rotation: surface(Vector2(285,125),Vector2(20,90)) # Cargo fits beneath; actor does not.
	else: surface(Vector2(150,220),Vector2(8,40)) # A genuine narrow physical fulcrum.
	cargo = make_cargo(Vector2(150,186),Vector2(100,28),Vector2.ZERO if rotation else Vector2(95,0),0.25 if rotation else 0.0,0.0)
	actor = make_actor(role,Vector2(175 if rotation else 150,172 if rotation else 150))
	var trace: Array[Dictionary] = []; var mismatch := 0.0; var supported := 0; var max_spin := 0.0
	var rotating_supported := 0; var anchor_drift := 0.0
	for i in hz*3:
		var prior := actor.position
		var prior_transform := cargo.global_transform
		var prior_anchor: Vector2 = actor._floor_contact_local
		var prior_support: bool = actor._support == cargo
		await frames(1)
		var actual: Vector2 = actor.position-prior
		if actor._support == cargo:
			supported += 1
			mismatch = maxf(mismatch,absf(actor._support_displacement.x-actual.x))
			if absf(cargo.angular_velocity) > 0.05: rotating_supported += 1
			if prior_support:
				var anchor_shift: Vector2 = cargo.global_transform * prior_anchor - prior_transform * prior_anchor
				anchor_drift += absf(anchor_shift.x-actual.x)
		max_spin = maxf(max_spin,absf(cargo.angular_velocity))
		if i % maxi(1,hz/20) == 0: trace.append(snapshot())
	var isolated := {"samples":actor.transport_samples.size(),"rotating_samples":0,"maximum_lost_anchor_x":0.0,"maximum_reported_x_error":0.0}
	for sample in actor.transport_samples:
		isolated.maximum_reported_x_error = maxf(isolated.maximum_reported_x_error,absf(sample.recorded_x-sample.actual_x))
		if absf(sample.rotation_delta) > 0.0001 and sample.continuous_support:
			isolated.rotating_samples += 1
			isolated.maximum_lost_anchor_x = maxf(isolated.maximum_lost_anchor_x,absf(sample.expected_anchor_x-sample.actual_x))
	records.append({"scenario":"rotating_support" if rotation else "blocked_support","role":role,"supported_ticks":supported,"rotating_supported_ticks":rotating_supported,"accumulated_anchor_x_drift":anchor_drift,"maximum_transport_x_mismatch":mismatch,"maximum_spin":max_spin,"isolated_transport":isolated,"transport_samples":actor.transport_samples,"trace":trace,"observed":snapshot()})
	await finish()
func stale_launch(operation: String) -> void:
	begin(); surface(Vector2(400,220),Vector2(1200,40))
	actor = make_actor("PC",Vector2(120,200)); cargo = make_cargo(Vector2(155,186))
	await frames(8)
	var calls := [0]
	actor.movement_event.connect(func(kind: StringName,_payload: Dictionary):
		if kind == &"strike_confirmed" and calls[0] == 0:
			calls[0] += 1
			if operation == "retire": cargo.invalidate_pending_contacts()
			elif operation == "move": cargo.position.x += 100
			elif operation == "shape": cargo.get_node("CollisionShape2D").shape.size = Vector2(4,4)
			elif operation == "freeze": cargo.freeze = true)
	intent("PC",Vector2.ZERO,true); await frames(1); intent("PC")
	await frames(hz)
	records.append({"scenario":"confirmation_"+operation,"callback_count":calls[0],"observed":snapshot()})
	await finish()
func launch_feedback() -> void:
	begin(); surface(Vector2(400,220),Vector2(1200,40))
	actor = make_actor("PC",Vector2(120,200)); cargo = make_cargo(Vector2(155,186)); await frames(8)
	var events: Array[Dictionary] = []
	cargo.burst_requested.connect(func(_a,_b,_c,_d): events.append({"kind":"burst","frame":Engine.get_physics_frames(),"epoch":cargo.impact_epoch,"lifecycle":cargo._lifecycle}); cargo.invalidate_pending_contacts())
	cargo.sound_requested.connect(func(_a,_b,_c): events.append({"kind":"sound","frame":Engine.get_physics_frames(),"epoch":cargo.impact_epoch,"lifecycle":cargo._lifecycle}))
	cargo.text_requested.connect(func(_a,_b,_c): events.append({"kind":"text","frame":Engine.get_physics_frames(),"epoch":cargo.impact_epoch,"lifecycle":cargo._lifecycle}))
	cargo.launched.connect(func(_p): events.append({"kind":"launched","frame":Engine.get_physics_frames(),"epoch":cargo.impact_epoch,"lifecycle":cargo._lifecycle}))
	intent("PC",Vector2.ZERO,true); await frames(1); intent("PC"); await frames(ceili(hz*0.4))
	records.append({"scenario":"post_commit_retirement","events":events,"observed":snapshot()})
	await finish()
func _run() -> void:
	seed(3271)
	await support("PC",1)
	for role in ["PC","NPC"]:
		await support(role,9); await push(role); await moving_support(role); await moving_support(role,true)
	for operation in ["retire","move","shape","freeze"]: await stale_launch(operation)
	await launch_feedback()
	var report := {"hz":hz,"scope":"Observational prechange actual physics; equal-controller role fixtures plus labelled lifecycle callbacks, not final acceptance.","records":records,"failures":failures}
	FileAccess.open("res://simulation/evidence/actor_cargo_baseline/trace_%d.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	for record in records:
		var small := record.duplicate(true); small.erase("trace"); small.erase("transport_samples"); print(JSON.stringify(small))
	quit(0)
