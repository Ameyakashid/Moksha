extends "res://simulation/tests/shared_actor_regression.gd"
## Generic fresh independent commitments. Raw input owns attacks; direct hurt,
## reset/configuration and notification probes are explicitly API/lifecycle tests.
const Chain = preload("res://combat_pc/resources/melee_chain.gd")
const Step = preload("res://combat_pc/resources/melee_step.gd")
var scenarios: Array[String] = []
func begin_case(next: String) -> void:
	scenarios.append(next); _begin(next)
	for offset in [Vector2.ZERO, OFFSET]: _surface(Vector2(300,220)+offset,Vector2(900,40))
	await _pair()
func until(test: Callable, seconds := 2.0) -> bool:
	for tick in ceili(hz*seconds):
		await _frames(1)
		if test.call(): return true
	return false
func configure(actor: Node, sequence := PackedInt32Array([0,1])) -> void:
	var chain := Chain.new(); chain.fresh_start_steps=sequence
	for index in 2:
		var step := Step.new(); step.next_step=-1; step.step_label="Opening %d" % index; step.pose_id=StringName("opening_%d" % index)
		step.windup_seconds=.12; step.active_seconds=.06; step.recovery_seconds=.16
		step.windup_move_scale=0; step.recovery_move_scale=0; step.active_ground_speed=0
		chain.steps.append(step)
	actor.melee_chain=chain
func press(actor: Node) -> void:
	if actor==pc: actor.get_node("InputSource").raw={"attack":true}
	else: actor.get_node("PatrolPolicy").intent={"attack":true}
func release(actor: Node) -> void:
	if actor==pc: actor.get_node("InputSource").raw={}
	else: actor.get_node("PatrolPolicy").intent={}
func start(actor: Node) -> bool:
	release(actor); await _frames(2)
	var serial: int=actor.attack_serial
	press(actor)
	var ok := await until(func(): return actor.attack_serial>serial)
	release(actor)
	_check(ok,"ordinary input commits an independent attack")
	return ok
func _run() -> void:
	await begin_case("paired fresh independent starts and rejected live requests")
	for actor in [pc,npc]: configure(actor)
	for expected in [0,1,0]:
		_equal_input(Vector2.ZERO,{"attack":true})
		_check(await until(func(): return pc.weapon_phase==&"windup" and npc.weapon_phase==&"windup"),"both sources commit real warning")
		for actor in [pc,npc]:
			var plan: Dictionary=actor.attack_plan_snapshot()
			_check(plan.is_read_only() and plan.step_index==expected and plan.committed,"defensive current step matches alternation")
			_check(plan.fresh_chain_commits==actor.attack_serial,"one counter increment per fresh commitment")
		_equal_input(); await _frames(1); _equal_input(Vector2.ZERO,{"attack":true}); await _frames(1); _equal_input()
		_check(await until(func(): return pc.weapon_phase==&"idle" and npc.weapon_phase==&"idle"),"terminal steps finish without combo")
		_check(pc.attack_serial==npc.attack_serial and pc.attack_plan_snapshot().step_index==1-expected,"rejected active request cannot consume next start")
		await _frames(2)
	await _end()
	await begin_case("interruption consumes a commitment; reset preserves lifetime serial")
	configure(pc)
	await start(pc)
	var first: int=pc.attack_serial
	pc.receive_attack({"amount":1.0,"impulse":Vector2.ZERO,"stun_seconds":.01,"hitpause":0.0})
	_check(pc.weapon_phase==&"idle" and pc.attack_plan_snapshot().fresh_chain_commits==1,"labelled hurt boundary retires action but not sequence")
	await until(func(): return pc.main_action!=&"hurt")
	await start(pc); _check(pc.attack_plan_snapshot().step_index==1,"next actual commitment is second opening")
	pc.reset_actor(Vector2(80,200),1); await _frames(4)
	_check(pc.attack_plan_snapshot().fresh_chain_commits==0 and pc.attack_plan_snapshot().step_index==0,"reset restores opening preview")
	await start(pc); _check(pc.attack_serial>first and pc.attack_plan_snapshot().step_index==0,"reset never rewinds attack identity")
	await _end()
	for operation in ["reset","chain","input","away_back"]:
		await begin_case("commit callback retirement / "+operation); configure(pc)
		var seen: Array[Dictionary]=[]
		pc.movement_event.connect(func(kind,payload):
			if kind!=&"attack_started" or not seen.is_empty(): return
			seen.append(pc.attack_plan_snapshot())
			match operation:
				"reset": pc.reset_actor(Vector2(80,200),1)
				"chain": pc.melee_chain=pc.melee_chain.duplicate(true)
				"input": pc.melee_input_profile=preload("res://simulation/resources/projectile_input.tres").duplicate(true)
				"away_back":
					var original: Resource=pc.melee_chain; pc.melee_chain=pc.melee_chain.duplicate(true); pc.melee_chain=original
		)
		await start(pc); await _frames(3)
		_check(seen.size()==1 and seen[0].fresh_chain_commits==1,"commit precedes first external callback")
		_check(pc.attack_plan_snapshot().fresh_chain_commits==0,"callback reset/reconfigure is not overwritten by late cursor increment")
		_check(not pc.set_pending_recovery_duration(int(seen[0].serial),int(seen[0].configuration_epoch),.1),"retired handle cannot mutate later action")
		await start(pc); _check(pc.attack_plan_snapshot().step_index==0,"replacement opens first independent step")
		await _end()
	await begin_case("pending copied recovery and strict phase/identity validation"); configure(pc)
	await start(pc)
	var plan: Dictionary=pc.attack_plan_snapshot()
	for bad in [NAN,INF,-1.0,0.0]: _check(not pc.set_pending_recovery_duration(plan.serial,plan.configuration_epoch,bad),"invalid duration rejected")
	_check(not pc.set_pending_recovery_duration(plan.serial+1,plan.configuration_epoch,.2) and not pc.set_pending_recovery_duration(plan.serial,plan.configuration_epoch+1,.2),"wrong exact identities rejected")
	_check(pc.set_pending_recovery_duration(plan.serial,plan.configuration_epoch,.24),"current unentered recovery adjusted")
	var after: Dictionary=pc.attack_plan_snapshot()
	_check(after.elapsed==plan.elapsed and after.windup_seconds==plan.windup_seconds and after.rect==plan.rect and after.damage==plan.damage,"no warning clock/geometry/damage mutation")
	_check(after.recovery_seconds==.24 and pc.melee_chain.steps[0].recovery_seconds==.16 and pc._chain_snapshot.steps[0].recovery_seconds==.16,"current copy detached from source and reusable chain snapshot")
	_check(await until(func():return pc.weapon_phase==&"recovery"),"ordinary current attack enters adjusted recovery")
	_check(not pc.set_pending_recovery_duration(plan.serial,plan.configuration_epoch,.1) and pc.attack_plan_snapshot().recovery_seconds==.24,"entered recovery duration is frozen")
	await until(func():return pc.weapon_phase==&"idle")
	_check(not pc.set_pending_recovery_duration(plan.serial,plan.configuration_epoch,.1),"completed action rejected")
	await _end()
	await begin_case("configuration isolation and malformed independent sequence")
	configure(pc); configure(npc)
	pc.melee_chain.fresh_start_steps=PackedInt32Array([3])
	_check(pc.melee_chain.snapshot()==null,"out-of-range sequence rejects whole admission")
	press(pc); await _frames(5); release(pc)
	_check(pc.attack_serial==0 and npc.attack_plan_snapshot().step_index==0,"invalid request does not commit or affect peer")
	pc.melee_chain.fresh_start_steps=PackedInt32Array([1,1,0]); await start(pc)
	_check(pc.attack_plan_snapshot().step_index==1 and npc.attack_plan_snapshot().fresh_chain_commits==0,"repeated authored indices valid and cursor is per actor")
	await _end()
	await begin_case("idle preview rejects invalid whole config and retires old retained copy")
	configure(pc)
	pc.melee_chain.steps[0].next_step=1
	pc.melee_chain.steps[0].followup_open_seconds=0.01; pc.melee_chain.steps[0].followup_close_seconds=1.0; pc.melee_chain.steps[0].followup_commit_recovery_seconds=0.01
	await start(pc); await until(func():return pc.weapon_phase==&"idle")
	_check(pc.attack_plan_snapshot().step_index==1,"live retained preview chooses real follow-up")
	var replacement: Resource=pc.melee_chain.duplicate(true); replacement.steps[0].step_label="New opening"; pc.melee_chain=replacement
	_check(pc.attack_plan_snapshot().step_index==0 and pc.attack_plan_snapshot().step_label=="New opening","same-frame source replacement cannot expose retired retained tuning")
	pc.melee_chain.chain_id=&""
	_check(not pc.attack_plan_snapshot().valid,"invalid whole chain cannot promise a valid idle plan")
	pc.melee_chain=preload("res://demo/resources/warden_melee.tres").duplicate(true)
	pc.melee_input_profile=preload("res://combat_pc/resources/held_charge.tres").duplicate(true)
	_check(pc.attack_plan_snapshot().step_label==pc.melee_input_profile.charge_starter.step_label,"held-charge idle preview uses actual starter")
	await _frames(2); await start(pc)
	_check(pc.attack_plan_snapshot().step_label==pc.melee_input_profile.charge_starter.step_label and pc.attack_plan_snapshot().fresh_chain_commits==0,"charge commit is excluded from fresh independent sequence")
	await _end()
	await begin_case("queued preview is not commit-time selection authority"); configure(pc)
	var queued: Array[int]=[]
	pc.movement_event.connect(func(kind,payload):
		if kind==&"chain_input_queued" and queued.is_empty():
			queued.append(payload.step_index)
			pc.melee_chain.fresh_start_steps=PackedInt32Array([1,0]))
	await start(pc)
	_check(queued==[0] and pc.attack_plan_snapshot().step_index==1 and pc.attack_plan_snapshot().fresh_chain_commits==1,"validated latest configuration selects step once at true commitment")
	await _end()
	await health_scope_cases()
	print("SHARED ATTACK PLAN %d Hz: %d scenarios, %d checks, %d failures" % [hz,scenarios.size(),checks,failures.size()])
	for failure in failures: printerr(failure)
	FileAccess.open("res://simulation/evidence/warden_attack_plan_%d.json" % hz,FileAccess.WRITE).store_string(JSON.stringify({"hz":hz,"scenarios":scenarios,"checks":checks,"failures":failures},"  "))
	quit(0 if failures.is_empty() else 1)
func health_scope_cases() -> void:
	for operation in ["ordinary","nested","equal_reset","rebind","actor_reset"]:
		await begin_case("Health synchronous receipt API / "+operation)
		var store: Node=pc.get_node("Health")
		var seen: Array[Dictionary]=[]; var valid: Array[bool]=[]; var depth: Array[int]=[0]
		store.damage_processed.connect(func(receipt):
			seen.append(receipt)
			valid.append(store.damage_receipt_is_current(receipt))
			_check(not store.damage_receipt_is_current(receipt.duplicate(true)),"equal copied receipt never authenticates")
			if depth[0]>0: return
			depth[0]+=1
			match operation:
				"nested": pc.receive_attack({"amount":1.0,"impulse":Vector2.ZERO,"hitpause":0.0})
				"equal_reset": store.maximum_health=store.current_health; store.reset_to_full()
				"rebind": store.bind_actor(pc)
				"actor_reset": pc.reset_actor(Vector2(80,200),1)
			_check(store.damage_receipt_is_current(receipt)==(operation=="ordinary"),"notification authority retired by nested/change/binding/generation event"))
		pc.receive_attack({"amount":1.0,"impulse":Vector2.ZERO,"hitpause":0.0})
		_check(valid.size()==(2 if operation=="nested" else 1) and valid.all(func(x):return x),"each genuine synchronous delivery is current at entry")
		_check(seen.all(func(x):return not store.damage_receipt_is_current(x)),"all receipt authority ends on signal return")
		_check(store.current_health==(28.0 if operation=="nested" else (30.0 if operation=="actor_reset" else 29.0)),"additive accessor does not change default Health debit/reset")
		await _end()
