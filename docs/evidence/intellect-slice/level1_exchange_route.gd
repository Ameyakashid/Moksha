extends "res://campaign/quality/nov6_full_campaign_route.gd"
## Continuous normal-title first-seven-district acceptance, not manual play.
## Only ordinary inputs; the clinic return waypoint proves the opened shortcut.
const ReportSink=preload("res://campaign/quality/nov12_report_sink.gd")
var report_destination:=""
var companion_receipts:Array=[]
var seen_companion:Dictionary={}
var disable_companion:=false
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--disable-companion":disable_companion=true
		if arg.begins_with("--report="):report_destination=arg.trim_prefix("--report=")
	var invalid:String=ReportSink.validate(report_destination)
	if not invalid.is_empty():
		push_error(invalid);quit(2);return
	super._initialize()
var clinic_closed_seen:=false
var clinic_roof_crossed:=false
var clinic_open_seen:=false
var clinic_street_crossed:=false
var previous_clinic_position:=Vector2.ZERO
var clinic_observed:=false
var finished:=false
var completion_code:=1
func decide()->Dictionary:
	for id in host.companion.director.seen:
		if not seen_companion.has(id):
			seen_companion[id]=true
			var row={"id":id,"district":host.sectors[host.sector].id,"seconds":host.elapsed,"position":str(host.player.position),"blind":host.blind}
			companion_receipts.append(row);print("COMPANION_ACCEPTED ",JSON.stringify(row))
	if host.sector>=7 and not finished:
		finished=true
		var drift:Array[String]=[]
		for path in full_sources:
			if FileAccess.get_sha256(path)!=full_sources[path]:drift.append(path)
		if not clinic_closed_seen:failures.append("Clinic shortcut was not observed closed before reserve power")
		if not clinic_roof_crossed:failures.append("No physical outbound roof crossing above the closed shortcut")
		if not clinic_open_seen:failures.append("Restored clinic generator did not open street shortcut")
		if not clinic_street_crossed:failures.append("No physical return-trip crossing through the opened street shortcut")
		if objective_receipts.size()!=7:failures.append("Missing required objective/gate receipts for seven districts")
		if host.deaths!=0:failures.append("Unexpected death")
		if not drift.is_empty():failures.append("Source drift")
		var report:Dictionary={"passed":failures.is_empty(),"hz":hz,"lens":host.lens,"districts":["rainline","city_clinic","city_tram_depot","city_records","city_evac_spine","quarantine_intake","l2_exchange"],"companion_receipts":companion_receipts,"presentation_disabled":disable_companion,"actual_blind":host.blind,"active_seconds":host.elapsed,"deaths":host.deaths,"objective_receipts":objective_receipts,"clinic_closed_seen":clinic_closed_seen,"clinic_roof_crossed":clinic_roof_crossed,"clinic_open_seen":clinic_open_seen,"clinic_street_crossed":clinic_street_crossed,"events":events,"source_hashes":full_sources,"source_drift":drift,"failures":failures,"method":"Normal title and ordinary automated input. No state/position/health/objective writes. Explicit walking target after restoring clinic power proves real street-shortcut traversal. Not manual play or human duration validation."}
		var output_error:String=ReportSink.write_report(report_destination,report)
		if not output_error.is_empty():
			push_error(output_error);completion_code=2;return {}
		print("NOV12_OPENING_ROUTE_RESULT "+JSON.stringify({"passed":report.passed,"hz":hz,"seconds":host.elapsed,"failures":failures}))
		completion_code=0 if report.passed else 1
		return {}
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
	host=load(scene_path).instantiate();root.add_child(host);host.save_enabled=false;host.companion.director.enabled=not disable_companion
	await key(KEY_2 if requested_lens=="strength" else KEY_3 if requested_lens=="agility" else KEY_1)
	await key(KEY_ENTER)
	await key(KEY_ENTER) # ordinary player skip of opening, not a state write
	var current_id:=""
	var entered_frame:=0
	for tick in range(hz*full_timeout*7):
		if finished:break
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
		elif host.state=="upgrade":
			area_samples.append({"level":host.sectors[host.sector].level,"seconds":host.level_seconds.get(str(host.sectors[host.sector].level),0),"blind":host.blind})
			await key([KEY_J,KEY_K,KEY_L,KEY_J][host.upgrades.size()])
		elif host.state=="final_choice":await key(KEY_J)
		elif host.state=="playing":
			host.input_override=decide()
			if host.room.gate_open and not objective_receipts.has(id):
				objective_receipts[id]={"active_seconds":host.elapsed,"required_goals":host.goals.filter(func(goal):return not goal.optional).map(func(goal):return {"id":goal.objective_id,"completed":goal.completed,"kind":goal.kind}),"relays":host.relay_states.duplicate(),"freight_latched":host.room.freight_receiver.is_latched if is_instance_valid(host.room.freight_receiver) else false}
			if frame%hz==0:
				trace.append(snapshot())
				if trace.size()>40:trace.pop_front()
		await physics_frame;await process_frame
	if not finished:
		push_error("Opening route ended before all seven districts completed");completion_code=1
	host.free();input_dispatch.free()
	await process_frame
	quit(completion_code)
