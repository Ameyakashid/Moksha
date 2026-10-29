extends "res://demo/tests/expanded_mission_route_bot.gd"
var grade:="flat"
var trial_seed:=1
var last_strike:=-9999
var stationary_time:=0.0
var cargo_records:Array=[]
var observed_cargo_ids:={}
func _initialize() -> void:
	probe_sector=0
	scene_path="res://demo/tests/freight_transport_trial_room.tscn"
	max_sector_seconds=60
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--grade="):grade=arg.trim_prefix("--grade=")
		if arg.begins_with("--seed="):trial_seed=int(arg.trim_prefix("--seed="))
	seed(trial_seed)
	super._initialize()
func run() -> void:
	input_dispatch=InputDispatch.new()
	input_dispatch.process_mode=Node.PROCESS_MODE_ALWAYS
	root.add_child(input_dispatch)
	for path in ["res://demo/tests/freight_transport_trial.gd","res://demo/tests/freight_transport_trial_room.gd","res://prop.gd","res://demo/components/mission_prop.gd","res://demo/components/freight_receiver.gd","res://resources/tuning/prop_tuning.gd"]:
		source_hashes[path]=FileAccess.get_sha256(path)
	host=load(scene_path).instantiate()
	root.add_child(host)
	host.save_enabled=false
	for tick in range(hz*30):
		frame=tick
		if host.room.freight_receiver.is_latched:break
		if host.sector!=sector_seen:begin_sector()
		host.input_override=decide()
		await physics_frame
		await process_frame
	var cradle=host.room.freight_cradle
	var cargo=cradle.cargo
	var intact:bool=is_instance_valid(cargo) and cargo.alive
	if not host.room.freight_receiver.is_latched:failures.append("Actual receiver did not latch within capability observation")
	if not intact:failures.append("Original cargo destroyed")
	if cradle.replacement_count!=1:failures.append("Capability trial replaced original cargo")
	var launches=cargo_records.filter(func(event):return event.event=="actual_launch")
	if launches.size()<3:failures.append("Multi-strike transport not exercised")
	var changed_sources:Array=[]
	for path in source_hashes:
		if FileAccess.get_sha256(path)!=source_hashes[path]:changed_sources.append(path)
	if not changed_sources.is_empty():failures.append("Source changed during trial")
	var report={"grade":grade,"hz":hz,"seed":trial_seed,"capability_fixture":true,"criterion":"Actual intact receiver latch after repeated raw controller J strikes; NOT onward actor-egress proof.","cargo_records":cargo_records,"events":events,"active_seconds":host.elapsed,"latched":host.room.freight_receiver.is_latched,"original_spawn_count":cradle.replacement_count,"intact":intact,"final_hard_impacts":cargo.hard_impacts if intact else -1,"actual_launch_count":launches.size(),"source_hashes":source_hashes,"sources_changed_during_run":changed_sources,"failures":failures,"passed":failures.is_empty()}
	var path="res://demo/evidence/freight_transport_capacity_%s_%dhz_seed%d.json"%[grade,hz,trial_seed]
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("TRANSPORT CAPACITY ",path," launches=",launches.size()," hard_impacts=",report.final_hard_impacts," failures=",failures)
	quit(0 if failures.is_empty() else 1)
func freight_plan(data:Dictionary)->Dictionary:
	var player=host.player
	var cargo=host.room.freight_cradle.cargo
	if not is_instance_valid(cargo) or not cargo.alive:
		return {"target":data.freight.cradle,"objective":"lost cargo return"}
	if not observed_cargo_ids.has(cargo.get_instance_id()):
		observed_cargo_ids[cargo.get_instance_id()]=true
		cargo.launched.connect(func(body): cargo_records.append({"event":"actual_launch","frame":frame,"x":body.global_position.x,"y":body.global_position.y,"hit_count":body.hit_count,"hard_impacts":body.hard_impacts,"pre_solver_velocity_at_signal":str(body.linear_velocity)}))
	var position:Vector2=cargo.global_position
	if frame%maxi(1,hz/4)==0:cargo_records.append({"event":"sample","frame":frame,"x":position.x,"y":position.y,"speed":cargo.linear_velocity.length(),"hit_count":cargo.hit_count,"hard_impacts":cargo.hard_impacts,"intact":cargo.alive})
	if cargo.linear_velocity.length()<25:stationary_time+=1.0/hz
	else:stationary_time=0
	var stance:=Vector2(position.x-40,180)
	if position.x>1000:stance.y=300
	if player.position.distance_to(stance)>9:return {"target":stance,"objective":"follow actual cargo"}
	if player.facing!=1:return {"raw":{"right":1.0}}
	if not player.grounded or absf(player.velocity.x)>20:return {"raw":{}}
	if stationary_time<0.25 or frame-last_strike<hz or player.weapon_phase!=&"idle":return {"raw":{}}
	last_strike=frame
	return {"raw":{"attack":true}}
