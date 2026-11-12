extends "res://campaign/quality/nov12_thermal_route_base.gd"
var outbound:="exposed"
var phase:=0
var point_index:=0
var push_frames:=0
var blocked_proven:=false
var outbound_proven:=false
var return_proven:=false
var previous:=Vector2.ZERO
var have_previous:=false
var service_done:=false
var thermal_health_start:=0.0
var thermal_seconds_start:=0.0
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--outbound="):outbound=arg.trim_prefix("--outbound=")
	if outbound not in ["exposed","service"]:push_error("Invalid outbound");quit(2);return
	super._initialize()
func decide()->Dictionary:
	if district_id=="l2_thermal_foundry":
		var p:Vector2=host.player.position
		if not have_previous:
			thermal_health_start=host.health.current_health;thermal_seconds_start=host.elapsed
		var door:Node
		for node in host.room.get_children():
			if node.get_script()==preload("res://campaign/logic/objective_door.gd") and absf(node.position.x-3340)<1:door=node
		if is_instance_valid(door) and have_previous:
			if not door.opened and previous.x<3340 and p.x>=3340:
				if outbound=="exposed" and p.y>240:outbound_proven=true
				if outbound=="service" and p.y<0:outbound_proven=true
			if door.opened and previous.x>3340 and p.x<=3340 and absf(p.y-120)<55:return_proven=true
		previous=p;have_previous=true;service_done=host.goal_done("service")
		if phase==1:
			push_frames+=1
			if push_frames>=30:
				blocked_proven=is_instance_valid(door) and not door.opened and p.x<3340 and p.x>3290 and absf(p.y-120)<10
				if not blocked_proven:failures.append("Closed connector did not physically block middle-height push")
				phase=2;point_index=0
			return {"right":1.0}
		if outbound=="service" and phase==2 and not service_done and host._near(Vector2(3220,-90),48):
			if frame-interaction_tick>=12:interaction_tick=frame;queue_key(KEY_E)
			return {}
	return super.decide()
func navigate(target:Vector2,data:Dictionary)->Dictionary:
	if str(data.id)=="l2_thermal_foundry" and host.goal_done("ceramic") and host.goal_done("return"):
		# A short jump beneath the east gallery can hit its underside. Recover via
		# the authored ladder using ordinary movement/Up instead of rewriting physics.
		if phase==3 and host.goal_done("feed") and point_index==0 and host.player.position.y>190:
			return {"target":Vector2(3550,180),"up":true,"jump":false,"drop":false}
		var points:Array=[]
		if phase==0:points=[Vector2(3310,120)]
		elif phase==2:
			points=[Vector2(3280,300),Vector2(3460,300),Vector2(3550,180)] if outbound=="exposed" else [Vector2(3210,-90),Vector2(3430,-90),Vector2(3550,180)]
		elif phase==3 and host.goal_done("feed"):points=[Vector2(3510,180),Vector2(3360,120),Vector2(3200,120)]
		if not points.is_empty():
			var p:Vector2=host.player.position
			if point_index<points.size() and p.distance_to(points[point_index])<28:
				point_index+=1
				if point_index==points.size():
					phase+=1;point_index=0
					return stationary_plan(host.player.position)
			var old:=have_goal;have_goal=false
			var plan:Dictionary=super.navigate(points[point_index],data)
			have_goal=old;return plan
	return super.navigate(target,data)
func run()->void:
	for directory in ["res://campaign","res://demo","res://simulation","res://combat_pc"]:collect_sources(directory)
	full_sources[get_script().resource_path]=FileAccess.get_sha256(get_script().resource_path)
	full_sources["res://combat_pc/player.gd"]=FileAccess.get_sha256("res://combat_pc/player.gd")
	input_dispatch=InputDispatch.new();input_dispatch.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(input_dispatch)
	host=load(scene_path).instantiate();root.add_child(host);host.save_enabled=false
	await key(KEY_2 if requested_lens=="strength" else KEY_3 if requested_lens=="agility" else KEY_1)
	await key(KEY_ENTER)
	await key(KEY_ENTER) # ordinary player skip of opening, not a state write
	var current_id:=""
	var entered_frame:=0
	for tick in range(hz*full_timeout*host.sectors.size()):
		frame=tick
		if host.sector>10:break
		var id:String=host.sectors[host.sector].id
		if current_id!=id:
			current_id=id;district_id=id;residential_index=0;entered_frame=frame;goals_seen.clear();interaction_tick=-999
			choice_done=host.blind
			begin_sector()
			print("CAMPAIGN_ENTER ",host.sector+1," ",id," time=",host.elapsed," blind=",host.blind)
			if id=="l2_thermal_foundry":print("THERMAL_MOVIE_START_FRAME ",Engine.get_frames_drawn())
		if frame-entered_frame>hz*full_timeout:
			failures.append("District timed out: "+id);break
		if host.state=="dead":
			failures.append("Death in "+id+" at "+str(host.player.position));break
		elif host.state=="archive":await key(KEY_E)
		elif host.state=="choice":
			await key(KEY_J if sacrifice else KEY_K);choice_done=true
			events.append({"event":"actual_sight_menu_choice","requested_trade":sacrifice,"actual_blind":host.blind,"district":id,"frame":frame})
		elif host.state=="upgrade":
			area_samples.append({"level":host.sectors[host.sector].level,"seconds":host.level_seconds.get(str(host.sectors[host.sector].level),0),"blind":host.blind})
			await key([KEY_J,KEY_K,KEY_L,KEY_J][host.upgrades.size()])
		elif host.state=="final_choice":await key(KEY_J if requested_ending=="public_record" else KEY_K)
		elif host.state=="playing":
			host.input_override=decide()
			if host.room.gate_open and not objective_receipts.has(id):
				objective_receipts[id]={"active_seconds":host.elapsed,"required_goals":host.goals.filter(func(goal):return not goal.optional).map(func(goal):return {"id":goal.objective_id,"completed":goal.completed,"kind":goal.kind}),"relays":host.relay_states.duplicate(),"freight_latched":host.room.freight_receiver.is_latched if is_instance_valid(host.room.freight_receiver) else false}
			if frame%hz==0:
				trace.append(snapshot())
				if trace.size()>40:trace.pop_front()
		await physics_frame;await process_frame
	print("THERMAL_MOVIE_END_FRAME ",Engine.get_frames_drawn())
	var drift:Array=[]
	for path in full_sources:
		if FileAccess.get_sha256(path)!=full_sources[path]:drift.append(path)
	if host.sector<=10:failures.append("Thermal district did not complete")
	if not blocked_proven or not outbound_proven or not return_proven:failures.append("Missing real gate/route crossing proof")
	if service_done!=(outbound=="service"):failures.append("Optional harness branch result incorrect")
	if host.blind!=sacrifice or host.lens!=requested_lens:failures.append("Natural lens/sight selection mismatch")
	if host.deaths!=0:failures.append("Death/retry")
	if not drift.is_empty():failures.append("Source drift")
	var report={"passed":failures.is_empty(),"failures":failures,"source_drift":drift,"source_hashes":full_sources,"lens":host.lens,"blind":host.blind,"outbound":outbound,"closed_push_blocked":blocked_proven,"outbound_crossed":outbound_proven,"open_return_crossed":return_proven,"optional_service_recovered":service_done,"deaths":host.deaths,"active_seconds":host.elapsed,"thermal_seconds":host.elapsed-thermal_seconds_start,"thermal_health_start":thermal_health_start,"objective_receipts":objective_receipts,"events":events,"last_trace":trace,"method":"Normal title, ordinary keys, route waypoints only. No position/health/goal writes."}
	var output_error:String=Sink.write_report(destination,report)
	var code:=0 if report.passed else 1
	if not output_error.is_empty():push_error(output_error);code=2
	print("THERMAL_ROUTE_RESULT ",JSON.stringify({"passed":report.passed,"failures":failures}))
	host.free();input_dispatch.free();await process_frame;quit(code)

static func stationary_plan(at:Vector2)->Dictionary:
	# Full schema consumed by the established production-input observer.
	return {"target":at,"up":false,"jump":false,"drop":false}
