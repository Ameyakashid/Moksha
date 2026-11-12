extends "res://campaign/quality/nov6_full_campaign_route.gd"
## External normal-title campaign observer. No initial district/sight fixture.
const Sink=preload("res://campaign/quality/nov12_report_sink.gd")
var destination:=""
var checkpoint_destination:=""
var provenance_destination:=""
var continue_sha:=""
var checkpoint_input:=""
var checkpoint_provenance:Dictionary={}
var prior_metrics:Array=[]
var prior_levels:Array=[]
var movie_frames:Array=[]
var continue_mode:=false
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
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--checkpoint="):checkpoint_destination=arg.trim_prefix("--checkpoint=")
		if arg.begins_with("--provenance="):provenance_destination=arg.trim_prefix("--provenance=")
		if arg.begins_with("--continue-sha="):continue_sha=arg.trim_prefix("--continue-sha=")
		if arg.begins_with("--checkpoint-input="):checkpoint_input=arg.trim_prefix("--checkpoint-input=")
	continue_mode=not continue_sha.is_empty()
	var invalid:String=Sink.validate(destination)
	if continue_mode:
		if continue_sha.length()!=64 or continue_sha!=continue_sha.to_lower():invalid="Invalid checkpoint SHA256"
	else:
		for path in [checkpoint_destination,provenance_destination]:
			var path_error:=Sink.validate(path)
			if not path_error.is_empty():invalid=path_error
		if checkpoint_destination==provenance_destination or checkpoint_destination==destination or provenance_destination==destination:invalid="Output paths must be distinct"
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
	if continue_mode:
		var save_path:="user://moksha_five_levels_v1.json"
		if FileAccess.file_exists(save_path) or FileAccess.get_sha256(checkpoint_input)!=continue_sha:
			push_error("Continue requires fresh isolated save and exact checkpoint input");input_dispatch.free();quit(2);return
		DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
		if DirAccess.copy_absolute(checkpoint_input,ProjectSettings.globalize_path(save_path))!=OK or FileAccess.get_sha256(save_path)!=continue_sha:
			push_error("Checkpoint materialization failed");input_dispatch.free();quit(2);return
	host=load(scene_path).instantiate();root.add_child(host);host.save_enabled=true
	if continue_mode:
		var decoded:Dictionary=host._decode_campaign_checkpoint()
		if FileAccess.get_sha256(host.CAMPAIGN_SAVE)!=continue_sha or not decoded.get("ok",false) or not host.continue_available:
			push_error("Genuine checkpoint unavailable or hash invalid");host.free();input_dispatch.free();quit(2);return
		if str(host.sectors[int(decoded.sector)].id)!="crown_ascent" or decoded.metrics.size()!=25 or decoded.campaign.level_receipts.size()!=4 or decoded.campaign.upgrades.size()!=4:
			push_error("Checkpoint is not genuine Crown entry schema");host.free();input_dispatch.free();quit(2);return
		prior_metrics=decoded.metrics.duplicate(true);prior_levels=decoded.campaign.level_receipts.duplicate(true)
		if decoded.campaign.lens!=requested_lens or decoded.blind!=sacrifice:
			push_error("Checkpoint build does not match requested recording labels");host.free();input_dispatch.free();quit(2);return
		await key(KEY_C)
		if host.state!="playing" or str(host.sectors[host.sector].id)!="crown_ascent":failures.append("Ordinary Continue did not enter Crown")
	else:
		if FileAccess.file_exists(host.CAMPAIGN_SAVE):
			push_error("Producer requires empty isolated save directory");host.free();input_dispatch.free();quit(2);return
		await key(KEY_2 if requested_lens=="strength" else KEY_3 if requested_lens=="agility" else KEY_1)
		await key(KEY_ENTER)
		await key(KEY_ENTER) # ordinary player skip of opening, not a state write
	var current_id:=""
	var entered_frame:=0
	for tick in range(hz*full_timeout*host.sectors.size()):
		frame=tick
		if not failures.is_empty() or host.state=="complete":break
		var id:String=host.sectors[host.sector].id
		if current_id!=id:
			current_id=id;district_id=id;residential_index=0;entered_frame=frame;goals_seen.clear();interaction_tick=-999
			choice_done=host.blind
			begin_sector()
			print("CAMPAIGN_ENTER ",host.sector+1," ",id," time=",host.elapsed," blind=",host.blind)
			movie_frames.append({"district":id,"frame":Engine.get_frames_drawn(),"tick":frame,"seconds":host.elapsed})
			if id=="crown_ascent" and not continue_mode and checkpoint_provenance.is_empty():
				capture_crown_checkpoint()
				if not failures.is_empty():break
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
	if continue_mode and host.state=="complete":
		for ending_frame in 120:await process_frame
	var drift:Array[String]=[]
	for path in full_sources:
		if FileAccess.get_sha256(path)!=full_sources[path]:drift.append(path)
	if not drift.is_empty():failures.append("Source changed while run was active")
	if host.state=="complete" and host.blind!=sacrifice:failures.append("Requested actual sight decision did not persist")
	if host.state=="complete":
		if host.lens!=requested_lens:failures.append("Wrong selected lens")
		if host.upgrades.size()!=4:failures.append("Expected four genuine level upgrade choices")
		if host.metrics.size()!=host.sectors.size():failures.append("District metric count does not match campaign")
		else:
			for i in host.metrics.size():
				if int(host.metrics[i].sector)!=i:failures.append("District order mismatch at %d"%i)
		if host.level_receipts.map(func(receipt):return int(receipt.level))!=[1,2,3,4,5]:failures.append("Five level completion receipts missing")
		if host.deaths!=0:failures.append("Unexpected death/retry")
		if objective_receipts.size()!=(7 if continue_mode else host.sectors.size()):failures.append("Missing actual open-gate objective receipt")
	if host.state!="complete":failures.append("Campaign did not naturally complete")
	if host.sectors.size()!=32:failures.append("Expected32 districts")
	if host.campaign_ending!=requested_ending:failures.append("Wrong natural ending")
	if not continue_mode and not (clinic_closed_seen and clinic_roof_crossed and clinic_open_seen and clinic_street_crossed):failures.append("Clinic shortcut proof incomplete")
	for data in host.sectors:
		if continue_mode and int(data.level)!=5:continue
		if not objective_receipts.has(data.id):
			failures.append("Missing district receipt: "+str(data.id));continue
		var required:Array=data.get("objectives",[]).filter(func(goal):return not goal.get("optional",false)).map(func(goal):return goal.id)
		var observed:Array=objective_receipts[data.id].required_goals
		if observed.map(func(goal):return goal.id)!=required or observed.any(func(goal):return not goal.completed):failures.append("Invalid required objectives: "+str(data.id))
	if continue_mode:
		if host.metrics.slice(0,25)!=prior_metrics:failures.append("Prior checkpoint metrics changed")
		if host.level_receipts.slice(0,4)!=prior_levels:failures.append("Prior level receipts changed")
	elif checkpoint_provenance.is_empty():failures.append("No genuine Crown checkpoint captured")
	movie_frames.append({"ending":host.campaign_ending,"frame":Engine.get_frames_drawn(),"tick":frame})
	var report:Dictionary={"passed":host.state=="complete" and failures.is_empty(),"completed":host.state=="complete","hz":hz,"lens":requested_lens,"requested_sight_trade":sacrifice,"actual_blind":host.blind,"actual_upgrade_choices":host.upgrades,"active_seconds":host.elapsed,"levels":host.level_receipts,"district_metrics":host.metrics,"ending":host.campaign_ending,"deaths":host.deaths,"kills":host.kills,"events":events,"damage_receipts":damage_receipts,"objective_receipts":objective_receipts,"last_trace":trace,"source_hashes":full_sources,"source_drift":drift,"failures":failures,"human_duration_validated":false,"method":"Normal title lens key, Enter, opening skip; raw PC input plus idle-dispatched ordinary E/Q/choice/upgrade/finale keys. No gameplay state/position/health/enemy writes, no forced goals. Layout-aware bot timing is not human timing."}
	report["requested_ending"]=requested_ending
	report["continue_mode"]=continue_mode
	report["checkpoint_sha256"]=continue_sha if continue_mode else checkpoint_provenance.get("sha256","")
	report["checkpoint_provenance"]=checkpoint_provenance
	report["movie_frames"]=movie_frames
	report["new_objective_receipt_count"]=objective_receipts.size()
	report["prior_metrics_count"]=prior_metrics.size()
	report["prior_level_receipts_count"]=prior_levels.size()
	report["method"]="Ordinary title C from byte-identical checkpoint captured at first natural Crown entry during validated normal-title run;7new Crown districts. Room/health reset is normal Continue behavior. Automated ordinary inputs; no forced state/position/goals." if continue_mode else "Normal-title automated full campaign with isolated ordinary saves enabled; genuine Crown entry save copied byte-for-byte before Crown inputs. No forced state/position/health/goals."
	report["clinic_shortcut"]={"closed_seen":clinic_closed_seen,"roof_crossed":clinic_roof_crossed,"open_seen":clinic_open_seen,"street_crossed":clinic_street_crossed}
	var output_error:String=Sink.write_report(destination,report)
	var result_code:=0 if report.passed else 1
	if not output_error.is_empty():push_error(output_error);result_code=2
	print("NOV12_FULL_CAMPAIGN_RESULT ",JSON.stringify({"passed":report.passed,"completed":report.completed,"seconds":host.elapsed,"failures":failures,"output_error":output_error}))
	host.free();input_dispatch.free()
	await process_frame
	quit(result_code)

func capture_crown_checkpoint()->void:
	var decoded:Dictionary=host._decode_campaign_checkpoint()
	if not decoded.get("ok",false) or int(decoded.sector)!=host.sector or decoded.metrics.size()!=25 or decoded.campaign.level_receipts.size()!=4 or decoded.campaign.upgrades.size()!=4:
		failures.append("Natural Crown entry checkpoint missing/inconsistent");return
	if decoded.metrics!=host.metrics or decoded.campaign.level_receipts!=host.level_receipts:
		failures.append("Disk checkpoint differs from natural entry history");return
	var invalid:=Sink.validate(checkpoint_destination)
	if not invalid.is_empty():failures.append(invalid);return
	var digest:=FileAccess.get_sha256(host.CAMPAIGN_SAVE)
	if digest.is_empty():failures.append("Checkpoint unreadable");return
	var error:=DirAccess.copy_absolute(ProjectSettings.globalize_path(host.CAMPAIGN_SAVE),checkpoint_destination)
	if error!=OK or FileAccess.get_sha256(checkpoint_destination)!=digest or FileAccess.get_sha256(host.CAMPAIGN_SAVE)!=digest:
		failures.append("Byte-identical checkpoint copy failed");return
	checkpoint_provenance={"sha256":digest,"district":"crown_ascent","sector_index":host.sector,"capture_tick":frame,"active_seconds":host.elapsed,"prior_metrics":host.metrics.duplicate(true),"prior_levels":host.level_receipts.duplicate(true),"upgrades":host.upgrades.duplicate(),"lens":host.lens,"blind":host.blind,"deaths":host.deaths,"source_hashes":full_sources.duplicate(),"method":"First natural Crown entry, after ordinary synchronous checkpoint commit and before Crown movement input. Exact file copy, no synthesis."}
	var output_error:=Sink.write_report(provenance_destination,checkpoint_provenance)
	if not output_error.is_empty():failures.append(output_error)
	print("GENUINE_CROWN_CHECKPOINT ",digest)
