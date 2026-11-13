extends "res://combat_pc/tests/noise_regression.gd"
func _run()->void:
	await _begin("scoped nested context")
	var retained:Array[Dictionary]=[]
	relay.forwarded.connect(func(event:Dictionary):
		_check(relay.is_forwarding_receipt(event),"identity active inside callback")
		_check(not relay.is_forwarding_receipt(event.duplicate()),"equal copy not authority")
		retained.append(event)
		if event.kind==&"outer":
			actor._commit_noise(Vector2(110,180),&"inner",.8,actor.noise_generation())
			_check(relay.is_forwarding_receipt(event),"outer restored after nested unwind"))
	actor._commit_noise(Vector2(100,180),&"outer",.8,actor.noise_generation())
	_check(retained.size()==2 and bus.event_count==2,"exact two bus deliveries")
	for event in retained:_check(not relay.is_forwarding_receipt(event),"context absent after callback")
	await _finish()
	for mode in ["disable","diagnostics","rebind","reset","remove","queue_free"]:
		await _begin(mode)
		relay.forwarded.connect(func(event:Dictionary):
			_check(relay.is_forwarding_receipt(event),"active before "+mode)
			match mode:
				"disable":relay.enabled=false
				"diagnostics":relay.reset_diagnostics()
				"rebind":relay.bind(actor,bus)
				"reset":actor.reset_actor(actor.position)
				"remove":actor.remove_child(relay)
				"queue_free":relay.queue_free()
			if is_instance_valid(relay):_check(not relay.is_forwarding_receipt(event),"invalid after "+mode))
		actor._commit_noise(Vector2(100,180),&"probe",.8,actor.noise_generation())
		_check(bus.event_count==1,"bus preserved "+mode)
		if mode=="remove":relay.free()
		await _finish()
	print("RELAY_CONTEXT "+JSON.stringify({"checks":checks.size(),"failures":failures,"hz":hz}))
	quit(0 if failures.is_empty() else 1)
