extends "res://campaign/quality/nov6_full_campaign_route.gd"
## External normal-title campaign observer. No initial district/sight fixture.
const Sink=preload("res://campaign/quality/nov12_report_sink.gd")
var destination:=""
var requested_ending:="public_record"
var clinic_closed_seen:=false
var clinic_roof_crossed:=false
var clinic_open_seen:=false
var clinic_street_crossed:=false
var previous_clinic_position:=Vector2.ZERO
var clinic_observed:=false
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):destination=arg.trim_prefix("--report=")
		if arg.begins_with("--ending="):requested_ending=arg.trim_prefix("--ending=")
	var lens_argument:="neutral"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lens="):lens_argument=arg.trim_prefix("--lens=")
	var invalid:String=Sink.validate(destination)
	if lens_argument not in ["neutral","strength","agility"]:invalid="Invalid lens"
	if not invalid.is_empty() or requested_ending not in ["public_record","local_custody"]:
		push_error("Invalid report or ending: "+invalid);quit(2);return
	super._initialize()
func decide()->Dictionary:
	if str(host.sectors[host.sector].id)=="city_clinic":
		var gate:Node
		for node in host.room.get_children():
			if node.get_script()==preload("res://campaign/logic/objective_door.gd") and absf(node.position.x-2850)<1:gate=node
		if is_instance_valid(gate):
			if not host.goal_done("generator") and not gate.opened:clinic_closed_seen=true
			if host.goal_done("generator") and gate.opened:clinic_open_seen=true
			var p:Vector2=host.player.position
			if clinic_observed and previous_clinic_position.x<2850 and p.x>=2850:
				if not gate.opened and p.y<0 and previous_clinic_position.y<0:clinic_roof_crossed=true
				if gate.opened and p.y>100 and previous_clinic_position.y>100:clinic_street_crossed=true
			previous_clinic_position=p;clinic_observed=true
	return super.decide()
func navigate(target:Vector2,data:Dictionary)->Dictionary:
	# Established Strength observer hint: ordinary ladder ascent, not actor changes.
	if requested_lens=="strength" and str(data.id)=="l2_stamping_galleries" and not host.goal_done("die") and (host.player.position.y>110 or host.player.main_action==&"climb"):
		return {"target":Vector2(1340,100),"up":true,"jump":false,"drop":false}
	if str(data.id)=="city_clinic" and host.goal_done("generator") and not clinic_street_crossed:
		var fighting:bool=host.enemies.any(func(enemy):return is_instance_valid(enemy) and not enemy.dead and target.distance_to(enemy.position)<2 and host.player.position.distance_to(enemy.position)<115)
		if not fighting:
			var old_have_goal:=have_goal;have_goal=false
			var result:Dictionary=super.navigate(Vector2(2960,300),data)
			have_goal=old_have_goal
			return result
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
		if host.state=="complete":break
		var id:String=host.sectors[host.sector].id
		if current_id!=id:
			current_id=id;district_id=id;residential_index=0;entered_frame=frame;goals_seen.clear();interaction_tick=-999
			choice_done=host.blind
			begin_sector()
			print("CAMPAIGN_ENTER ",host.sector+1," ",id," time=",host.elapsed," blind=",host.blind)
		if frame-entered_frame>hz*full_timeout:
			failures.append("District timed out: "+id);break
		if host.state=="dead":
			failures.append("Death in "+id+" at "+str(host.player.position));break
		elif host.state=="archive":await key(KEY_E)
		elif host.state=="choice":
			await key(KEY_J if sacrifice else KEY_K);choice_done=true
			events.append({"event":"actual_sight_menu_choice","requested_trade":sacrifice,"actual_blind":host.blind,"hearing_retained":host.hearing_retained,"district":id,"frame":frame})
		elif host.state=="hearing_choice":
			await key(KEY_K) # Historical route explicitly retains hearing.
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
	var drift:Array[String]=[]
	for path in full_sources:
		if FileAccess.get_sha256(path)!=full_sources[path]:drift.append(path)
	if not drift.is_empty():failures.append("Source changed while run was active")
	if host.state=="complete" and host.blind!=sacrifice:failures.append("Requested actual sight decision did not persist")
	if host.state=="complete":
		if host.lens!=requested_lens:failures.append("Wrong selected lens")
		if not host.hearing_retained:failures.append("Historical route unexpectedly traded hearing")
		if host.upgrades.size()!=4:failures.append("Expected four genuine level upgrade choices")
		if host.metrics.size()!=host.sectors.size():failures.append("District metric count does not match campaign")
		else:
			for i in host.metrics.size():
				if int(host.metrics[i].sector)!=i:failures.append("District order mismatch at %d"%i)
		if host.level_receipts.map(func(receipt):return int(receipt.level))!=[1,2,3,4,5]:failures.append("Five level completion receipts missing")
		if host.deaths!=0:failures.append("Unexpected death/retry")
		if objective_receipts.size()!=host.sectors.size():failures.append("Missing actual open-gate objective receipt")
	if host.state!="complete":failures.append("Campaign did not naturally complete")
	if host.sectors.size()!=32:failures.append("Expected32 districts")
	if host.campaign_ending!=requested_ending:failures.append("Wrong natural ending")
	if not (clinic_closed_seen and clinic_roof_crossed and clinic_open_seen and clinic_street_crossed):failures.append("Clinic shortcut proof incomplete")
	for data in host.sectors:
		if not objective_receipts.has(data.id):
			failures.append("Missing district receipt: "+str(data.id));continue
		var required:Array=data.get("objectives",[]).filter(func(goal):return not goal.get("optional",false)).map(func(goal):return goal.id)
		var observed:Array=objective_receipts[data.id].required_goals
		if observed.map(func(goal):return goal.id)!=required or observed.any(func(goal):return not goal.completed):failures.append("Invalid required objectives: "+str(data.id))
	var report:Dictionary={"passed":host.state=="complete" and failures.is_empty(),"completed":host.state=="complete","hz":hz,"lens":requested_lens,"requested_sight_trade":sacrifice,"actual_blind":host.blind,"hearing_retained":host.hearing_retained,"actual_upgrade_choices":host.upgrades,"active_seconds":host.elapsed,"levels":host.level_receipts,"district_metrics":host.metrics,"ending":host.campaign_ending,"deaths":host.deaths,"kills":host.kills,"events":events,"damage_receipts":damage_receipts,"objective_receipts":objective_receipts,"last_trace":trace,"source_hashes":full_sources,"source_drift":drift,"failures":failures,"human_duration_validated":false,"method":"Normal title lens key, Enter, opening skip; raw PC input plus idle-dispatched ordinary E/Q/choice/upgrade/finale keys. No gameplay state/position/health/enemy writes, no forced goals. Layout-aware bot timing is not human timing."}
	report["requested_ending"]=requested_ending
	report["clinic_shortcut"]={"closed_seen":clinic_closed_seen,"roof_crossed":clinic_roof_crossed,"open_seen":clinic_open_seen,"street_crossed":clinic_street_crossed}
	var output_error:String=Sink.write_report(destination,report)
	var result_code:=0 if report.passed else 1
	if not output_error.is_empty():push_error(output_error);result_code=2
	print("NOV12_FULL_CAMPAIGN_RESULT ",JSON.stringify({"passed":report.passed,"completed":report.completed,"seconds":host.elapsed,"failures":failures,"output_error":output_error}))
	host.free();input_dispatch.free()
	await process_frame
	quit(result_code)
