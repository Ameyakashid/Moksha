extends "res://campaign/route_tests/l23_route.gd"
## Full start-to-resolution production route. No sector/sight/health fixtures.
var requested_lens:="neutral"
var full_sources:Dictionary={}
var area_samples:Array[Dictionary]=[]
var full_timeout:=480
var objective_receipts:Dictionary={}
func _initialize()->void:
	scene_path="res://campaign/campaign.tscn"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
		if arg=="--sacrifice":sacrifice=true
		if arg.begins_with("--lens="):requested_lens=arg.trim_prefix("--lens=")
		if arg.begins_with("--district-timeout="):full_timeout=int(arg.trim_prefix("--district-timeout="))
	Engine.physics_ticks_per_second=hz
	run.call_deferred()
func collect_sources(path:String)->void:
	for file in DirAccess.get_files_at(path):
		if file.ends_with(".gd") or file.ends_with(".tscn") or file.ends_with(".tres"):
			full_sources[path+"/"+file]=FileAccess.get_sha256(path+"/"+file)
	for folder in DirAccess.get_directories_at(path):collect_sources(path+"/"+folder)
func run()->void:
	for directory in ["res://campaign","res://demo","res://simulation","res://combat_pc"]:collect_sources(directory)
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
		elif host.state=="hearing_choice":
			await key(KEY_K) # Historical route explicitly retains hearing.
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
	var report:Dictionary={"passed":host.state=="complete" and failures.is_empty(),"completed":host.state=="complete","hz":hz,"lens":requested_lens,"requested_sight_trade":sacrifice,"actual_blind":host.blind,"hearing_retained":host.hearing_retained,"actual_upgrade_choices":host.upgrades,"active_seconds":host.elapsed,"levels":host.level_receipts,"district_metrics":host.metrics,"ending":host.campaign_ending,"deaths":host.deaths,"kills":host.kills,"events":events,"damage_receipts":damage_receipts,"objective_receipts":objective_receipts,"last_trace":trace,"source_hashes":full_sources,"source_drift":drift,"failures":failures,"human_duration_validated":false,"method":"Normal title lens key, Enter, opening skip; raw PC input plus idle-dispatched ordinary E/Q/choice/upgrade/finale keys. No gameplay state/position/health/enemy writes, no forced goals. Layout-aware bot timing is not human timing."}
	var output:="res://campaign/tests/full_route_%d_%s_%s.json"%[hz,requested_lens,"traded" if sacrifice else "retained"]
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FULL_CAMPAIGN_RESULT ",output," completed=",report.completed," seconds=",host.elapsed," failures=",failures)
	quit(0 if report.passed else 1)
