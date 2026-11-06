extends "res://campaign/route_tests/l23_route.gd"
## Explicit district-start/build fixture. Once measuring, only existing route
## raw input and ordinary UI keys; read-only gate/actor instrumentation.
var requested_lens:="neutral"
var release_after_modal:=false
var rescue_after_stall:=false
var did_rescue:=false
var observations:Array[Dictionary]=[]
var output_path:=""
var modal_count:=0
var stalled_evidence:Dictionary={}
var frame_offset:=0
func _initialize()->void:
	district_id="l2_exchange";scene_path="res://campaign/campaign.tscn";max_sector_seconds=120
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
		if arg.begins_with("--district="):district_id=arg.trim_prefix("--district=")
		if arg.begins_with("--seconds="):max_sector_seconds=int(arg.trim_prefix("--seconds="))
		if arg.begins_with("--lens="):requested_lens=arg.trim_prefix("--lens=")
		if arg.begins_with("--output="):output_path=arg.trim_prefix("--output=")
		if arg.begins_with("--frame-offset="):frame_offset=int(arg.trim_prefix("--frame-offset="))
		if arg=="--release-after-modal":release_after_modal=true
		if arg=="--rescue-after-stall":rescue_after_stall=true
	Engine.physics_ticks_per_second=hz
	run.call_deferred()
func diagnostic(label:String)->Dictionary:
	var result:Dictionary=snapshot()
	result.merge({"label":label,"state":host.state,"blocked":host._input_gate._blocked.duplicate(),"admitted_input":host.player._input.duplicate(),"mode":str(host.player.main_action),"modal_count":modal_count},true)
	return result
func run()->void:
	input_dispatch=InputDispatch.new();input_dispatch.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(input_dispatch)
	host=load(scene_path).instantiate();host.save_enabled=false;root.add_child(host)
	host.lens=requested_lens;host.start_new(true);host.upgrades.assign(["force","agility"] if district_id=="l3_homes" else ["force"])
	for i in host.sectors.size():
		if str(host.sectors[i].id)==district_id:probe_sector=i
	host.load_sector(probe_sector);host.input_override={};begin_sector()
	measured_start=host.elapsed
	var blocked_ticks:=0
	for tick in range(hz*max_sector_seconds):
		frame=frame_offset+tick
		if host.sector!=probe_sector or host.state=="upgrade":break
		if host.state=="dead":failures.append("Route died");break
		if host.state in ["archive","choice"]:
			modal_count+=1
			observations.append(diagnostic("before modal close"))
			var was_choice:bool=host.state=="choice"
			await key(KEY_K if was_choice else KEY_E)
			if was_choice:choice_done=true
			observations.append(diagnostic("after modal close"))
			if release_after_modal:
				await preload("res://campaign/quality/nov6_modal_route_input.gd").release_after_resume(host,"choice" if was_choice else "archive",events,frame)
				observations.append(diagnostic("ordinary neutral frame after modal"))
		elif host.state=="playing":
			host.input_override=decide()
			if (host._input_gate._blocked.has("right") and host.input_override.get("right",0)>0) or (host._input_gate._blocked.has("left") and host.input_override.get("left",0)>0):blocked_ticks+=1
			else:blocked_ticks=0
			if blocked_ticks==hz*3:
				stalled_evidence=diagnostic("three seconds of held movement suppressed")
				observations.append(stalled_evidence)
				if rescue_after_stall and not did_rescue:
					did_rescue=true;host.input_override={}
					await physics_frame;await process_frame
					observations.append(diagnostic("ordinary one-frame release after observed stall"))
				elif not release_after_modal:break
			if tick%hz==0:observations.append(diagnostic("sample"))
		await physics_frame;await process_frame
	var reached:bool=host.sector!=probe_sector or host.state=="upgrade"
	var report:Dictionary={"district":district_id,"lens":requested_lens,"hz":hz,"release_after_modal":release_after_modal,"rescue_after_stall":rescue_after_stall,"did_rescue":did_rescue,"reached_next_district":reached,"actual_seconds":host.elapsed-measured_start,"deaths":host.deaths,"failures":failures,"modal_count":modal_count,"stalled_evidence":stalled_evidence,"observations":observations,"events":events,"logic_sha256":FileAccess.get_sha256("res://campaign/logic/campaign.gd"),"gate_sha256":FileAccess.get_sha256("res://campaign/logic/campaign_input_gate.gd"),"scope":"Explicit district/build starting fixture: "+district_id+", force"+(" and agility" if district_id=="l3_homes" else "")+". Measured route: unchanged production bot raw inputs and E/K/Q UI keys. Optional repair is one ordinary neutral input frame; no actor/health/enemy/goal writes."}
	if not output_path.is_empty():FileAccess.open(output_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("NOV6_EXCHANGE_PROBE ",JSON.stringify({"reached":reached,"modal_count":modal_count,"stall":not stalled_evidence.is_empty(),"rescued":did_rescue,"failures":failures,"output":output_path}))
	host.free();quit(0 if failures.is_empty() else 1)
