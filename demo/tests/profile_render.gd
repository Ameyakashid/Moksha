extends Node2D
var mission:Node2D
var elapsed:=0.0
var stage:=-1
var samples:Array[Dictionary]=[]
var frame:=0
var next_tap:=0.0
func build_mission()->void:
	mission=load("res://demo/mission.tscn").instantiate()
	add_child(mission)
	mission.save_enabled=false
	mission.load_sector(3)
	mission.player.reset_actor(Vector2(800,-500),1)
	mission.input_override={}
	mission.chapter_left=0
	mission.sonar.free()
	mission.sonar=CanvasLayer.new()
	mission.sonar.set_script(load("res://demo/tests/profile_sonar.gd"))
	mission.sonar.tuning=load("res://resources/sensory/sonar_default.tres").duplicate(true)
	mission.add_child(mission.sonar)
	mission.sonar.tuning.draw_proprioception=false
	mission._apply_trade()
	mission.sonar.bind_level(mission.room,mission.player)
func _process(dt:float)->void:
	elapsed+=dt
	var phase:=mini(int(elapsed/8),2)
	if stage!=phase:
		stage=phase
		if stage==1: build_mission()
		if stage==0: return
		mission.process_mode=Node.PROCESS_MODE_INHERIT
		mission.visible=stage!=0
		mission.hud.visible=stage!=0
		mission.sonar.visible=stage==2
		mission.sonar.simulation_enabled=stage==2
		mission.sonar.preview_when_sighted=stage==2
		mission.sonar.clear_pulses()
		mission.sonar.cpu_usec={"render":0,"refresh":0,"emit":0}
		mission.sonar.counts={"render":0,"refresh":0,"emit":0}
		print("PROFILE STAGE ",stage)
	if stage==2 and elapsed>next_tap:
		next_tap=elapsed+0.5
		mission.tap_weapon()
	frame+=1
	if frame%10==0 and fmod(elapsed,8)>2:
		samples.append({"stage":stage,"fps":Engine.get_frames_per_second(),"frame_ms":dt*1000,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"geometry":mission.sonar.geometry.size() if is_instance_valid(mission) else 0,"pulses":mission.sonar.pulses.size() if is_instance_valid(mission) else 0,"sonar_cpu_usec":mission.sonar.cpu_usec.duplicate() if is_instance_valid(mission) else {},"sonar_calls":mission.sonar.counts.duplicate() if is_instance_valid(mission) else {}})
	if elapsed>24:
		var f=FileAccess.open("res://demo/evidence/native_profile_render.json",FileAccess.WRITE)
		f.store_string(JSON.stringify(samples,"\t"))
		print("RENDER PROFILE COMPLETE ",samples.size())
		get_tree().quit()
