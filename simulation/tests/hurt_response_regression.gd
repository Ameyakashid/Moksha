extends "res://simulation/tests/shield_counter_regression.gd"
## Successful cases use ordinary player/NPC input and real incoming contacts.
## Direct receive_attack calls below are explicitly labelled lifecycle/API probes.
const Step = preload("res://combat_pc/resources/melee_step.gd")
const Chain = preload("res://combat_pc/resources/melee_chain.gd")
const HealthScene = preload("res://combat_pc/components/health_component.tscn")
class CounterSourceProbe extends MokshaShieldContactAdapter:
	var after_claim: Callable
	func counter_source_is_current(packet: Dictionary, expected_binding: int = -1) -> bool:
		var current := super.counter_source_is_current(packet,expected_binding)
		if current and not _delivery_scope.is_empty() and bool(_delivery_scope.get("claimed",false)) and after_claim.is_valid():
			var callback := after_claim; after_claim=Callable(); callback.call()
		return current
var braced: Array[Dictionary] = []
var hurt: Array[Dictionary] = []
var resolved: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
func _actor(at: Vector2, mode: String, facing := 1) -> Node2D:
	var actor := super._actor(at, mode, facing)
	actor.movement_event.connect(func(kind, payload):
		var record: Dictionary = payload.duplicate(true)
		record.actor_id = actor.get_instance_id()
		record.state = actor.telemetry()
		if kind == &"hurt_braced": braced.append(record)
		if kind == &"hurt_started": hurt.append(record)
		if kind == &"defense_resolved": resolved.append(record))
	actor.get_node("PhysicalImpactReceiver").impact_resolved.connect(func(receipt): impacts.append(receipt.duplicate(true)))
	return actor
func _begin(next: String, lm := "PC", rm := "NPC", distance := 36.0) -> void:
	braced=[]; hurt=[]; resolved=[]; impacts=[]
	await super._begin(next,lm,rm,distance)
func _configure(actor: Node, protect := true, windup := 0.6, active := 0.6, recovery := 0.4, outgoing := false) -> Resource:
	var step := Step.new()
	step.next_step=-1
	step.windup_seconds=windup; step.active_seconds=active; step.recovery_seconds=recovery
	step.windup_move_scale=0.0; step.recovery_move_scale=0.0; step.active_ground_speed=0.0
	step.allow_turn_windup=false; step.allow_turn_active=false; step.allow_turn_recovery=false
	step.hurt_protected_phases=PackedStringArray(["windup","active"]) if protect else PackedStringArray()
	var chain := Chain.new(); chain.steps.append(step)
	actor.melee_chain=chain
	actor.get_node("ContactAdapter").enabled=outgoing
	return step
func _enter_phase(actor: Node, phase: StringName) -> void:
	await _attack(actor)
	_check(await _until(func(): return actor.weapon_phase==phase,2.5),"ordinary input reaches "+String(phase))
func _own_events(events: Array[Dictionary], actor: Node) -> Array[Dictionary]:
	return events.filter(func(event): return event.get("actor_id")==actor.get_instance_id())
func _assert_braced(actor: Node, serial: int, phase: StringName, before: Dictionary, damage: float) -> void:
	var responses := _own_events(resolved,actor)
	_check(_health(actor)==30.0-damage,"full exact Health debit")
	_check(_own_events(braced,actor).size()==1 and _own_events(hurt,actor).is_empty(),"one braced event and no fabricated recoil event")
	_check(responses.size()==1 and responses[0].admitted_damage and responses[0].braced and not responses[0].hurt_applied and not responses[0].applied_recoil and not responses[0].attack_interrupted,"separate damage admission and physical response diagnostics")
	_check(actor.attack_serial==serial and actor.weapon_phase==phase and actor.main_action==before.main_action,"committed attack remains current")
	_check(actor.facing==before.facing and actor.grounded==before.grounded and actor.telemetry().support_id==before.support_id,"facing and true support preserved")
	var actual_health := _own_events(health_events,actor)
	_check(actual_health.size()==1 and actual_health[0].applied==damage and actual_health[0].braced and not actual_health[0].applied_recoil,"one Health-confirmed braced fact")
	_check(_own_events(noise_events,actor).filter(func(event): return event.kind==&"hurt").size()==1,"one existing committed hurt sound")
func _run() -> void:
	await _melee_cases()
	await _duration_cases()
	await _counter_cases()
	await _counter_claim_retirement_cases()
	await _cargo_cases()
	await _snapshot_cases()
	await _lifecycle_cases_braced()
	await _health_binding_cases()
	await _negative_configuration_cases()
	print("SHARED HURT RESPONSE %d Hz: %d scenarios, %d checks, %d failures" % [hz,scenarios.size(),checks,failures.size()])
	for failure in failures: printerr(failure)
	var report := {"hz":hz,"scenarios":scenarios,"checks":checks,"failures":failures,"execution":"Actual input and melee/counter/cargo contacts; direct lifecycle/API probes explicitly labelled."}
	FileAccess.open("res://simulation/evidence/hurt_response_%d.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit(0 if failures.is_empty() else 1)
func _melee_cases() -> void:
	for pair in [["PC","NPC"],["NPC","PC"],["NPC","NPC"]]:
		for phase in [&"windup",&"active"]:
			await _begin("real %s to %s braced %s" % [pair[0],pair[1],phase],pair[0],pair[1])
			_configure(right)
			await _enter_phase(right,phase)
			var serial: int=right.attack_serial; var before: Dictionary=right.telemetry()
			await _attack(left)
			_check(await _until(func(): return not receipts.is_empty()),"real sword contacts protected target")
			_assert_braced(right,serial,phase,before,1.0)
			_check(right.hitpause_remaining>0.0 and right.hitpause_remaining<=right.combat_profile.hurt_hitpause_seconds,"existing authored hurt hitpause remains")
			var elapsed: float=right._weapon_elapsed
			await _frames(1)
			_check(right._weapon_elapsed==elapsed,"one common phase clock freezes during local pause")
			await _frames(ceili(hz*.25))
			_check(_health(right)==29 and receipts.size()==1,"same real source sweep cannot debit twice")
			await _end()
	for mode in ["PC","NPC"]:
		for phase in [&"idle",&"recovery",&"unconfigured",&"charge"]:
			await _begin(mode+" ordinary response "+String(phase),"NPC",mode)
			_configure(right,phase!=&"unconfigured")
			if phase in [&"recovery",&"unconfigured"]: await _enter_phase(right,&"recovery" if phase==&"recovery" else &"windup")
			if phase==&"charge":
				right.melee_input_profile=load("res://combat_pc/resources/held_charge.tres").duplicate(true)
				right.melee_input_profile.charge_seconds=2.0
				right.melee_input_profile.charge_starter.hurt_protected_phases=PackedStringArray(["windup","active"])
				_request(right,{"attack":true})
				_check(await _until(func(): return right.weapon_phase==&"charge"),"ordinary held input enters charge")
			await _attack(left)
			_check(await _until(func(): return not receipts.is_empty()),"real sword reaches ordinary phase")
			_check(_health(right)==29 and right.main_action==&"hurt" and right.weapon_phase==&"idle" and right.velocity.x>0,"ordinary recoil/cancellation unchanged")
			_check(_own_events(braced,right).is_empty() and _own_events(hurt,right).size()==1,"no phase-name immunity")
			await _end()
func _duration_cases() -> void:
	for mode in ["PC","NPC"]:
		for duration in [0.0,0.699999,0.7,0.700001]:
			await _begin("real "+mode+" duration "+str(duration),"NPC",mode)
			_configure(right); right.combat_profile.hurt_seconds=duration
			left.combat_profile.strike_impulse=Vector2(1400,-800) if duration<0.7 else Vector2.ZERO
			await _enter_phase(right,&"windup")
			await _attack(left); await _until(func(): return not receipts.is_empty())
			_check(_health(right)==29,"threshold never reduces damage")
			_check((right.main_action!=&"hurt" and right.weapon_phase==&"windup") if duration<0.7 else (right.main_action==&"hurt" and right.weapon_phase==&"idle"),"strict duration threshold ignores impulse magnitude")
			_check(right.velocity.is_zero_approx(),"short huge impulse suppressed; long zero impulse remains zero")
			await _end()
func _counter_cases() -> void:
	for pair in [["PC","NPC"],["NPC","PC"],["NPC","NPC"]]:
		for duration in [-1.0,0.699999,0.7,0.78]:
			await _begin("real %s to %s counter %.6f" % [pair[0],pair[1],duration],pair[0],pair[1])
			_configure(left,true,0.09,0.5,0.4,true)
			_counter(left).response_stun_seconds=duration
			await _frames(2)
			await _parry(left,right)
			_check(_health(left)==27 and _health(right)==30 and counters.size()==1,"actual canonical ray debits exact counter once")
			_check(receipts.size()==1 and receipts[0].outcome==&"parried" and receipts[0].counter_confirmed,"independent incoming parry and confirmed physical counter")
			var interrupts: bool = duration>=0.7
			_check((left.main_action==&"hurt" and left.weapon_phase==&"idle" and left.velocity.x<0) if interrupts else (left.main_action!=&"hurt" and left.weapon_phase==&"active"),"configured true counter follows common duration rule")
			_check(_own_events(braced,left).size()==(0 if interrupts else 1),"default -1 preserves actor's ordinary .18 response")
			await _end()
	for condition in ["disabled","removed","range","wall","guard","counterable_off"]:
		await _begin("real failed counter no fake recoil / "+condition,"NPC","PC")
		_configure(left,true,0.09,0.5,0.4,true); _counter(left).response_stun_seconds=0.78
		match condition:
			"disabled": _counter(left).enabled=false
			"removed": _counter(left).queue_free()
			"range": right.shield_profile.counter_range=1.0
			"wall": _surface(Vector2(220,174),Vector2(2,52),128); right.get_node("ShieldContactAdapter").obstruction_mask=129
			"counterable_off": _receiver(right).counterable=false
		await _frames(3)
		_request(right,{"shield":true})
		if condition=="guard": await _frames(ceili(hz*.3))
		await _attack(left); await _until(func(): return not receipts.is_empty())
		_check(receipts.size()==1 and receipts[0].outcome==(&"guarded" if condition=="guard" else &"parried"),"incoming defense remains true")
		_check(_health(left)==30 and left.weapon_phase==&"active" and left.main_action!=&"hurt" and counters.is_empty(),"unreachable counter never fabricates attacker recoil or damage")
		await _end()
	for change in ["different","away_back","invalid"]:
		await _begin("actual counter capture config retirement / "+change,"NPC","PC")
		_configure(left,true,0.09,0.5,0.4,true)
		var probe := _probe(left); probe.response_stun_seconds=0.78
		probe.after_capture=func():
			probe.response_stun_seconds=0.8 if change!="invalid" else NAN
			if change=="away_back": probe.response_stun_seconds=0.78
		await _frames(3); await _parry(left,right)
		_check(_health(left)==30 and counters.is_empty() and left.weapon_phase==&"active","config replacement retires captured permission without fake effect")
		_check(receipts.size()==1 and receipts[0].outcome==&"parried" and not receipts[0].counter_confirmed,"parry remains independently completed")
		await _end()
func _counter_claim_retirement_cases() -> void:
	for operation in ["counter_config","incoming_toggle","shape_disabled","shape_replaced","shape_transform","host_layer","hurtbox_layer","source_toggle","source_finish","source_shield_gate","source_physics","source_reset"]:
		await _begin("actual post-claim counter target retirement / "+operation,"NPC","PC")
		_configure(left,true,0.09,0.5,0.4,true); _counter(left).response_stun_seconds=0.78
		var old: Node=right.get_node("ShieldContactAdapter"); old.bind_actor(null); right.remove_child(old); old.queue_free()
		var probe := CounterSourceProbe.new(); probe.name="ShieldContactAdapter"; right.add_child(probe)
		var called: Array[bool]=[]
		probe.after_claim=func():
			called.append(true)
			match operation:
				"counter_config": _counter(left).response_stun_seconds=0.8; _counter(left).response_stun_seconds=0.78
				"incoming_toggle": _receiver(left).enabled=false; _receiver(left).enabled=true
				"shape_disabled": left.get_node("BodyShape").disabled=true
				"shape_replaced":
					var shape := RectangleShape2D.new(); shape.size=Vector2(18,36); left.get_node("BodyShape").shape=shape
				"shape_transform": _receiver(left).position.x=2.0
				"host_layer": left.collision_layer=2
				"hurtbox_layer": _receiver(left).collision_layer=4
				"source_toggle": probe.enabled=false; probe.enabled=true
				"source_finish": right.finish_main_action()
				"source_shield_gate": right.allow_shield=false
				"source_physics": right.set_physics_process(false)
				"source_reset": right.reset_actor(right.position,-1)
		await _frames(3); await _parry(left,right)
		_check(called==[true],"actual canonical ray reaches one-use claim")
		_check(_health(left)==30 and counters.is_empty() and left.main_action!=&"hurt","retired local target state cannot debit or recoil after final source callback")
		if operation in ["source_finish","source_reset","source_physics"]:
			_check(probe.confirmed_counters==0,"retired source produces no stale confirmation")
		else:
			_check(receipts.size()==1 and receipts[0].outcome==&"parried" and not receipts[0].counter_confirmed,"incoming parry remains independently completed")
		await _end()
func _cargo_cases() -> void:
	for mode in ["PC","NPC"]:
		for duration in [0.42,0.699999,0.7,0.78]:
			await _begin("real cargo "+mode+" duration "+str(duration),"NPC",mode,360)
			_configure(right,true,1.0,0.8,0.4)
			await _enter_phase(right,&"windup")
			var cargo := Cargo.instantiate()
			cargo.position=right.position+Vector2(-110,-20)
			cargo.tuning=cargo.tuning.duplicate(true); cargo.tuning.body_gravity_scale=0; cargo.tuning.hard_impacts_to_break=100
			cargo.linear_velocity=Vector2(260,0)
			cargo.impact_profile.stun_seconds=duration; cargo.impact_profile.hitpause_seconds=0.06
			world.add_child(cargo)
			_check(await _until(func(): return not impacts.is_empty()),"real rigid solver contact admitted")
			_check(_health(right)==27 and impacts.size()==1 and impacts[0].normal_speed>=80,"actual cargo full damage exactly once")
			_check((right.main_action!=&"hurt" and right.weapon_phase==&"windup") if duration<0.7 else (right.main_action==&"hurt" and right.weapon_phase==&"idle"),"same configured cargo threshold as melee/counter")
			await _end()
func _snapshot_cases() -> void:
	for change in ["source_edit","chain_replace","input_replace","peer_edit"]:
		await _begin("committed snapshot / "+change,"NPC","PC")
		var step := _configure(right)
		await _enter_phase(right,&"windup")
		if change=="source_edit": step.hurt_protected_phases=PackedStringArray(); step.hurt_interrupt_seconds=0.0
		elif change=="chain_replace": right.melee_chain=right.melee_chain.duplicate(true)
		elif change=="input_replace": right.melee_input_profile=preload("res://simulation/resources/projectile_input.tres").duplicate(true)
		else:
			_configure(left); left.melee_chain.steps[0].hurt_protected_phases=PackedStringArray(); left.get_node("ContactAdapter").enabled=true
			left.melee_chain=null
		var expected: bool = change in ["source_edit","peer_edit"]
		_check(right.hurt_response_snapshot().protected==expected,"current snapshot observation has no mutable resource authority")
		await _attack(left); await _until(func(): return not receipts.is_empty())
		_check(_health(right)==29 and (right.main_action!=&"hurt" if expected else right.main_action==&"hurt"),"source copy isolation/current configuration fence")
		await _end()
	await _begin("real lethal protected melee","NPC","PC")
	_configure(right); left.combat_profile.strike_damage=45
	var deaths: Array[bool]=[]; right.get_node("DefeatResponse").defeat_started.connect(func(): deaths.append(true))
	await _enter_phase(right,&"windup"); await _attack(left); await _until(func(): return right.is_defeated())
	_check(_health(right)==0 and deaths==[true] and right.weapon_phase==&"idle","one bounded lethal debit retires braced action through Defeat")
	var facts := _own_events(health_events,right)
	_check(facts.size()==1 and facts[0].applied==30 and facts[0].braced,"Health records real clamped braced fact")
	await _frames(ceili(hz*.5)); _check(_health(left)==30 and deaths==[true],"no ghost outgoing action after defeat")
	await _end()
func _lifecycle_cases_braced() -> void:
	for stage in ["hurt_braced","hurt_noise","hitpause_started","defense_resolved"]:
		for action in ["target_reset","target_remove","source_reset","forced","chain_replace"]:
			await _begin("actual braced callback / "+stage+" / "+action,"NPC","PC")
			_configure(right); await _enter_phase(right,&"windup")
			var called: Array[bool]=[]
			var retire := func():
				if not called.is_empty(): return
				called.append(true)
				match action:
					"target_reset": right.reset_actor(right.position,-1)
					"target_remove": right.queue_free()
					"source_reset": left.reset_actor(left.position,1)
					"forced": right.finish_main_action()
					"chain_replace": right.melee_chain=right.melee_chain.duplicate(true)
			if stage=="hurt_noise": right.noise_requested.connect(func(_origin,kind,_loudness,_source):
				if kind==&"hurt": retire.call())
			else: right.movement_event.connect(func(kind,_payload):
				if kind==StringName(stage): retire.call())
			await _attack(left); await _until(func(): return not called.is_empty())
			_check(called==[true],"genuine contact reaches lifecycle callback")
			var facts := health_events.filter(func(event): return event.get("actor_id")!=left.get_instance_id())
			_check(facts.is_empty() if action in ["target_reset","target_remove"] else (facts.size()==1 and facts[0].applied==1),"old life blocked; same-life admitted fact preserved")
			if action!="target_remove":
				_check(_health(right)==(30 if action=="target_reset" else 29),"correct final scalar Health")
				if stage=="hurt_braced": _check(right.hitpause_remaining==0 if action in ["target_reset","forced","chain_replace"] else true,"retired feedback cannot pause replacement owner")
			await _end()
	await _begin("real braced global pause resume","NPC","PC")
	_configure(right); await _enter_phase(right,&"windup")
	var elapsed: float=right._weapon_elapsed; paused=true; await _frames(8)
	_check(right._weapon_elapsed==elapsed,"global pause preserves existing action clock")
	paused=false; await _frames(3); await _attack(left); await _until(func(): return not receipts.is_empty())
	_check(_health(right)==29 and right.main_action!=&"hurt","resumed current action remains braced")
	await _end()
func _health_binding_cases() -> void:
	for operation in ["replace","rebind","replace_nested"]:
		for phase in ["hurt_braced","hurt_started"]:
			await _begin("real Health binding fence / "+operation+" / "+phase,"NPC","PC")
			_configure(right,phase=="hurt_braced"); await _enter_phase(right,&"windup")
			var called: Array[bool]=[]; var bound: Array[Node]=[right.get_node("Health")]
			right.movement_event.connect(func(kind,_payload):
				if kind!=StringName(phase) or not called.is_empty(): return
				called.append(true)
				var old := bound[0]; old.unbind_actor()
				if operation=="rebind": old.bind_actor(right)
				else:
					right.remove_child(old); old.queue_free()
					var fresh := HealthScene.instantiate(); fresh.name="Health"; fresh.maximum_health=30
					right.add_child(fresh); bound[0]=fresh
				if operation=="replace_nested":
					# Explicit nested API lifecycle probe after the real outer contact.
					right.receive_attack({"amount":2.0,"impulse":Vector2.ZERO,"hitpause":0.0,"rollable":false}))
			await _attack(left); await _until(func(): return not called.is_empty())
			_check(called==[true] and bound[0].current_health==(28 if operation=="replace_nested" else 30),"new Health binding rejects older outer admission, admits fresh nested work")
			# Explicit post-rebind API probe: no permanent damage immunity.
			right.receive_attack({"amount":1.0,"impulse":Vector2.ZERO,"hitpause":0.0,"rollable":false})
			_check(bound[0].current_health==(27 if operation=="replace_nested" else 29),"subsequent admission reaches current binding")
			await _end()
func _negative_configuration_cases() -> void:
	for invalid in ["negative","nonfinite","recovery","unknown"]:
		await _begin("invalid brace configuration / "+invalid,"NPC","PC")
		var step := _configure(right)
		match invalid:
			"negative": step.hurt_interrupt_seconds=-1
			"nonfinite": step.hurt_interrupt_seconds=NAN
			"recovery": step.hurt_protected_phases=PackedStringArray(["recovery"])
			"unknown": step.hurt_protected_phases=PackedStringArray(["invincible"])
		await _attack(right)
		_check(right.weapon_phase==&"idle" and not right.hurt_response_snapshot().protected,"invalid authored step fails closed")
		await _attack(left); await _until(func(): return not receipts.is_empty())
		_check(_health(right)==29 and right.main_action==&"hurt","invalid capability never grants damage/recoil immunity")
		await _end()
	for duration in [-2.0,-0.5,5.01,NAN,INF]:
		await _begin("invalid counter response config "+str(duration),"NPC","PC")
		_configure(left,true,0.09,0.5,0.4,true); _counter(left).response_stun_seconds=duration
		await _frames(3); await _parry(left,right)
		_check(_health(left)==30 and counters.is_empty() and receipts.size()==1 and receipts[0].outcome==&"parried","invalid config fails closed without corrupting incoming defense")
		await _end()
