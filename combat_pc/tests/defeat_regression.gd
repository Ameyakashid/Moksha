extends "res://combat_pc/tests/health_regression.gd"
## M13 focused policy acceptance, using the existing one-real-callback driver.
const DEFEAT = preload("res://combat_pc/components/defeat_response.tscn")
const POSE = preload("res://combat_pc/visuals/wireframe_pose.gd")
var response: Node
var starts := 0
var clears := 0
var defeat_paths: Array[String] = ["res://combat_pc/player.gd", "res://combat_pc/player.tscn", "res://combat_pc/components/health_component.gd", "res://combat_pc/components/defeat_response.gd", "res://combat_pc/components/defeat_response.tscn", "res://combat_pc/visuals/defeat_pose.gd", "res://combat_pc/visuals/wireframe.gd", "res://combat_pc/visuals/wireframe_pose.gd"]

class Carrier extends AnimatableBody2D:
	var travel_velocity := Vector2.ZERO
	func _physics_process(delta: float) -> void:
		position += travel_velocity * delta

func _run() -> void:
	for path in defeat_paths: hashes[path] = FileAccess.get_sha256(path)
	await _defense_cases()
	await _physical_lethal_cases()
	await _cancellation_cases()
	await _fall_and_carrier_cases()
	await _reset_and_lifetime_cases()
	await _acquisition_callback_cases()
	await _parity_case()
	_pose_cases()
	var stable := true
	for path in defeat_paths: stable = stable and hashes[path] == FileAccess.get_sha256(path)
	_check(stable, "production sources stayed unchanged during run")
	var report := {"milestone":13,"physics_hz":hz,"checks":checks.size(),"failures":failures,"scenarios":scenarios,"total_physics_ticks":total_ticks,"source_hashes":hashes,"production_hash_stable_during_run":stable,"engine":Engine.get_version_info().string,"generated_utc":Time.get_datetime_string_from_system(true),"execution":"Real reusable player and optional Health/DefeatResponse, one driver call per engine physics callback; bounded assertions and measurements","limitations":["Headless integration and numeric pose checks; native visual review belongs to parent","Authored collapse policy and timing; no source-game death-animation parity claim"]}
	FileAccess.open("res://combat_pc/tests/defeat_results_%dhz.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("DEFEAT_M13 %dHz: %d checks, %d scenarios, %d failures" % [hz,checks.size(),scenarios.size(),failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _begin(name_: String, attach := true) -> void:
	await super._begin(name_,true)
	response=null; starts=0; clears=0
	if attach: _attach_response()

func _attach_response(target: Node = null) -> Node:
	var result: Node=DEFEAT.instantiate()
	result.defeat_started.connect(func(): starts+=1)
	result.defeat_cleared.connect(func(): clears+=1)
	(target if target!=null else actor).add_child(result)
	response=result
	return result

func _kill(extra: Dictionary = {}) -> bool:
	return actor.receive_hit({"amount":150.0,"impulse":Vector2(-120,-50),"stun_seconds":0.18,"hitpause":0.0,"rollable":false}.merged(extra,true))

func _assert_retired() -> void:
	_check(actor.main_action==&"defeated" and actor.is_defeated() and response.active,"zero Health installs the response-owned terminal action")
	_check(actor.weapon_phase==&"idle" and actor.shield_phase==&"idle" and actor.roll_phase==&"", "defeat retires weapon shield and roll owners")
	_check(actor._attack_buffer==0 and actor._jump_buffer==0 and actor._roll_buffer==0 and actor._shield_buffer==0 and actor._chain_pending.is_empty() and not actor._attack_hold_armed,"defeat clears queued input and held attack admission")

func _defense_cases() -> void:
	for mode in ["hurt","guard","parry","roll"]:
		await _begin("nonlethal "+mode)
		await _enter(mode)
		var result: Dictionary=actor.receive_attack(_attack(_source(),1,20))
		var expected: StringName={"hurt":&"hurt","guard":&"guarded","parry":&"parried","roll":&"evaded"}[mode]
		_check(result.outcome==expected and health.current_health>0 and not actor.is_defeated() and starts==0,"nonlethal and fully defended outcomes do not acquire defeat")
		await _finish({"outcome":String(result.outcome),"health":health.current_health})

func _physical_lethal_cases() -> void:
	for mode in ["hurt","guard"]:
		await _begin("real lethal melee "+mode)
		health.maximum_health=10 if mode=="hurt" else 1
		health.reset_to_full()
		await _enter(mode)
		var fixture: Node=MELEE.instantiate()
		fixture.position=actor.position+Vector2(43,0)
		fixture.telegraph_seconds=0.05; fixture.attack_damage=20
		world.add_child(fixture)
		_check(fixture.trigger_attack(),"real swept melee fixture arms")
		_check(await _until(func(): return fixture.contacts>0,{"shield":mode=="guard"}),"real swept melee reaches actual actor")
		_assert_retired()
		_check(health.current_health==0 and starts==1 and depletions==1,"one lethal damage receipt produces one policy transition")
		_check(fixture.last_result.outcome==(&"hurt" if mode=="hurt" else &"guarded"),"lethal guard chip preserves guarded outcome")
		var velocity_before: Vector2=actor.velocity
		var receipt_count:=receipts.size()
		var later: Dictionary=actor.receive_attack(_attack(_source(),42,500,{"impulse":Vector2(700,-900)}))
		_check(not later.consumed and not _kill({"impulse":Vector2(700,-900)}) and actor.velocity==velocity_before and receipts.size()==receipt_count,"later identified and legacy hits reject without recoil or extra receipts")
		var elapsed: float=actor.telemetry().defeat_elapsed
		if actor.hitpause_remaining>dt:
			await _step({"attack":true,"jump":true,"roll":true,"shield":true,"right":1.0})
			_near(actor.telemetry().defeat_elapsed,elapsed,"lethal contact hitpause freezes collapse clock")
		await _step({"attack":true,"jump":true,"roll":true,"shield":true,"right":1.0,"down":1.0},ceili(1.1/dt))
		_check(actor.is_defeated() and actor.grounded and actor.weapon_phase==&"idle" and actor.shield_phase==&"idle" and actor.velocity.length()<0.001,"all held controls remain locked while recoil settles onto floor")
		_check(actor.telemetry().defeat_progress==1.0 and starts==1,"collapse completes without timed revival")
		_check(actor.get_node("Visual").pose_name=="defeated" and actor.get_node("Visual").pose_key=="defeated_settled","actual motor telemetry selects settled defeated rendering")
		await _finish({"contacts":fixture.contacts,"outcome":String(fixture.last_result.outcome),"collapse_progress":actor.telemetry().defeat_progress})

func _cancellation_cases() -> void:
	for mode in ["active","queued","charge","shield"]:
		await _begin("retire live "+mode)
		if mode=="charge": actor.melee_input_profile=load("res://combat_pc/resources/held_charge.tres").duplicate(true)
		if mode=="shield": await _enter("guard")
		else:
			await _step({"attack":true})
			_check(await _until(func(): return actor.weapon_phase==(&"charge" if mode=="charge" else &"active"),{"attack":true}),"fixture reaches intended weapon phase")
			if mode=="queued":
				await _step({})
				await _step({"attack":true})
				_check(actor._attack_buffer>0 or not actor._chain_pending.is_empty(),"fixture contains a genuine queued attack")
		var serial: int=actor.attack_serial
		_check(_kill(),"lethal legacy hit commits")
		_assert_retired()
		_check(not actor.is_strike_current(serial) and not actor.confirm_strike(serial,99001,actor.position),"old strike eligibility and delayed confirmations retire")
		await _step({"attack":true,"shield":true},ceili(0.8/dt))
		_check(actor.attack_serial==serial and actor.weapon_phase==&"idle" and actor.shield_phase==&"idle","held controls cannot start another attack or shield")
		response.unbind()
		await _step({"attack":true,"shield":true},ceili(0.3/dt))
		_check(actor.weapon_phase==&"idle" and actor.shield_phase==&"idle","component release cannot replay buttons held across defeat")
		await _step({})
		await _step({"attack":true})
		_check(actor.weapon_phase!=&"idle","fresh neutral then press works after explicit policy release")
		await _finish()

func _fall_and_carrier_cases() -> void:
	await _begin("defeated high fall does not revive through hard landing")
	world.get_child(0).position.y=720
	actor.enable_hard_landing=true
	actor.reset_actor(Vector2(100,100))
	await _step({},2)
	_check(_kill({"impulse":Vector2(160,400)}),"airborne lethal recoil commits")
	_check(not actor.grounded and actor.telemetry().pose==&"defeated_air","airborne defeat chooses air pose")
	_check(await _until(func(): return actor.grounded,{"jump":true,"roll":true,"attack":true},3.0),"defeated body falls and lands through production sweep")
	_check(actor.main_action==&"defeated" and not movement.has("hard_land_started") and actor.position.y<=700.01,"qualifying high contact cannot replace defeat or tunnel through floor")
	await _step({},ceili(0.8/dt))
	_check(actor.is_defeated() and actor.grounded and actor.velocity==Vector2.ZERO,"gravity and existing hurt drag converge to stable terminal body")
	await _finish({"foot_y":actor.position.y,"floor_y":700})
	await _begin("defeated moving support and carrier hitpause")
	var floor: Node=world.get_child(0)
	world.remove_child(floor); floor.free()
	var carrier:=Carrier.new()
	carrier.position=Vector2(100,220); carrier.sync_to_physics=false; carrier.process_physics_priority=-20
	var shape:=CollisionShape2D.new(); shape.shape=RectangleShape2D.new(); shape.shape.size=Vector2(800,40)
	carrier.add_child(shape); world.add_child(carrier)
	actor.reset_actor(Vector2(100,200))
	await _step({},3)
	_check(actor.grounded,"carrier fixture establishes real support")
	_kill({"impulse":Vector2.ZERO})
	await _step({},ceili(0.5/dt))
	carrier.travel_velocity=Vector2(45,-12)
	var relative_before: Vector2=actor.position-carrier.position
	actor.apply_hitpause(0.1)
	var clock_before: float=actor.telemetry().defeat_elapsed
	await _step({},maxi(1,ceili(0.06/dt)))
	_near(actor.telemetry().defeat_elapsed,clock_before,"carrier motion cannot advance paused collapse clock")
	await _step({"right":1.0},ceili(0.6/dt))
	var error: float=(actor.position-carrier.position).distance_to(relative_before)
	_check(actor.grounded and actor.is_defeated() and error<0.3,"settled terminal body retains swept moving-support transport",{"relative_error":error})
	await _finish({"relative_error":error,"carrier_travel_x":carrier.position.x-100})

func _reset_and_lifetime_cases() -> void:
	await _begin("health-only and actor reset have separate policies")
	_kill()
	health.reset_to_full()
	_check(actor.is_defeated() and response.active and health.current_health==100,"refilling quantity alone does not revive")
	actor.reset_actor(Vector2(100,200))
	_check(not actor.is_defeated() and not response.active and clears==1 and health.current_health==100,"explicit actor reset releases terminal ownership and restores default health")
	await _step({},2)
	_kill()
	_check(starts==2 and actor.is_defeated(),"a reset actor can acquire a new defeat episode")
	actor.allow_input=false
	actor.set_weapon_permissions({"can_attack":false,"can_turn":false,"move_scale":0.4})
	var host: Dictionary=actor._external_weapon_permissions.duplicate(true)
	response.unbind()
	_check(not actor.is_defeated() and not actor.allow_input and actor._external_weapon_permissions==host,"component release preserves host input and weapon settings")
	await _finish()
	for disposition in ["detach_response","remove_health","queue_response"]:
		await _begin("lifetime "+disposition)
		_kill()
		if disposition=="detach_response": actor.remove_child(response)
		elif disposition=="remove_health": actor.remove_child(health)
		else: response.queue_free(); await process_frame
		_check(not actor.is_defeated(),"component or health lifetime end releases only its gate")
		if disposition=="detach_response": response.free()
		elif disposition=="remove_health": health.free()
		await _finish()
	await _begin("retained callbacks mismatched store and replacement owner")
	var old: Callable=response._depleted_callback
	response.unbind()
	_kill()
	old.call()
	_check(not actor.is_defeated(),"old retained depleted callable cannot acquire after unbind")
	var replacement:=_new_actor(Vector2(300,200))
	_check(not response.bind(replacement,health),"bind rejects Health belonging to a different actor")
	_check(response.bind(actor,health) and actor.is_defeated(),"binding current zero Health acquires terminal state")
	var replacement_owner:=Node.new(); world.add_child(replacement_owner)
	_check(not actor.release_defeated(replacement_owner) and not actor.enter_defeated(replacement_owner),"foreign owner cannot release or replace an acquired gate")
	response.unbind()
	_check(actor.enter_defeated(replacement_owner),"matching release permits a new owner")
	old.call(); response.unbind()
	_check(actor.is_defeated_by(replacement_owner),"stale component cleanup cannot retire replacement ownership")
	world.remove_child(replacement_owner)
	_check(not actor.is_defeated(),"replacement owner's actual tree exit releases its own gate")
	replacement_owner.free()
	_check(health.bind_actor(replacement),"Health can rebind to replacement actor")
	_check(response.bind(replacement,health) and replacement.is_defeated(),"policy can rebind to replacement actor and current zero store")
	await _finish()
	await _begin("Health rebound before depletion invalidates prior response")
	var other:=_new_actor(Vector2(300,200))
	health.bind_actor(other)
	other.receive_hit({"amount":150,"hitpause":0.0})
	_check(health.current_health==0 and not actor.is_defeated() and not other.is_defeated() and starts==0,"depletion-time binding check rejects a store that changed actors")
	await _finish()

func _acquisition_callback_cases() -> void:
	for mode in ["reset","unbind","replacement"]:
		await _begin("synchronous acquisition callback "+mode)
		var alternate:=Node.new(); world.add_child(alternate)
		var entered: Array[bool]=[false]
		actor.action_changed.connect(func(_previous: StringName,current: StringName):
			if current!=&"defeated" or entered[0]: return
			entered[0]=true
			if mode=="reset": actor.reset_actor(Vector2(100,200))
			else:
				response.unbind()
				if mode=="replacement": actor.enter_defeated(alternate))
		_kill()
		_check(entered[0] and starts==0 and not response.active,"synchronous callback invalidates outer acquisition and stale start signal")
		if mode=="replacement": _check(actor.is_defeated_by(alternate),"new owner survives return through prior acquisition stack")
		else: _check(not actor.is_defeated() and actor.main_action==&"locomotion","reset or unbind remains authoritative after callback returns")
		if mode=="reset": _check(health.current_health==100,"actor reset during acquisition restores scalar health")
		await _finish()

func _parity_case() -> void:
	await _begin("optional response has no policy before depletion")
	var bare:=_new_actor()
	driver.actors.append(bare)
	actor.reset_actor(Vector2(100,200)); bare.reset_actor(Vector2(100,200))
	var mismatch:=0
	for segment in [{"frame":{"right":1.0},"seconds":0.2},{"frame":{"jump":true},"seconds":0.1},{"frame":{},"seconds":0.5},{"frame":{"roll":true},"seconds":0.4},{"frame":{"shield":true},"seconds":0.4},{"frame":{},"seconds":0.3},{"frame":{"attack":true},"seconds":0.4}]:
		for _i in ceili(segment.seconds/dt):
			await _step(segment.frame)
			if _motor_state(actor)!=_motor_state(bare): mismatch+=1
	_check(mismatch==0 and starts==0,"attached inactive response and bare actor have exact movement/combat parity",{"mismatched_ticks":mismatch})
	response.unbind()
	actor.reset_actor(Vector2(100,200))
	_kill()
	_check(health.current_health==0 and not actor.is_defeated() and actor.main_action==&"hurt","Health without response retains M12 depletion behavior")
	await _finish()

func _pose_cases() -> void:
	label="passive mirrored collapse geometry"
	var start:=checks.size()
	var maximum_mirror_error:=0.0
	var minimum_clearance:=INF
	var samples:=0
	for mode in ["defeated","defeated_air"]:
		for phase in [0.0,0.2,0.4,0.65,0.92,1.0]:
			for slope in [-0.4,0.0,0.4]:
				var normal:=Vector2(slope,-1).normalized()
				var t: Dictionary={"grounded":mode=="defeated","position":Vector2(10,20),"floor_contact_point":Vector2(10,20),"floor_normal":normal,"facing":1}
				var right: Dictionary=POSE.evaluate(mode,phase,t)
				t.facing=-1; t.floor_normal=Vector2(-normal.x,normal.y)
				var left: Dictionary=POSE.evaluate(mode,phase,t)
				var finite:=true
				for bone in right.bones:
					var point: Vector2=right.bones[bone]
					finite=finite and point.is_finite() and Vector2(left.bones[bone]).is_finite()
					maximum_mirror_error=maxf(maximum_mirror_error,Vector2(-point.x,point.y).distance_to(left.bones[bone]))
				if mode=="defeated":
					for bone in ["sole_near","sole_far","knee_near","knee_far"]: minimum_clearance=minf(minimum_clearance,Vector2(right.bones[bone]).dot(normal))
				_check(finite and not right.weapon.visible and not left.weapon.visible,"finite passive unarmed collapse sample",{"mode":mode,"phase":phase,"slope":slope})
				samples+=1
	_check(maximum_mirror_error<0.0001,"all sampled air and ground collapse bones mirror",{"maximum_error":maximum_mirror_error})
	_check(minimum_clearance>=-0.01,"ground feet and knees stay above sampled flat and slope contact planes",{"minimum_clearance":minimum_clearance})
	var rest: Dictionary=POSE.evaluate("defeated",1.0,{"grounded":true,"facing":1})
	_check(rest.key=="defeated_settled" and absf(rest.bones.head.y-rest.bones.chest.y)<2 and absf(rest.bones.head.x-rest.bones.chest.x)>4,"settled head follows horizontal torso for a readable prone silhouette")
	scenarios.append({"name":label,"assertions":checks.slice(start),"physics_ticks":0,"measurements":{"samples":samples,"maximum_mirror_error":maximum_mirror_error,"minimum_floor_clearance":minimum_clearance}})
