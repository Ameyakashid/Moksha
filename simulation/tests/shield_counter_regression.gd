extends "res://simulation/tests/incoming_strike_regression.gd"
## Timed ordinary raw input drives real incoming sweep and outgoing counter ray.
## Callback/forgery tests are labelled boundary probes, never successful contacts.
const Counter = preload("res://simulation/components/shield_counter_receiver.tscn")
const CounterProbe = preload("res://simulation/tests/counter_capture_probe.gd")
var counters: Array[Dictionary] = []
var health_events: Array[Dictionary] = []
var noise_events: Array[Dictionary] = []
func _actor(at: Vector2, mode: String, facing := 1) -> Node2D:
	var actor := super._actor(at, mode, facing)
	actor.get_node("BodyShape/IncomingStrikeReceiver").counterable = true
	actor.get_node("ShieldCounterReceiver").counter_resolved.connect(func(receipt): counters.append(receipt.duplicate(true)))
	actor.get_node("NoiseRelay").forwarded.connect(func(receipt): noise_events.append(receipt.duplicate(true)))
	actor.get_node("Health").damage_processed.connect(func(receipt): health_events.append(receipt.duplicate(true)))
	return actor
func _begin(next: String, lm := "PC", rm := "NPC", distance := 36.0) -> void:
	counters = []
	health_events = []
	noise_events = []
	await super._begin(next, lm, rm, distance)
func _counter(actor: Node) -> Node: return actor.get_node("ShieldCounterReceiver")
func _parry(attacker: Node, defender: Node) -> void:
	_request(defender, {"shield":true})
	await _attack(attacker)
	await _until(func(): return not receipts.is_empty() or not counters.is_empty())
	await _frames(2)
func _probe(actor: Node) -> Node:
	var old := _counter(actor)
	old.unbind()
	old.get_parent().remove_child(old)
	old.queue_free()
	var probe := Counter.instantiate()
	probe.set_script(CounterProbe)
	actor.add_child(probe)
	probe.counter_resolved.connect(func(receipt): counters.append(receipt.duplicate(true)))
	return probe
func _run() -> void:
	for pair in [["PC","NPC"],["NPC","PC"],["NPC","NPC"]]:
		for direction in [1,-1]:
			await _begin("actual %s to %s counter direction%d" % [pair[0],pair[1],direction],pair[0],pair[1])
			var attacker := left if direction == 1 else right
			var defender := right if direction == 1 else left
			await _parry(attacker,defender)
			_check(_health(attacker) == 27 and _health(defender) == 30, "exact configured three damage and zero parry loss")
			_check(counters.size() == 1 and counters[0].amount == 3 and counters[0].outcome == &"hurt", "one actual counter Health receipt")
			_check(receipts.size() == 1 and receipts[0].outcome == &"parried" and receipts[0].counter_confirmed, "completed defender parry survives attacker retirement")
			_check(attacker.main_action == &"hurt" and attacker.velocity.x * direction < 0 and not attacker.is_strike_current(attacker.attack_serial), "existing controller owns recoil and strike cancellation")
			_check(defender.get_node("ShieldContactAdapter").confirmed_counters == 1 and health_events.size() == 2, "independent confirmed effect and Health observers")
			_check(attacker.get_node("NoiseRelay").forwarded_count > 0 and defender.get_node("NoiseRelay").forwarded_count > 0, "real committed parry/hurt noise")
			var parry_noise := noise_events.filter(func(event): return event.actor_id==defender.get_instance_id() and event.kind==&"parry")
			var hurt_noise := noise_events.filter(func(event): return event.actor_id==attacker.get_instance_id() and event.kind==&"hurt")
			_check(parry_noise.size()==1 and hurt_noise.size()==1, "one exact committed parry and counter-hurt sound")
			_check(health_events.filter(func(event): return event.actor_id==defender.get_instance_id() and event.outcome==&"parried" and event.applied==0).size()==1, "one exact zero-damage defender Health observation")
			await _frames(ceili(hz*.3))
			_check(counters.size() == 1 and receipts.size() == 1, "no repeat or continued sampled sweep")
			await _end()
	await _negative_counter_cases()
	await _lifecycle_counter_cases()
	await _forgery_counter_cases()
	await _terminal_counter_cases()
	await _composition_counter_cases()
	await _receipt_callback_cases()
	print("SHARED SHIELD COUNTER %d Hz: %d scenarios, %d checks, %d failures" % [hz,scenarios.size(),checks,failures.size()])
	for failure in failures: printerr(failure)
	var report := {"hz":hz,"scenarios":scenarios,"checks":checks,"failures":failures,"execution":"Actual raw-input parry, melee sweep and physical counter ray; malformed/lifecycle probes labelled."}
	FileAccess.open("res://simulation/evidence/counter_%d.json" % hz,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit(0 if failures.is_empty() else 1)
func _negative_counter_cases() -> void:
	for condition in ["disabled","removed","counterable_off","range","wall","no_shield","guard","rear"]:
		await _begin("actual rejection / " + condition,"NPC","PC")
		match condition:
			"disabled": _counter(left).enabled = false
			"removed": _counter(left).queue_free()
			"counterable_off": _receiver(right).counterable = false
			"range": right.shield_profile.counter_range = 1.0
			"wall":
				# Counter-only terrain layer: ordinary incoming sweep stays clear.
				_surface(Vector2(220,174),Vector2(2,52),128)
				right.get_node("ShieldContactAdapter").obstruction_mask = 129
			"no_shield":
				var caps := Capabilities.new()
				caps.can_shield = false
				right.get_node("IntentDriver").configure_capabilities(caps)
			"rear": right.reset_actor(right.position,1)
		await _frames(3)
		_request(right,{"shield":true})
		if condition == "guard": await _frames(ceili(hz*.3))
		await _attack(left)
		_check(await _until(func(): return not receipts.is_empty()), "real incoming contact still completes")
		_check(counters.is_empty() and _health(left) == 30 and right.get_node("ShieldContactAdapter").confirmed_counters == 0, "no unreachable or disabled effect")
		var outcome: StringName = &"hurt" if condition in ["rear","no_shield"] else (&"guarded" if condition == "guard" else &"parried")
		_check(receipts.size() == 1 and receipts[0].outcome == outcome, "incoming defense remains independently correct")
		await _end()
func _lifecycle_counter_cases() -> void:
	for operation in ["target_reset","defender_reset","receiver_toggle","receiver_unbind","receiver_remove","receiver_replace","incoming_remove","shape_remove","shape_disable","adapter_toggle","adapter_rebind","mask_change","target_process","defender_process","defender_physics","shape_replace","shape_transform","target_detach","defender_detach","cross_world","pause_cycle","always_pause_cycle"]:
		await _begin("counter capture callback / " + operation,"NPC","PC")
		var probe := _probe(left)
		var called: Array[bool] = []
		if operation == "always_pause_cycle":
			left.process_mode = Node.PROCESS_MODE_ALWAYS
			right.process_mode = Node.PROCESS_MODE_ALWAYS
		probe.after_capture = func():
			if not called.is_empty(): return
			called.append(true)
			match operation:
				"target_reset": left.reset_actor(left.position,1)
				"defender_reset": right.reset_actor(right.position,-1)
				"receiver_toggle": probe.enabled=false; probe.enabled=true
				"receiver_unbind": probe.unbind()
				"receiver_remove": probe.queue_free()
				"receiver_replace": probe.unbind(); probe.queue_free(); left.add_child(Counter.instantiate())
				"incoming_remove": _receiver(left).queue_free()
				"shape_remove": _receiver(left).get_node("Shape").queue_free()
				"shape_disable": left.get_node("BodyShape").disabled=true
				"adapter_toggle": right.get_node("ShieldContactAdapter").enabled=false; right.get_node("ShieldContactAdapter").enabled=true
				"adapter_rebind": right.get_node("ShieldContactAdapter").bind_actor(left)
				"mask_change": right.get_node("ShieldContactAdapter").obstruction_mask=3
				"target_process": left.set_physics_process(false)
				"defender_process": right.process_mode=Node.PROCESS_MODE_DISABLED
				"defender_physics": right.set_physics_process(false)
				"shape_replace":
					var replacement := RectangleShape2D.new()
					replacement.size = Vector2(18,36)
					left.get_node("BodyShape").shape=replacement
				"shape_transform": _receiver(left).position.x=2
				"target_detach": world.remove_child(left); world.add_child(left)
				"defender_detach": world.remove_child(right); world.add_child(right)
				"cross_world":
					var viewport := SubViewport.new()
					viewport.world_2d=World2D.new()
					world.add_child(viewport)
					left.reparent(viewport)
				"pause_cycle","always_pause_cycle": paused=true; paused=false
		await _frames(3)
		await _parry(left,right)
		_check(called == [true], "actual parry reaches capture hook")
		_check(_health(left) == 30 and counters.is_empty(), "retired token cannot authorize target response")
		await _end()
func _forgery_counter_cases() -> void:
	for field in ["damage","impulse","defender_origin","counter_contact_position","defender","source","target_id","shield_serial","attack_key","counter_ticket","counter_generation"]:
		await _begin("permit forged field / " + field,"NPC","PC")
		var probe := _probe(left)
		var denied: Array[bool] = []
		probe.before_receive = func(packet: Dictionary):
			var bad := packet.duplicate(true)
			match field:
				"damage": bad[field]=999.0
				"impulse","defender_origin","counter_contact_position": bad[field]=Vector2(999,999)
				"defender","source": bad[field]=left if field=="defender" else right
				"attack_key": bad[field]="forged"
				"counter_generation": bad[field]={}
				_: bad[field]=999
			probe.before_receive=Callable()
			denied.append(not probe.receive_shield_counter(bad).get("accepted",false))
		await _frames(3)
		await _parry(left,right)
		_check(denied == [true] and _health(left) == 27 and counters.size() == 1, "forged packet rejected; original actual contact applies once")
		var retained: Dictionary = probe.captured.duplicate(true)
		_check(not probe.receive_shield_counter(retained).get("accepted",false) and _health(left)==27, "out-of-scope replay rejected")
		await _end()
	for field in ["damage","impulse","source","target_id","defender_origin","max_range","attack_key"]:
		await _begin("canonical request alteration / " + field,"NPC","PC")
		var adapter: Node = right.get_node("ShieldContactAdapter")
		adapter.bind_actor(null)
		right.shield_effect_requested.connect(func(owner,request):
			var bad: Dictionary = request.duplicate(true)
			match field:
				"damage","max_range": bad[field]=999.0
				"impulse","defender_origin": bad[field]=Vector2(999,999)
				"source": bad[field]=right
				"attack_key": bad[field]="forged"
				_: bad[field]=999
			adapter.resolve_effect(owner,bad))
		adapter.actor=right
		await _parry(left,right)
		_check(_health(left)==30 and counters.is_empty() and receipts.size()==1 and receipts[0].outcome==&"parried", "altered canonical request has no authority; parry survives")
		await _end()
func _terminal_counter_cases() -> void:
	await _begin("actual lethal counter Health Defeat Noise","NPC","PC")
	right.shield_profile.counter_damage=40
	var defeats: Array[bool]=[]
	left.get_node("DefeatResponse").defeat_started.connect(func(): defeats.append(true))
	await _parry(left,right)
	_check(_health(left)==0 and left.is_defeated() and defeats==[true], "one bounded lethal debit and defeat")
	_check(counters.size()==1 and counters[0].amount==30 and receipts.size()==1 and receipts[0].outcome==&"parried", "lethal counter and zero-loss defender receipts survive")
	_check(right.get_node("ShieldContactAdapter").confirmed_counters==1 and _counter(left).capture_counter_generation().is_empty(), "completed lethal confirmation; dead host rejects new effect")
	await _end()
	for operation in ["target_reset","defender_reset","receiver_unbind","health_unbind"]:
		await _begin("committed counter hurt callback / "+operation,"NPC","PC")
		var called: Array[bool]=[]
		left.movement_event.connect(func(kind,_payload):
			if kind!=&"hurt_started" or not called.is_empty(): return
			called.append(true)
			match operation:
				"target_reset": left.reset_actor(left.position,1)
				"defender_reset": right.reset_actor(right.position,-1)
				"receiver_unbind": _counter(left).unbind()
				"health_unbind": left.get_node("Health").unbind_actor()
		)
		await _parry(left,right)
		_check(called==[true], "actual counter enters existing hurt owner")
		_check(_health(left)==(30 if operation in ["target_reset","health_unbind"] else 27), "target-life/Health fences prevent new-life debit")
		_check(counters.is_empty(), "retired counter diagnostics suppressed")
		await _end()

func _composition_counter_cases() -> void:
	await _begin("actual first parry ends multi-target sweep", "raw", "raw")
	var third := _actor(Vector2(237,200),"raw",-1)
	await _frames(4)
	_request(right,{"shield":true})
	_request(third,{"shield":true})
	await _attack(left)
	await _frames(ceili(hz*.3))
	_check(_health(left)==27 and _health(right)==30 and _health(third)==30, "one counter cancels attacking owner")
	_check(counters.size()==1 and receipts.size()==1 and left.get_node("ContactAdapter").confirmed_contacts==1, "retired source never continues captured sweep")
	await _end()
	await _begin("actual crouching attacker live hurtbox", "raw", "raw")
	_request(left,{"down":1.0})
	await _frames(5)
	_check(left.crouched, "raw input produces smaller live body")
	_request(right,{"shield":true})
	_request(left,{"down":1.0,"attack":true})
	await _frames(1)
	_request(left,{"down":1.0})
	await _until(func(): return not counters.is_empty())
	_check(counters.size()==1 and _health(left)==27 and _health(right)==30, "actual ray contacts current shared crouched shape")
	await _end()
	await _begin("absent attacking capability", "NPC", "PC")
	var caps := Capabilities.new()
	caps.can_attack=false
	left.get_node("IntentDriver").configure_capabilities(caps)
	await _frames(3)
	await _parry(left,right)
	_check(_health(left)==30 and _health(right)==30 and counters.is_empty() and receipts.is_empty(), "absent attack cannot create a parry or counter")
	await _end()
	for stage in ["health_changed","damage_processed","defeat_started"]:
		for operation in ["target_reset","defender_reset","receiver_unbind","adapter_toggle"]:
			await _begin("completed counter callback / "+stage+"/"+operation,"NPC","PC")
			right.shield_profile.counter_damage=40.0 if stage=="defeat_started" else 3.0
			var called: Array[bool]=[]
			var retire := func():
				if not called.is_empty(): return
				called.append(true)
				match operation:
					"target_reset": left.reset_actor(left.position,1)
					"defender_reset": right.reset_actor(right.position,-1)
					"receiver_unbind": _counter(left).unbind()
					"adapter_toggle": right.get_node("ShieldContactAdapter").enabled=false; right.get_node("ShieldContactAdapter").enabled=true
			if stage=="health_changed": left.get_node("Health").health_changed.connect(func(_a,_b): retire.call())
			elif stage=="damage_processed": left.get_node("Health").damage_processed.connect(func(_event): retire.call())
			else: left.get_node("DefeatResponse").defeat_started.connect(retire)
			await _parry(left,right)
			_check(called==[true], "actual completed debit reaches callback")
			_check(_health(left)==(30 if operation=="target_reset" else (0 if stage=="defeat_started" else 27)), "old completed damage never debits reset life")
			_check(counters.is_empty() and right.get_node("ShieldContactAdapter").confirmed_counters==0, "retired feedback/confirmation suppressed without undoing debit")
			await _end()

func _receipt_callback_cases() -> void:
	for operation in ["target_reset","receiver_unbind","incoming_remove","defender_reset","adapter_toggle"]:
		await _begin("completed counter receipt callback / "+operation,"NPC","PC")
		_counter(left).counter_resolved.connect(func(_event):
			match operation:
				"target_reset": left.reset_actor(left.position,1)
				"receiver_unbind": _counter(left).unbind()
				"incoming_remove": _receiver(left).queue_free()
				"defender_reset": right.reset_actor(right.position,-1)
				"adapter_toggle": right.get_node("ShieldContactAdapter").enabled=false; right.get_node("ShieldContactAdapter").enabled=true
		)
		await _parry(left,right)
		_check(counters.size()==1 and counters[0].amount==3, "completed immutable counter value survives its observer")
		_check(_health(left)==(30 if operation=="target_reset" else 27), "applied old-life debit remains distinct from reset")
		var report: Dictionary=right.get_node("ShieldContactAdapter").last_report
		_check(report.get("applied",false) and not report.get("confirmed",false), "retired-after-receipt effect stays applied but unconfirmed")
		await _end()
