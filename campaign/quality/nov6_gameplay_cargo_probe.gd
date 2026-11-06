extends "res://campaign/route_tests/l23_route.gd"
## Explicit Works Cargo entrance/build fixture. Measured phase only raw inputs
## and ordinary E/Q interactions; cargo, receiver and actor are read-only.
var requested_lens:="neutral"
var repair_short_delivery:=false
var output_path:=""
var frame_offset:=50280
var observations:Array[Dictionary]=[]
var stalled_evidence:Dictionary={}
var rescue_strikes:=0
var delivery_seen:=false
var fixture_seed:=-1
var trace_stall_fixture:=false
var fixture_details:Dictionary={}
func _initialize()->void:
	district_id="works_cargo_exchange";scene_path="res://campaign/campaign.tscn";max_sector_seconds=180
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):fixture_seed=int(arg.trim_prefix("--seed="))
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
		if arg.begins_with("--lens="):requested_lens=arg.trim_prefix("--lens=")
		if arg.begins_with("--output="):output_path=arg.trim_prefix("--output=")
		if arg.begins_with("--frame-offset="):frame_offset=int(arg.trim_prefix("--frame-offset="))
		if arg=="--repair-short-delivery":repair_short_delivery=true
		if arg=="--trace-stall-fixture":trace_stall_fixture=true
	Engine.physics_ticks_per_second=hz
	run.call_deferred()
func diagnostic(label:String)->Dictionary:
	var result:Dictionary=snapshot()
	var receiver=host.room.freight_receiver
	var cargo=host.room.freight_cradle.cargo
	result.merge({"label":label,"state":host.state,"blocked":host._input_gate._blocked.duplicate(),"admitted_input":host.player._input.duplicate(),"goals":host.goals.map(func(goal):return {"id":goal.objective_id,"completed":goal.completed,"available":goal.available}),"receiver_position":str(receiver.global_position),"receiver_status":receiver.status,"receiver_supported_and_slow":receiver.is_supported_and_slow(cargo),"cargo_receiver_local":str(receiver.to_local(cargo.global_position)) if is_instance_valid(cargo) else "missing","rescue_strikes":rescue_strikes},true)
	return result
var _freight_route_input=preload("res://campaign/quality/nov6_freight_route_input.gd").new()
func freight_45_plan(data:Dictionary)->Dictionary:
	var plan:Dictionary=super.freight_45_plan(data)
	if not repair_short_delivery or stalled_evidence.is_empty():return plan
	var filtered:Dictionary=_freight_route_input.filter_plan(host,data,plan,frame,hz,events)
	if filtered.get("raw",{}).get("attack",false):rescue_strikes+=1
	return filtered
func run()->void:
	if fixture_seed>=0:seed(fixture_seed) # Initial reproducible random-spin fixture only.
	input_dispatch=InputDispatch.new();input_dispatch.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(input_dispatch)
	host=load(scene_path).instantiate();host.save_enabled=false;root.add_child(host)
	host.lens=requested_lens;host.start_new(true);host.upgrades.assign(["force","agility","vitality"])
	for i in host.sectors.size():
		if str(host.sectors[i].id)==district_id:probe_sector=i
	host.load_sector(probe_sector);host.input_override={}
	if trace_stall_fixture:
		await physics_frame;await process_frame
		host.player.global_position=Vector2(3214.519,239.98)
		var fixture_cargo=host.room.freight_cradle.cargo
		fixture_cargo.global_position=Vector2(3290.142,226.176)
		fixture_cargo.linear_velocity=Vector2.ZERO;fixture_cargo.angular_velocity=0;fixture_cargo.rotation=0
		fixture_cargo.hit_count=3
		# Explicit initial state only. Allow real contacts/sleep to settle before
		# measuring. Rotation was absent from the full receipt, so zero is an
		# explicit fixture assumption; this does not claim an exact save replay.
		for tick in hz/2:await physics_frame;await process_frame
		fixture_details={"kind":"trace-matched stationary approach-deck fixture","source":"f00 modal-v1 full_route_60_neutral_retained.json final trace","actor_position":"(3214.519,239.98)","cargo_position":"(3290.142,226.176)","cargo_hit_count":3,"cargo_rotation_assumption":0,"goals":"fresh ordinary district goals; none forced complete","setup_only":true,"not_an_exact_save_replay":true}
	begin_sector();measured_start=host.elapsed
	observations.append(diagnostic("initial fixture settled; measured ordinary inputs begin"))
	var still_ticks:=0
	for tick in range(hz*max_sector_seconds):
		frame=frame_offset+tick
		if host.sector!=probe_sector or host.state=="upgrade":break
		if host.state=="dead":failures.append("Route died");break
		if host.state in ["archive","choice"]:
			var previous_state:String=host.state
			await key(KEY_K if previous_state=="choice" else KEY_E)
			await preload("res://campaign/quality/nov6_modal_route_input.gd").release_after_resume(host,previous_state,events,frame)
		elif host.state=="playing":
			host.input_override=decide()
			var cargo=host.room.freight_cradle.cargo
			var receiver=host.room.freight_receiver
			if receiver.is_latched and not delivery_seen:
				delivery_seen=true;observations.append(diagnostic("actual intact receiver latch"))
			if is_instance_valid(cargo) and cargo.alive and not receiver.is_latched and cargo.linear_velocity.length()<1 and nav_trace.get("objective","")=="freight let delivery settle":still_ticks+=1
			else:still_ticks=0
			if still_ticks==hz*3 and stalled_evidence.is_empty():
				stalled_evidence=diagnostic("three seconds of motionless short delivery while observer waits")
				observations.append(stalled_evidence)
				if not repair_short_delivery:break
			if tick%hz==0:observations.append(diagnostic("sample"))
		await physics_frame;await process_frame
	var reached:bool=host.sector!=probe_sector or host.state=="upgrade"
	var report:Dictionary={"fixture_seed":fixture_seed,"trace_stall_fixture":trace_stall_fixture,"fixture_details":fixture_details,"district":district_id,"lens":requested_lens,"hz":hz,"frame_offset":frame_offset,"repair_short_delivery":repair_short_delivery,"reached_next_district":reached,"delivered":delivery_seen,"rescue_strikes":rescue_strikes,"actual_seconds":host.elapsed-measured_start,"deaths":host.deaths,"failures":failures,"stalled_evidence":stalled_evidence,"observations":observations,"events":events,"logic_sha256":FileAccess.get_sha256("res://campaign/logic/campaign.gd"),"gate_sha256":FileAccess.get_sha256("res://campaign/logic/campaign_input_gate.gd"),"route_sha256":FileAccess.get_sha256("res://campaign/route_tests/l23_route.gd"),"scope":"Explicit Works Cargo entrance or clearly labelled trace-matched stationary-cargo fixture with Neutral/selected lens and Force, Agility, Vitality build. Measured route uses original observer plus optional ordinary approach/strike after confirmed stationary undelivered cargo. No measured actor, cargo, receiver, health, enemy or objective writes."}
	if not output_path.is_empty():FileAccess.open(output_path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("NOV6_CARGO_PROBE ",JSON.stringify({"reached":reached,"delivered":delivery_seen,"stall":not stalled_evidence.is_empty(),"rescue_strikes":rescue_strikes,"failures":failures,"output":output_path}))
	host.free();quit(0 if failures.is_empty() else 1)
