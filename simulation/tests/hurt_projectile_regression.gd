extends "res://simulation/tests/projectile_regression.gd"
## Real ordinary emission, timed shield reflection, and swept return contacts.
var health_facts: Array[Dictionary]=[]
var brace_events: Array[Dictionary]=[]
func _actor(at: Vector2,mode: String,facing := 1) -> Node2D:
	var actor := super._actor(at,mode,facing)
	actor.get_node("Health").damage_processed.connect(func(receipt): health_facts.append(receipt.duplicate(true)))
	actor.movement_event.connect(func(kind,payload):
		if kind==&"hurt_braced": brace_events.append(payload.merged({"actor_id":actor.get_instance_id()})))
	return actor
func _begin(next: String,lm := "RAW",rm := "RAW",distance := 180.0) -> void:
	health_facts=[]; brace_events=[]
	await super._begin(next,lm,rm,distance)
func _brace(actor: Node,phase: StringName=&"active") -> void:
	var step: Resource=actor.melee_chain.steps[0]
	step.hurt_protected_phases=PackedStringArray(["windup","active"])
	step.active_seconds=2.5
	if phase==&"windup": step.windup_seconds=2.0
func _reflect() -> bool:
	await _attack(left)
	if not await _until(func(): return not shots.is_empty()): return false
	if not await _until(func(): return is_instance_valid(carriers[0]) and carriers[0].position.x>right.position.x-38): return false
	_request(right,{"shield":true})
	return await _until(func(): return contacts.size()>=2)
func _run() -> void:
	for mode in ["PC","NPC"]:
		for duration in [0.5,0.699999,0.7,0.78]:
			await _begin("real "+mode+" braced reflected return "+str(duration),mode,"NPC")
			_brace(left); _emitter(left).profile.return_stun_seconds=duration
			_check(await _reflect(),"genuine parry reflects same carrier into actual source body")
			_check(contacts.size()==2 and contacts[0].outcome==&"parried" and contacts[0].reflection_confirmed and contacts[1].reflected,"separate reflection and return collision facts")
			_check(_health(left)==28 and _health(right)==30 and contacts[1].amount==2,"full return damage exactly once")
			var protects: bool=duration<0.7
			_check((left.main_action!=&"hurt" and left.weapon_phase==&"active") if protects else (left.main_action==&"hurt" and left.weapon_phase==&"idle"),"role-neutral strict duration threshold on genuine return")
			var facts := health_facts.filter(func(receipt): return receipt.actor_id==left.get_instance_id())
			_check(facts.size()==1 and bool(facts[0].braced)==protects and bool(facts[0].applied_recoil)!=protects,"completed Health retains truthful response flags")
			_check(brace_events.size()==(1 if protects else 0),"no false braced/recoil event")
			await _end()
	for mode in ["PC","NPC"]:
		await _begin("real outbound shot into "+mode+" braced windup","NPC",mode)
		_brace(right,&"windup"); _emitter(right).enabled=false
		await _attack(left); await _until(func(): return not shots.is_empty())
		await _attack(right)
		_check(right.weapon_phase==&"windup","ordinary target input establishes protected windup")
		_check(await _until(func(): return not contacts.is_empty()),"real outbound sweep contacts protected target")
		_check(_health(right)==29 and right.weapon_phase==&"windup" and right.main_action!=&"hurt","full outbound damage without action cancellation")
		_check(health_facts.size()==1 and health_facts[0].braced==1 and right.hitpause_remaining>0,"Health and existing shared hitpause confirmed")
		await _end()
	await _begin("real lethal reflected return while protected","NPC","NPC")
	_brace(left); left.melee_chain.steps[0].damage=45
	var deaths: Array[bool]=[]; left.get_node("DefeatResponse").defeat_started.connect(func(): deaths.append(true))
	_check(await _reflect(),"genuine lethal returned collider")
	_check(_health(left)==0 and left.is_defeated() and left.weapon_phase==&"idle" and deaths==[true],"lethal full Health clamp defeats and retires protected action")
	_check(contacts.size()==2 and contacts[1].amount==30 and contacts[1].accepted,"source retirement preserves completed actual lethal receipt")
	await _end()
	await _begin("real return uses isolated committed protection snapshot","NPC","NPC")
	_brace(left)
	await _attack(left); await _until(func(): return not shots.is_empty())
	left.melee_chain.steps[0].hurt_protected_phases=PackedStringArray()
	left.melee_chain.steps[0].hurt_interrupt_seconds=0.0
	await _until(func(): return is_instance_valid(carriers[0]) and carriers[0].position.x>right.position.x-38)
	_request(right,{"shield":true})
	_check(await _until(func(): return contacts.size()==2),"actual reflection return after source config edit")
	_check(_health(left)==28 and left.weapon_phase==&"active" and brace_events.size()==1,"in-place source edit affects future action only")
	await _end()
	print("SHARED HURT PROJECTILE %d Hz: %d scenarios, %d checks, %d failures" % [hz,scenarios.size(),checks,failures.size()])
	for failure in failures: printerr(failure)
	var report := {"hz":hz,"scenarios":scenarios,"checks":checks,"failures":failures,"execution":"All successful contacts use ordinary PC/NPC input, real emission and genuine reflection/return sweep."}
	FileAccess.open("res://simulation/evidence/hurt_projectile_%d.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit(0 if failures.is_empty() else 1)
