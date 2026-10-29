extends SceneTree
var findings:Array[String]=[]
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	call_deferred("run")
func report(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:findings.append(label)
func run()->void:
	var mission=load("res://campaign/campaign.tscn").instantiate()
	mission.save_enabled=false
	root.add_child(mission)
	mission.start_new(true)
	paused=true
	var ids:Dictionary={}
	for d in mission.sectors:
		report(not ids.has(d.id),"unique district "+d.id);ids[d.id]=true
		var local:Dictionary={}
		for o in d.get("objectives",[]):local[o.id]=o
		for o in local.values():
			for dependency in o.get("requires",[]):report(local.has(dependency),d.id+" prerequisite exists "+dependency)
		var resolved:Array=[]
		for step in local.size()+1:
			for o in local.values():
				if o.get("requires",[]).all(func(id):return id in resolved) and not o.id in resolved:resolved.append(o.id)
		report(resolved.size()==local.size(),d.id+" acyclic dependencies")
		for door in d.get("objective_doors",[]):
			for dependency in door.get("requires",[]):report(local.has(dependency),d.id+" door prerequisite exists "+dependency)
	# Controlled component test, not a traversal or pacing claim.
	var objective=load("res://campaign/logic/objective.tscn").instantiate()
	objective.configure({"id":"test","label":"test","kind":"install","at":Vector2.ZERO,"requires":["missing"]},mission)
	mission.room.add_child(objective)
	report(not objective.interact(),"dependency rejects interaction before first physics tick")
	objective.queue_free()
	mission.lens="strength";mission._apply_build()
	var speed:float=mission.player.profile.run_speed
	var damage:float=mission.player.melee_chain.steps[0].damage
	for i in 5:mission._apply_build()
	report(is_equal_approx(speed,mission.player.profile.run_speed),"build speed idempotent")
	report(is_equal_approx(damage,mission.player.melee_chain.steps[0].damage),"build damage idempotent")
	mission.player.receive_hit({"amount":10.0,"impulse":Vector2.ZERO,"source_position":mission.player.position+Vector2(20,0)})
	var before:float=mission.health.current_health
	mission.rewards["qa/vitality"]="vitality";mission._apply_build()
	report(is_equal_approx(before,mission.health.current_health),"wounded reward does not heal")
	report(is_equal_approx(mission.health.capacity,mission.health.maximum_health),"wounded reward updates effective capacity")
	# Synthetic setup isolates repeated ordinary key delivery at a real level boundary.
	var boundary:=0
	while boundary+1<mission.sectors.size() and mission.sectors[boundary+1].level==1:boundary+=1
	mission.load_sector(boundary);paused=true
	for goal in mission.goals:goal.completed=true
	mission.relay_on=true
	if is_instance_valid(mission.room.freight_receiver):mission.room.freight_receiver.is_latched=true
	mission.room.gate_open=true
	mission.player.position=Vector2(float(mission.sectors[boundary].width)-45,float(mission.sectors[boundary].get("gate_y",300)))
	mission.interact()
	report(mission.state=="upgrade","level exit reaches upgrade")
	var e:=InputEventKey.new();e.physical_keycode=KEY_J;e.pressed=true
	mission._unhandled_key_input(e)
	var count:int=mission.upgrades.size()
	e.physical_keycode=KEY_E;mission._unhandled_key_input(e)
	e.physical_keycode=KEY_J;mission._unhandled_key_input(e)
	report(mission.upgrades.size()==count,"same-frame exit input cannot duplicate upgrade")
	print("AUDIT_FAILURES "+JSON.stringify(findings))
	quit(0 if findings.is_empty() else 1)
