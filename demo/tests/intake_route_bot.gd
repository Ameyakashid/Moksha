extends "res://demo/tests/expanded_mission_route_bot.gd"
## Explicit sector-start fixture; ordinary production input after initialization.
## Parent observer is unchanged. This adds route-choice waypoints and assertions.
var approach_reached := false
var recovery := ""
var fall_reached := false
func _initialize() -> void:
	probe_sector=1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--recovery="): recovery=arg.trim_prefix("--recovery=")
	if recovery=="right": scene_path="res://demo/tests/intake_review.tscn"
	super._initialize()

func run() -> void:
	source_hashes["res://demo/tests/intake_route_bot.gd"]=FileAccess.get_sha256("res://demo/tests/intake_route_bot.gd")
	await super.run()
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(report_path))
	var exits: Array=events.filter(func(event):return event.event=="sector_exit" and event.sector==2)
	if not approach_reached: failures.append("Required distinct approach waypoint not reached")
	if exits.is_empty(): failures.append("No actual Intake onward interaction")
	elif approach=="upper" and int(exits[0].remaining_enemies)<1: failures.append("Upper route failed to preserve any living guards")
	if not recovery.is_empty() and not fall_reached: failures.append("Actual fall to supported recovery floor not observed")
	report.merge({"approach":approach,"recovery_fixture":recovery,"approach_reached":approach_reached,"fall_reached":fall_reached,"failures":failures,"passed":failures.is_empty(),"method_note":"Right recovery uses an explicitly staged initial spawn on the right upper platform; all subsequent fall, return, relay and onward movement is ordinary input. Normal approach routes use unchanged mission spawn."},true)
	var destination="res://demo/evidence/intake_%s_%dhz%s.json"%[approach,hz,"" if recovery.is_empty() else "_recovery_"+recovery]
	FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("INTAKE ROUTE RESULT ",destination," failures=",failures)
	quit(0 if failures.is_empty() else 1)

func begin_sector() -> void:
	approach_reached=false
	fall_reached=false
	super.begin_sector()

func navigate(target: Vector2, data: Dictionary) -> Dictionary:
	if host.sector==1 and host.relay_states.is_empty():
		var waypoint := Vector2(1110,80) if approach=="upper" else Vector2(1100,300)
		if recovery=="right": waypoint=Vector2(1880,-100)
		if not approach_reached:
			if reached_supported_waypoint(waypoint,32):
				approach_reached=true
				events.append({"event":"approach_waypoint","approach":approach,"position":str(host.player.position),"frame":frame,"remaining_enemies":host.remaining_enemies()})
			elif target.distance_to(host._relay_points()[0])<1: target=waypoint
		if approach_reached and not recovery.is_empty() and not fall_reached:
			var floor_waypoint:=Vector2(1970,300) if recovery=="right" else Vector2(1200,300)
			if reached_supported_waypoint(floor_waypoint,35):
				fall_reached=true
				events.append({"event":"actual_fall_recovery_floor","side":recovery,"position":str(host.player.position),"frame":frame,"closed_shutter":not host.room.shutters[0].is_open})
			elif target.distance_to(host._relay_points()[0])<1: target=floor_waypoint
	return super.navigate(target,data)
