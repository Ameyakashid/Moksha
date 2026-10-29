extends "res://demo/tests/expanded_mission_route_bot.gd"
## Existing input observer plus explicit neighbourhood-choice waypoints.
var district_phase:=0
var recovery_side:=""
var shortcut_crossed:=false
var high_distance:=0.0
var street_distance:=0.0
var observed_position:=Vector2.ZERO
var observation_started:=false
func _initialize() -> void:
	probe_sector=0
	scene_path="res://demo/tests/rainline_review.tscn"
	max_sector_seconds=120
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--recovery="): recovery_side=arg.trim_prefix("--recovery=")
	super._initialize()
func run() -> void:
	for filename in DirAccess.get_files_at("res://demo/views"):
		if filename.begins_with("favela_") and (filename.ends_with(".gd") or filename.ends_with(".tscn")):
			var path="res://demo/views/"+filename
			source_hashes[path]=FileAccess.get_sha256(path)
	source_hashes["res://demo/tests/rainline_route_bot.gd"]=FileAccess.get_sha256("res://demo/tests/rainline_route_bot.gd")
	await super.run()
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(report_path))
	if not recovery_side.is_empty():
		var falls=events.filter(func(event):return event.event=="district_waypoint" and event.beat==1)
		if falls.is_empty() or not falls[0].closed_shutter or not falls[0].active_relays.is_empty(): failures.append("Recovery floor was not reached before badge with shortcut closed")
	if approach=="street" and not shortcut_crossed: failures.append("Street route did not physically cross opened ground shortcut")
	if recovery_side.is_empty() and approach=="roof" and high_distance<400: failures.append("Roof route lacks400px of elevated approach traversal")
	if recovery_side.is_empty() and approach=="street" and street_distance<600: failures.append("Street route lacks600px of low approach traversal")
	if district_phase<3: failures.append("Did not complete all three district waypoint beats")
	var exits=events.filter(func(event):return event.event=="sector_exit" and event.sector==1)
	if exits.is_empty(): failures.append("No actual onward interaction into Intake")
	elif int(exits[0].remaining_enemies)<1: failures.append("Route did not demonstrate bypassed living enemies")
	report.merge({"district_approach":approach,"district_phase":district_phase,"opened_shortcut_crossed":shortcut_crossed,"high_approach_distance":high_distance,"street_approach_distance":street_distance,"recovery":recovery_side,"failures":failures,"passed":failures.is_empty()},true)
	var destination="res://demo/evidence/rainline_%s_%dhz%s.json"%[approach,hz,"" if recovery_side.is_empty() else "_recovery_"+recovery_side]
	FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("RAINLINE RESULT ",destination," failures=",failures)
	quit(0 if failures.is_empty() else 1)
func begin_sector() -> void:
	district_phase=0
	super.begin_sector()
func navigate(target:Vector2,data:Dictionary)->Dictionary:
	if host.sector==0:
		var points:Array=[Vector2(1300,80),Vector2(2530,-160),Vector2(4900,80)] if approach=="roof" else [Vector2(1350,300),Vector2(2750,300),Vector2(5000,300)]
		if recovery_side=="left": points[1]=Vector2(2750,300)
		if recovery_side=="right": points[1]=Vector2(4140,300)
		if district_phase<3:
			var waypoint:Vector2=points[district_phase]
			# Beat3 follows the real badge; earlier beats precede it.
			if district_phase<2 or not host.relay_states.is_empty():
				var on_recovery_floor:bool=recovery_side.is_empty() or district_phase!=1 or absf(host.player.position.y-300)<4
				if reached_supported_waypoint(waypoint,32) and on_recovery_floor:
					events.append({"event":"district_waypoint","beat":district_phase,"approach":approach,"position":str(host.player.position),"frame":frame,"active_relays":host.relay_states.duplicate(),"grounded":host.player.grounded,"closed_shutter":not host.room.shutters[0].is_open})
					district_phase+=1
				elif target.distance_to(host._relay_points()[0])<1 or target.x>6000: target=waypoint
	return super.navigate(target,data)

func decide() -> Dictionary:
	var position:Vector2=host.player.position
	if observation_started and observed_position.x<3680 and position.x>=3680 and position.y>150 and observed_position.y>150 and host.room.shutters[0].is_open:
		shortcut_crossed=true
		events.append({"event":"physical_open_shortcut_crossing","frame":frame,"position":str(position),"grounded":host.player.grounded})
	if observation_started and position.x>500 and position.x<2800 and observed_position.x>500 and observed_position.x<2800:
		var travel:=absf(position.x-observed_position.x)
		if position.y<100 and observed_position.y<100: high_distance+=travel
		if position.y>270 and observed_position.y>270: street_distance+=travel
	observed_position=position
	observation_started=true
	return super.decide()
