extends Node2D
## PC-only authored inspection course. Station resets are explicit debug actions.
const PLAYER = preload("res://combat_pc/player.tscn")
const LIGHT_CHAIN = preload("res://combat_pc/resources/light_chain.tres")
const HELD_REPEAT = preload("res://combat_pc/resources/held_repeat.tres")
const HELD_CHARGE = preload("res://combat_pc/resources/held_charge.tres")
const MELEE_MODE_NAMES := ["FRESH CHAIN", "HELD REPEAT", "HELD CHARGE"]
const STATIONS := [Vector2(70,270),Vector2(290,270),Vector2(865,270),Vector2(1010,270),Vector2(1370,270),Vector2(605,152),Vector2(1570,180),Vector2(1450,270),Vector2(1980,270),Vector2(2190,270),Vector2(1828,-150),Vector2(1730,80),Vector2(2500,270),Vector2(3440,270),Vector2(3820,270),Vector2(4220,270),Vector2(218,270),Vector2(282,270)]
var player: CharacterBody2D
var camera: Camera2D
var panel: Control
var paused := false
var details := false
var wall_ability_enabled := true
var hard_landing_enabled := true
var station := 0
var guard_mode := -1
var melee_mode := 0
var entry_assist_enabled := false
var candidate_awareness := true
var noise_marks: Array[Dictionary] = []
var record_noises: Array[Dictionary] = []
var last_event := "READY"
var recent_events: Array[Dictionary] = []
var record_remaining := 0.0
var record_clock := 0.0
var record_started := 0
var record_controller_sha256 := ""
var record_configuration: Dictionary = {}
var record_frames: Array[Dictionary] = []
var record_trace: Array[Dictionary] = []
var record_events: Array[Dictionary] = []
var sample_index := 0
var last_contact := "NO CONTACT"
var contact_marks: Array[Dictionary] = []
var feedback_text := ""
var feedback_timer := 0.0
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://delivery")
	var capture_ignore:=FileAccess.open("res://delivery/.gdignore",FileAccess.WRITE)
	if capture_ignore:capture_ignore.store_string("Generated viewport captures; excluded from resource import.\n")
	camera=$Camera
	panel=$HUD/Panel
	panel.lab=self
	player=get_node_or_null("Player")
	if player==null: reset_player()
	else: _bind_player()
	var bus:=get_node_or_null("/root/NoiseBus")
	if bus and bus.has_signal("noise_emitted") and not bus.is_connected("noise_emitted",_noise_event):bus.connect("noise_emitted",_noise_event)
func _bind_player() -> void:
	# The isolated actor starts locked; this movement course grants its wall ability.
	if "allow_wall_run" in player: player.allow_wall_run=wall_ability_enabled
	if "enable_hard_landing" in player: player.enable_hard_landing=hard_landing_enabled
	# One authored example weapon, independent of the reusable single-swing fallback.
	if "melee_chain" in player: player.melee_chain=LIGHT_CHAIN
	_apply_melee_mode()
	if player.has_signal("movement_event"): player.movement_event.connect(_movement_event)
	if player.has_signal("noise_requested"):player.connect("noise_requested",_noise_event)
	_bind_entry_host()
	var contact:=player.get_node_or_null("ContactAdapter")
	if contact and contact.has_signal("contact_confirmed"):contact.contact_confirmed.connect(_contact_confirmed)
	camera.position=Vector2(clampf(player.position.x,320,4180),clampf(player.position.y+70,-100,180))
func _entry_host() -> Node:
	return get_node_or_null("EntryFacingHost")
func _entry_candidate() -> Node2D:
	return get_node_or_null("Geometry/OpenContact") as Node2D
func _bind_entry_host() -> void:
	var host = _entry_host()
	if not is_instance_valid(host):return
	host.register_candidate(_entry_candidate(),{"classification":&"opponent","eligible":true,"perceived":candidate_awareness,"visible":candidate_awareness,"local_anchor":Vector2(0,-15)})
	host.set_assist_enabled(entry_assist_enabled)
	host.bind_actor(player)
	host.reset_diagnostics()
	_apply_candidate_awareness()
func _apply_candidate_awareness() -> void:
	var target = _entry_candidate()
	if is_instance_valid(target):target.visible=candidate_awareness
	var host = _entry_host()
	if is_instance_valid(host):host.set_candidate_awareness(candidate_awareness,candidate_awareness)
func entry_host_diagnostics() -> Dictionary:
	var host = _entry_host()
	return host.diagnostics() if is_instance_valid(host) else {}
func _record_inspection(event_name: String, data: Dictionary) -> void:
	if record_remaining>0:
		record_events.append({"raw_seconds":(Time.get_ticks_usec()-record_started)/1000000.0,"physics_tick":Engine.get_physics_frames(),"event":event_name,"data":data})
func toggle_entry_assist() -> void:
	entry_assist_enabled=not entry_assist_enabled
	var host = _entry_host()
	if is_instance_valid(host):host.set_assist_enabled(entry_assist_enabled)
	feedback_text="ENTRY AIM / "+("ON" if entry_assist_enabled else "OFF")+" / L TO COMPARE"
	feedback_timer=1.6
	_record_inspection("inspection_entry_assist_changed",{"enabled":entry_assist_enabled})
func toggle_candidate_awareness() -> void:
	candidate_awareness=not candidate_awareness
	_apply_candidate_awareness()
	feedback_text="TARGET PERCEPTION / "+("VISIBLE" if candidate_awareness else "UNPERCEIVED / AIM MUST REFUSE")
	feedback_timer=1.8
	_record_inspection("inspection_candidate_awareness_changed",{"perceived":candidate_awareness,"visible":candidate_awareness})
func _apply_melee_mode() -> void:
	if not is_instance_valid(player) or not "melee_input_profile" in player:return
	player.melee_input_profile=[null,HELD_REPEAT,HELD_CHARGE][melee_mode]
func cycle_melee_mode() -> void:
	melee_mode=(melee_mode+1)%MELEE_MODE_NAMES.size()
	_apply_melee_mode()
	feedback_text=["FRESH / PRESS J FOR EACH STEP","REPEAT / HOLD J; RELEASE TO STOP","CHARGE / HOLD J THROUGH SLASH; RELEASE TO CANCEL"][melee_mode]
	feedback_timer=2.8
	if record_remaining>0:
		record_events.append({"raw_seconds":(Time.get_ticks_usec()-record_started)/1000000.0,"physics_tick":Engine.get_physics_frames(),"event":"inspection_melee_mode_changed","data":{"mode":melee_mode,"label":MELEE_MODE_NAMES[melee_mode]}})
func reset_player() -> void:
	if record_remaining>0:record_events.append({"raw_seconds":(Time.get_ticks_usec()-record_started)/1000000.0,"physics_tick":Engine.get_physics_frames(),"event":"inspection_reset","data":{"station":station}})
	if is_instance_valid(player):
		remove_child(player)
		player.queue_free()
	player=PLAYER.instantiate()
	player.name="Player"
	player.position=STATIONS[station]
	add_child(player)
	_bind_player()
	paused=false
	_set_simulation(true)
	recent_events.clear()
	last_event="RESET / " + ["RUN + REVERSE","LEDGE APPROACH","CLEARANCE","MOVING CONTACT","ROLL + CONTACT","ONE-WAY STACK","DIVE + LANDING","LADDER / TOP EXIT","WALL / KICK TO LANDING","MIRROR / LEDGE HANDOFF","HIGH FALL / RECOVERY","SOFT FALL / CONTROL","SLOPES / RELEASE + REVERSE","SHIELD / MELEE","SHIELD / PROJECTILE","SHIELD / RIGID PROP","MELEE / THREE FRESH PRESSES","ENTRY AIM / TARGET BEHIND / COMPARE I ON-OFF"][station]
	if station==16:last_event="MELEE / "+MELEE_MODE_NAMES[melee_mode]
	last_contact="NO CONTACT"
	feedback_text=""
	feedback_timer=0
	contact_marks.clear()
	noise_marks.clear()
	for fixture in $Geometry.find_children("*","",true,false):
		if not is_instance_valid(fixture):continue
		if fixture.has_method("reset_target"):fixture.reset_target()
		if fixture.has_method("reset_fixture"):fixture.reset_fixture()
	_apply_candidate_awareness()
func _contact_confirmed(_actor: Node2D,target: Node2D,point: Vector2,serial: int,_kind: StringName) -> void:
	last_contact="HIT %s / SWING %s"%[target.name,serial]
	contact_marks.append({"point":point,"time":0.14})
	queue_redraw()
func _movement_event(event_name: StringName, data: Dictionary = {}) -> void:
	if record_remaining>0:record_events.append({"raw_seconds":(Time.get_ticks_usec()-record_started)/1000000.0,"physics_tick":Engine.get_physics_frames(),"event":String(event_name),"data":data})
	last_event=String(event_name).replace("_"," ").to_upper()
	if String(event_name).ends_with("denied"):
		feedback_text=last_event+": "+str(data.get("reason","unavailable")).replace("_"," ").to_upper()
		feedback_timer=1.2
	elif event_name==&"drop_geometry_blocked":
		feedback_text="GEOMETRY BLOCKED / CLEAR SUPPORT OR RESET"
		feedback_timer=1.2
	elif event_name==&"drop_cleanup_blocked":
		feedback_text="CLEARING PLATFORM"
		feedback_timer=0.6
	elif event_name==&"dive_impact":
		feedback_text="DIVE / GROUND CONTACT"
		feedback_timer=0.5
	elif event_name==&"hard_land_started":
		feedback_text="HARD %s / %.0f PX FALL"%[str(data.get("kind","ordinary")).to_upper(),float(data.get("fall_distance",0))]
		feedback_timer=0.7
	elif event_name==&"landed" and bool(data.get("fall_protected",false)):
		feedback_text="DIVE > ROLL / FALL RECOVERY AVOIDED"
		feedback_timer=0.7
	if event_name==&"defense_resolved":
		var outcome:=str(data.get("outcome",""))
		if outcome in ["guarded","parried","hurt","evaded"]:
			feedback_text={"guarded":"GUARD / DAMAGE ","parried":"PARRY / INCOMING HIT STOPPED","hurt":"HURT / DAMAGE ","evaded":"ROLL / ATTACK EVADED"}[outcome]
			if outcome in ["guarded","hurt"]:feedback_text+="%.2f"%float(data.get("residual_damage",0))
			feedback_timer=1.1
	elif event_name==&"shield_counter_confirmed":
		feedback_text="PARRY / COUNTER CONFIRMED";feedback_timer=1.1
	elif event_name==&"shield_reflection_confirmed":
		feedback_text="PARRY / PHYSICAL REFLECTION";feedback_timer=1.1
	elif event_name==&"entry_assist_resolved":
		var reason:=str(data.get("reason",""))
		if reason=="applied":
			feedback_text="ENTRY AIM / TURNED "+("LEFT" if int(data.get("facing_after",1))<0 else "RIGHT")
			feedback_timer=0.8
		elif reason=="no_offer":
			feedback_text="ENTRY AIM / "+str(entry_host_diagnostics().get("reason","no offer")).replace("_"," ").to_upper()
			feedback_timer=0.8
		elif reason=="manual_input":
			feedback_text="ENTRY AIM / MANUAL DIRECTION WINS";feedback_timer=0.8
	elif event_name==&"charge_started":
		feedback_text="LOADING / HOLD TO THRUST; RELEASE TO CANCEL";feedback_timer=0.65
	elif event_name==&"charge_cancelled":
		feedback_text="CHARGE CANCELLED / "+str(data.get("reason","released")).replace("_"," ").to_upper();feedback_timer=0.9
	elif event_name==&"charge_committed":
		feedback_text="THRUST / RELEASE BEFORE THE NEXT ATTACK";feedback_timer=0.8
	recent_events.append({"tick":Engine.get_physics_frames(),"event":String(event_name),"data":data})
	while recent_events.size()>30: recent_events.pop_front()
func _noise_event(origin:Vector2,kind:StringName,loudness:float,source:Variant) -> void:
	if not origin.is_finite():return
	if is_instance_valid(source) and source is Node and (not source.is_inside_tree() or source.is_queued_for_deletion()):return
	if kind in [&"guard",&"parry",&"prop_launch",&"prop_impact",&"prop_break"]:
		noise_marks.append({"point":origin,"kind":String(kind),"time":0.3})
		while noise_marks.size()>32:noise_marks.pop_front()
	if record_remaining>0:
		record_noises.append({"raw_seconds":(Time.get_ticks_usec()-record_started)/1000000.0,"physics_tick":Engine.get_physics_frames(),"origin":[origin.x,origin.y],"kind":String(kind),"loudness":loudness,"source_id":source.get_instance_id() if is_instance_valid(source) else 0})
func _guard_fixture() -> Node2D:
	if not is_instance_valid(player):return null
	var nearest:Node2D=null
	var distance:=180.0
	for name_ in ["Melee","Projectile","Prop"]:
		var fixture:=get_node_or_null("Geometry/GuardCourse/"+name_) as Node2D
		if fixture and fixture.global_position.distance_to(player.global_position)<distance:
			distance=fixture.global_position.distance_to(player.global_position)
			nearest=fixture
	return nearest
func request_fixture_attack() -> void:
	if paused:return
	var fixture:=_guard_fixture()
	if fixture==null:
		feedback_text="V / OPEN DEFENSE TESTS";feedback_timer=1.2
		return
	var accepted:bool=fixture.request_attack()
	feedback_text=(String(fixture.name).to_upper()+" / WATCH THE TELEGRAPH") if accepted else "FIXTURE / BUSY"
	feedback_timer=0.6
	if record_remaining>0:record_events.append({"raw_seconds":(Time.get_ticks_usec()-record_started)/1000000.0,"physics_tick":Engine.get_physics_frames(),"event":"inspection_attack_requested","data":{"fixture":String(fixture.name),"accepted":accepted}})
func snapshot() -> Dictionary:
	if is_instance_valid(player) and player.has_method("telemetry"):
		var state:Dictionary=player.telemetry()
		state["inspection_entry_assist_enabled"]=bool(player.get("enable_attack_entry_assist"))
		return state
	return {}
func _physics_process(dt: float) -> void:
	if not is_instance_valid(player): return
	if player.global_position.y>430: reset_player.call_deferred()
	if not paused:
		# Keep high air-jumps below the HUD while retaining a stable ground view.
		var target := Vector2(clampf(player.global_position.x,320,4180),clampf(player.global_position.y+70,-100,180))
		camera.position=camera.position.lerp(target,1.0-exp(-8.0*dt))
func _process(dt: float) -> void:
	if panel: panel.queue_redraw()
	if not paused:
		feedback_timer=maxf(0,feedback_timer-dt)
		for mark in contact_marks:mark.time-=dt
		contact_marks=contact_marks.filter(func(mark):return mark.time>0)
		for mark in noise_marks:mark.time-=dt
		noise_marks=noise_marks.filter(func(mark):return mark.time>0)
		queue_redraw()
	if record_remaining<=0: return
	record_remaining-=dt
	record_clock+=dt
	if record_clock>=1.0/60.0:
		record_clock-=1.0/60.0
		var name_ := "frame_%04d.jpg" % sample_index
		get_viewport().get_texture().get_image().save_jpg("res://delivery/combat_pc_capture/"+name_,0.94)
		record_frames.append({"file":name_,"raw_seconds":(Time.get_ticks_usec()-record_started)/1000000.0})
		sample_index+=1
	var t := snapshot()
	var v: Vector2=t.get("velocity",Vector2.ZERO)
	var at: Vector2=player.global_position if is_instance_valid(player) else Vector2.ZERO
	record_trace.append({"raw_seconds":(Time.get_ticks_usec()-record_started)/1000000.0,"position":[at.x,at.y],"velocity":[v.x,v.y],"state":str(t.get("main_action",t.get("state",""))),"pose":str(t.get("pose","")),"facing":t.get("facing",1),"weapon_phase":str(t.get("weapon_phase","idle")),"hitpause":t.get("hitpause_remaining",0),"roll_phase":str(t.get("roll_phase","")),"invulnerable":t.get("roll_invulnerable",false),"contact":last_contact,"air_jumps_left":t.get("air_jumps_left",0),"air_roll_available":t.get("air_roll_available",false),"dive_available":t.get("dive_available",false),"climb_phase":str(t.get("climb_phase","")),"climb_jump_grace":t.get("climb_jump_grace",0),"wall_phase":str(t.get("wall_phase","")),"wall_run_progress":t.get("wall_run_progress",0),"wall_kick_grace":t.get("wall_kick_grace",0),"fall_distance":t.get("fall_distance",0),"grounded":t.get("grounded",false),"floor_normal":t.get("floor_normal",Vector2.UP),"hard_land_phase":str(t.get("hard_land_phase","")),"hard_land_kind":str(t.get("hard_land_kind","")),"hard_land_relative_impact_speed":t.get("hard_land_relative_impact_speed",0),"roll_serial":t.get("roll_serial",0),"roll_fall_protected":t.get("roll_fall_protected",false),"jump_buffer":t.get("jump_buffer",0),"roll_buffer":t.get("roll_buffer",0),"attack_buffer":t.get("attack_buffer",0),"shield_phase":str(t.get("shield_phase","idle")),"shield_serial":t.get("shield_serial",0),"shield_parry_open":t.get("shield_parry_open",false),"shield_lock_remaining":t.get("shield_lock_remaining",0),"last_defense_outcome":str(t.get("last_defense_outcome","")),"paused":paused,"attack_serial":t.get("attack_serial",0),"attack_step_index":t.get("attack_step_index",-1),"attack_step_label":str(t.get("attack_step_label","")),"attack_pose_id":str(t.get("attack_pose_id","")),"chain_serial":t.get("chain_serial",0),"chain_next_step":t.get("chain_next_step",-1),"chain_retention_remaining":t.get("chain_retention_remaining",0),"chain_pending_input_id":t.get("chain_pending_input_id",0),"chain_pending_step":t.get("chain_pending_step",-1),"chain_pending_remaining":t.get("chain_pending_remaining",0),"attack_input_id":t.get("attack_input_id",0),"attack_consumed_input_id":t.get("attack_consumed_input_id",0),"melee_reuse_lock_remaining":t.get("melee_reuse_lock_remaining",0),"input":{"x":Input.get_axis("cp_left","cp_right"),"y":Input.get_axis("cp_up","cp_down"),"jump":Input.is_action_pressed("cp_jump"),"roll":Input.is_action_pressed("cp_roll"),"attack":Input.is_action_pressed("cp_attack"),"shield":Input.is_action_pressed("cp_shield")}})
	# Keep the optional input ownership visible without conflating a held
	# episode, a physical edge, a synthetic request and a committed strike.
	record_trace[-1].merge({"inspection_melee_mode":melee_mode,"entry_assist_enabled":t.get("inspection_entry_assist_enabled",false),"entry_assist_query_count":t.get("entry_assist_query_count",0),"entry_assist_token":t.get("entry_assist_token",0),"entry_assist_attack_serial":t.get("entry_assist_attack_serial",0),"entry_assist_reason":str(t.get("entry_assist_reason","")),"entry_assist_manual_x":t.get("entry_assist_manual_x",0),"entry_assist_facing_before":t.get("entry_assist_facing_before",1),"entry_assist_facing_after":t.get("entry_assist_facing_after",1),"entry_host":entry_host_diagnostics(),"input_mode":str(t.get("input_mode","fresh_only")),"attack_hold_id":t.get("attack_hold_id",0),"attack_hold_armed":t.get("attack_hold_armed",false),"attack_hold_released":t.get("attack_hold_released",true),"attack_rearm_required":t.get("attack_rearm_required",false),"attack_request_kind":str(t.get("attack_request_kind","")),"attack_request_id":t.get("attack_request_id",0),"attack_origin_hold_id":t.get("attack_origin_hold_id",0),"pending_attack_request_id":t.get("pending_attack_request_id",0),"pending_attack_request_kind":str(t.get("pending_attack_request_kind","")),"attack_facing":t.get("attack_facing",1),"attack_step_elapsed":t.get("attack_step_elapsed",0),"repeat_restart_remaining":t.get("repeat_restart_remaining",0),"charge_phase":str(t.get("charge_phase","")),"charge_elapsed":t.get("charge_elapsed",0),"charge_progress":t.get("charge_progress",0),"charge_duration":t.get("charge_duration",0),"charge_serial":t.get("charge_serial",0),"charge_role":str(t.get("charge_role",""))})
	if record_remaining<=0:
		var f:=FileAccess.open("res://delivery/MOKSHA-Combat-PC-Capture.json",FileAccess.WRITE)
		if f:f.store_string(JSON.stringify({"controller_sha256":record_controller_sha256,"configuration":record_configuration,"frames":record_frames,"trace":record_trace,"events":record_events,"noises":record_noises},"  "))
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_9:
		station=event.physical_keycode-KEY_1
		reset_player.call_deferred()
		return
	match event.physical_keycode:
		KEY_0:
			station=9
			reset_player.call_deferred()
		KEY_B:
			station=10
			reset_player.call_deferred()
		KEY_N:
			station=11
			reset_player.call_deferred()
		KEY_V:
			guard_mode=(guard_mode+1)%3
			station=13+guard_mode
			reset_player.call_deferred()
		KEY_F: request_fixture_attack()
		KEY_Y: cycle_melee_mode()
		KEY_I: toggle_entry_assist()
		KEY_U: toggle_candidate_awareness()
		KEY_L:
			station=17
			reset_player.call_deferred()
		KEY_T:
			station=16
			reset_player.call_deferred()
		KEY_M:
			station=12
			reset_player.call_deferred()
		KEY_H:
			hard_landing_enabled=not hard_landing_enabled
			if is_instance_valid(player) and "enable_hard_landing" in player:player.enable_hard_landing=hard_landing_enabled
			feedback_text="HARD LANDING / "+("ON" if hard_landing_enabled else "OFF")
			feedback_timer=1.2
		KEY_R: reset_player.call_deferred()
		KEY_G:
			wall_ability_enabled=not wall_ability_enabled
			if is_instance_valid(player) and "allow_wall_run" in player:player.allow_wall_run=wall_ability_enabled
			feedback_text="WALL ABILITY / "+("ON" if wall_ability_enabled else "OFF")
			feedback_timer=1.2
		KEY_TAB: details=not details
		KEY_ESCAPE:
			paused=not paused
			_set_simulation(not paused)
		KEY_P: get_viewport().get_texture().get_image().save_png("res://delivery/MOKSHA-Combat-PC-Movement.png")
		KEY_O:
			DirAccess.make_dir_recursive_absolute("res://delivery/combat_pc_capture")
			record_remaining=10
			record_clock=0
			record_started=Time.get_ticks_usec()
			record_controller_sha256=player.get_script().get_source_code().sha256_text()
			record_configuration={"inspection_mode":melee_mode,"mode_label":MELEE_MODE_NAMES[melee_mode],"entry_assist_enabled":entry_assist_enabled,"candidate_awareness":candidate_awareness,"lab_sha256":get_script().get_source_code().sha256_text(),"entry_host_sha256":_entry_host().get_script().get_source_code().sha256_text(),"resources":{}}
			for resource_name in ["melee_input_profile.gd","melee_step.gd","melee_chain.gd","light_chain.tres","held_repeat.tres","held_charge.tres"]:
				var resource_path:String="res://combat_pc/resources/"+resource_name
				if FileAccess.file_exists(resource_path):record_configuration.resources[resource_name]=FileAccess.get_sha256(resource_path)
			record_frames.clear()
			record_trace.clear()
			record_events.clear()
			record_noises.clear()
			sample_index=0
func _set_simulation(enabled: bool) -> void:
	if record_remaining>0:
		record_events.append({"raw_seconds":(Time.get_ticks_usec()-record_started)/1000000.0,"physics_tick":Engine.get_physics_frames(),"event":"inspection_pause_changed","data":{"paused":not enabled}})
	if is_instance_valid(player): player.set_physics_process(enabled)
	for node in $Geometry.find_children("*","",true,false):
		if node.has_method("set_fixture_paused"):
			node.set_fixture_paused(not enabled)
		elif not node is RigidBody2D:
			node.set_physics_process(enabled)
			node.set_process(enabled)
func _draw() -> void:
	var t:=snapshot()
	if details and bool(t.get("strike_active",false)):
		var center:Vector2=t.get("strike_center",Vector2.ZERO)
		var size:Vector2=t.get("strike_size",Vector2.ZERO)
		draw_rect(Rect2(center-size*0.5,size),Color(1,0.65,0.32,0.15))
		draw_rect(Rect2(center-size*0.5,size),Color(1,0.65,0.32,0.7),false,0.5)
	for mark in contact_marks:
		var point:Vector2=mark.point
		draw_line(point-Vector2(4,4),point+Vector2(4,4),Color("fff1cf"),1)
		draw_line(point+Vector2(-4,4),point+Vector2(4,-4),Color("fff1cf"),1)
	for mark in noise_marks:
		var alpha:=float(mark.time)/0.3
		draw_circle(mark.point,lerpf(8,2,alpha),Color(0.78,0.9,1,alpha),false,0.6)
	for x in range(0,4501,24): draw_line(Vector2(x,48),Vector2(x,306),Color(0.16,0.2,0.24,0.2),0.35)
	for y in range(54,307,24): draw_line(Vector2(0,y),Vector2(4500,y),Color(0.16,0.2,0.24,0.2),0.35)
	draw_string(ThemeDB.fallback_font,Vector2(42,298),"RUN / RELEASE / REVERSE",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("8ea5b5"))
	draw_string(ThemeDB.fallback_font,Vector2(1850,298),"9  TOWARD WALL > SPACE TO KICK   /   G  ABILITY ON-OFF",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("8ea5b5"))
	draw_line(Vector2(1050,330),Vector2(1140,330),Color("d7726c"),1.0)
	draw_string(ThemeDB.fallback_font,Vector2(1056,347),"FALL = RESET",HORIZONTAL_ALIGNMENT_LEFT,-1,7,Color("d7726c"))
