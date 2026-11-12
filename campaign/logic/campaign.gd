extends "res://demo/mission.gd"
## Campaign orchestrator. Original controller, damage pipeline and demo stay intact.
const BuildRules=preload("res://campaign/logic/build_rules.gd")
const CampaignCheckpoint=preload("res://campaign/logic/checkpoint_codec.gd")
const CheckpointStore=preload("res://campaign/save/checkpoint_store.gd")
const RunSnapshot=preload("res://campaign/state/run_snapshot.gd")
const CampaignData=preload("res://campaign/logic/campaign_data.gd")
const ObjectiveScene=preload("res://campaign/logic/objective.tscn")
const DoorScene=preload("res://campaign/logic/objective_door.tscn")
const HazardScene=preload("res://campaign/logic/hazard.tscn")
const CampaignInputGate=preload("res://campaign/logic/campaign_input_gate.gd")
const CAMPAIGN_SAVE="user://moksha_five_levels_v1.json"
var goals:Array[Node]=[]
var blackboard:Node
var completed_goals:Dictionary={}
var rewards:Dictionary={}
var lens:="neutral"
var upgrades:Array[String]=[]
var journal_page:=0
var level_seconds:Dictionary={}
var level_receipts:Array[Dictionary]=[]
var campaign_ending:=""
var art:Node2D
var actor_paint:Node
var object_paint:Node
var debug_wireframe:=false
var map_open:=false
var _loading_campaign:=false
var _completed_snapshot:Dictionary={}
var camera_follow=preload("res://campaign/presentation/camera_follow.gd").new()
var _input_gate=CampaignInputGate.new()
var _audio_feedback=preload("res://campaign/presentation/audio_feedback.gd").new()
var _input_tick_active:=false
var _input_tick_source:Variant=null
var _build_actor_id:=0
var _build_force:=-1.0
var _focus_pause_active:=false
var _focus_resume_state:="playing"
var _level_transition_snapshot:Dictionary={}
var _controller_bindings:Node
var companion:Node
var gamepad_navigation:Node
func _ready()->void:
	var catalog:=_load_catalog()
	if not catalog.ok:
		_show_content_error(str(catalog.error))
		return
	sectors.assign(catalog.sectors)
	# Register the preserved device mapping before title/Continue can share C.
	preload("res://combat_pc/player.gd").ensure_default_inputs()
	_controller_bindings=preload("res://campaign/input/controller_bindings.gd").new()
	_controller_bindings.bindings_ready.connect(_capture_input_boundary)
	add_child(_controller_bindings)
	gamepad_navigation=preload("res://campaign/input/gamepad_navigation.gd").new()
	gamepad_navigation.bind(self);add_child(gamepad_navigation)
	blackboard=preload("res://campaign/vendor/beehave/blackboard.gd").new()
	add_child(blackboard)
	super._ready()
	# The base scene creates its sonar while still on the title, before a room
	# exists. Replace that empty adapter, preserving its configured tuning and
	# presentation order without resetting a live script instance.
	var previous_sonar := sonar
	var sonar_index := previous_sonar.get_index()
	sonar = CanvasLayer.new()
	sonar.set_script(preload("res://campaign/presentation/campaign_sonar.gd"))
	sonar.tuning = previous_sonar.tuning
	sonar.layer = previous_sonar.layer
	sonar.process_mode = previous_sonar.process_mode
	add_child(sonar)
	move_child(sonar, sonar_index)
	previous_sonar.free()
	var appearance:Resource=hud.appearance
	hud.set_script(preload("res://campaign/views/campaign_hud_owner.gd"))
	hud.appearance=appearance
	hud.get_node("View").set_script(preload("res://campaign/views/campaign_hud.gd"))
	hud.set_snapshot(_hud_snapshot())
	get_window().focus_exited.connect(_on_window_focus_exited)
	companion=preload("res://campaign/narrative/companion_observer.gd").new()
	add_child(companion);companion.bind(self)
func _load_catalog()->Dictionary:
	return CampaignData.load_catalog()

func _show_content_error(message:String)->void:
	# Fail closed before creating actors, reading saves or starting the demo host.
	set_process(false);set_physics_process(false);set_process_input(false);set_process_unhandled_input(false);set_process_unhandled_key_input(false)
	var layer:=CanvasLayer.new();layer.layer=100;add_child(layer)
	var panel:=ColorRect.new();panel.color=Color(0.04,0.04,0.06);panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);layer.add_child(panel)
	var label:=Label.new();label.text="CAMPAIGN CONTENT ERROR\n\n"+message+"\n\nNo campaign was started and no save was changed.\nRestore the complete game files, then restart."
	label.position=Vector2(24,32);label.size=Vector2(590,280);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(label)

func start_new(skip_intro:=false)->void:
	_level_transition_snapshot.clear()
	_focus_pause_active=false
	rewards.clear();upgrades.clear();level_seconds.clear();level_receipts.clear();campaign_ending=""
	_completed_snapshot.clear()
	super.start_new(skip_intro)
func _create_player_health()->Node:
	# Bind the campaign depletion policy before DefeatResponse's _ready binding,
	# preserving the existing policy order without replacing a live authority.
	var adapter:=Node.new()
	adapter.set_script(preload("res://campaign/logic/build_health.gd"))
	adapter.depleted.connect(_on_defeat)
	return adapter

func load_sector(index:int)->void:
	if not _level_transition_snapshot.is_empty():
		if index==int(_level_transition_snapshot.to):_level_transition_snapshot.clear()
		else:_cancel_sector_transition()
	_capture_input_boundary()
	_audio_feedback.retire_room(audio)
	_pending_sector=-1;_pending_retry=false
	_loading_campaign=true
	goals.clear();completed_goals.clear();art=null;actor_paint=null;object_paint=null
	if is_instance_valid(blackboard):blackboard.set_value("objectives",{})
	super.load_sector(index)
	var d:Dictionary=sectors[sector]
	for spec in d.get("captains",[]):
		var scene_path:String="res://campaign/enemies/lancer.tscn" if spec.kind=="captain_lancer" else "res://campaign/enemies/keeper.tscn"
		var captain=load(scene_path).instantiate()
		captain.kind=spec.kind;captain.max_health=8.0;captain.attack_damage_override=12.0
		captain.room_left=maxf(40,spec.at.x-550);captain.room_right=minf(float(d.width)-50,spec.at.x+550);captain.position=spec.at
		room.add_child(captain);captain.configure(player,bus);captain.defeated.connect(_on_enemy_defeated);enemies.append(captain)
	for spec in d.get("objectives",[]):
		var objective=ObjectiveScene.instantiate()
		objective.configure(spec,self)
		room.add_child(objective)
		objective.changed.connect(_goal_changed.bind(objective))
		goals.append(objective)
	for spec in d.get("objective_doors",[]):
		var door=DoorScene.instantiate()
		door.position=spec.at;door.door_size=spec.size;door.required_ids.assign(spec.get("requires",[]));door.host=self
		room.add_child(door)
	for spec in d.get("hazards",[]):
		var hazard=HazardScene.instantiate()
		hazard.position=spec.at;hazard.hazard_size=spec.size;hazard.period=maxf(1,spec.get("period",3.6));hazard.duty=clampf(spec.get("duty",0.5),0.1,0.8);hazard.phase=spec.get("phase",0.0);hazard.damage=spec.get("damage",8.0);hazard.host=self
		room.add_child(hazard)
	if ResourceLoader.exists("res://campaign/presentation/campaign_scenery.gd"):
		art=load("res://campaign/presentation/campaign_scenery.tscn").instantiate();room.add_child(art)
		room.backdrop.visible=false
		if art.has_method("configure"):art.configure(d)
		elif art.has_method("configure_sector"):art.configure_sector(d)
		art.set_sight_enabled(not blind)
	actor_paint=Node.new();actor_paint.set_script(preload("res://campaign/presentation/actor_presentation.gd"));room.add_child(actor_paint)
	actor_paint.bind(player,enemies);actor_paint.set_sight_enabled(not blind);actor_paint.set_debug_wireframe(debug_wireframe)
	object_paint=Node.new();object_paint.set_script(preload("res://campaign/presentation/object_presentation.gd"));room.add_child(object_paint)
	object_paint.bind(room);object_paint.set_sight_enabled(not blind);object_paint.set_debug_wireframe(debug_wireframe)
	_apply_build()
	_loading_campaign=false
	camera.position=camera_follow.reset(player.global_position,sectors[sector])
	_update_gate()
	_save_checkpoint()
func goal_done(id:String)->bool:
	var facts:Dictionary=blackboard.get_value("objectives",{}) if is_instance_valid(blackboard) else completed_goals
	return bool(facts.get(id,false))
func _goal_changed(objective:Node)->void:
	completed_goals[objective.objective_id]=objective.completed
	blackboard.set_value("objectives",completed_goals.duplicate())
	if objective.completed:
		var reward_id:String=str(sectors[sector].id)+"/"+objective.objective_id
		if objective.specification.has("reward") and not rewards.has(reward_id):
			rewards[reward_id]=objective.specification.reward
			_apply_build()
		var detail:String=objective.specification.get("text","")
		announce(objective.label+" · COMPLETE"+(" — "+detail if not detail.is_empty() else ""),5)
		bus.emit_noise(objective.global_position-Vector2(0,20),&"prop_impact",1.2,objective)
	else:announce("CIRCUIT %d · target %d"%[objective.setting,objective.target],2)
	_update_gate()
	_save_checkpoint()
func _apply_build()->void:
	if not is_instance_valid(player):return
	# Apply from immutable base every time, never stack on a previous retry.
	_apply_trade()
	var build:Dictionary=BuildRules.evaluate(lens,rewards,upgrades)
	var force:float=build.force
	var capacity:float=build.capacity
	player.profile.run_speed*=float(build.speed)
	# Swapping an actor's melee resource legitimately retires its live strike.
	# Health/speed-only pickups must not cancel a combo by swapping it needlessly.
	if _build_actor_id!=player.get_instance_id() or not is_equal_approx(_build_force,force):
		player.melee_chain=preload("res://combat_pc/resources/responsive_chain.tres").duplicate(true)
		for step in player.melee_chain.steps:step.damage*=force
		_build_actor_id=player.get_instance_id();_build_force=force
	if _loading_campaign or not is_equal_approx(health.capacity,capacity):
		health.set_capacity(capacity,_loading_campaign)
func _raw_campaign_input()->Dictionary:
	var source:Variant=_input_tick_source if _input_tick_active else input_override
	if source is Dictionary:return source.duplicate()
	var raw:=_input_gate.sample_device()
	return _controller_bindings.extend_frame(raw) if is_instance_valid(_controller_bindings) else raw
func _capture_input_boundary()->void:
	_input_gate.suppress_held(_raw_campaign_input())
func _physics_process(dt:float)->void:
	var before_elapsed:=elapsed
	var raw:=_raw_campaign_input()
	if state!="playing" or _pending_sector>=0 or _pending_retry:
		_input_gate.suppress_held(raw)
	_input_tick_source=input_override
	_input_tick_active=true
	input_override=_input_gate.filter_frame(raw)
	# Focus loss suspends queued retries and elevator transitions too. Loading
	# a room unpauses the base scene, so no queued load may pass this boundary.
	if not _focus_pause_active:
		super._physics_process(dt)
	input_override=_input_tick_source
	_input_tick_source=null
	_input_tick_active=false
	if state=="playing":camera.position=camera_follow.follow(player.global_position,player.velocity,sectors[sector],dt)
	var level:int=int(sectors[sector].get("level",1)) if not sectors.is_empty() else 1
	var active_delta:=elapsed-before_elapsed
	if active_delta>0:level_seconds[str(level)]=float(level_seconds.get(str(level),0))+active_delta
	if is_instance_valid(art):
		art.set_sight_enabled(not blind)
		if art.has_method("update_view"):art.update_view(camera.position,Vector2(640,360))
	if is_instance_valid(actor_paint):actor_paint.set_sight_enabled(not blind)
	if is_instance_valid(object_paint):object_paint.set_sight_enabled(not blind)
	for goal in goals:
		if is_instance_valid(goal):goal.get_node("Presentation").visible=not blind
func _update_gate()->void:
	if not is_instance_valid(room):return
	super._update_gate()
	if not _loading_campaign:
		room.gate_open=room.gate_open and goals.all(func(goal):return goal.optional or goal.completed)
		if sectors[sector].get("captain_required",false):room.gate_open=room.gate_open and not enemies.any(func(enemy):return is_instance_valid(enemy) and not enemy.dead and str(enemy.kind).begins_with("captain_"))
func interact()->void:
	if state!="playing" or _pending_sector>=0 or _pending_retry:return
	var goal:=_nearby_objective()
	if is_instance_valid(goal):
		if not goal.interact():
			var missing:Array[String]=[]
			for id in goal.required_ids:
				if not goal_done(id):missing.append(_objective_label(id))
			announce("Requires: "+", ".join(missing) if not missing.is_empty() else "Strike the circuit breaker [J]" if goal.kind=="breaker" else "Move a physical cargo onto the pressure plate",3)
		return
	var d:Dictionary=sectors[sector]
	var at_exit:=_near(Vector2(float(d.width)-45,float(d.get("gate_y",300))),65)
	if at_exit and not room.gate_open and sectors[sector].get("captain_required",false) and enemies.any(func(enemy):return is_instance_valid(enemy) and not enemy.dead and str(enemy.kind).begins_with("captain_")):
		announce("The captain holds the seal · parry or evade the committed attack",3);return
	if at_exit and not room.gate_open and goals.any(func(goal):return not goal.optional and not goal.completed):
		announce("Complete the remaining field objectives · TAB journal",3);return
	if at_exit and room.gate_open:
		if sector==sectors.size()-1:
			state="final_choice";get_tree().paused=true;return
		_level_transition_snapshot={"to":sector+1,"metrics":metrics.size(),"receipts":level_receipts.size(),"upgrades":upgrades.size()}
		var next_level:int=int(sectors[sector+1].get("level",1))
		if next_level!=int(d.get("level",1)):
			metrics.append({"sector":sector,"seconds":sector_elapsed,"blind":blind,"health":health.current_health})
			level_receipts.append({"level":d.level,"active_seconds":level_seconds.get(str(d.level),0),"completed_district":d.id})
			state="upgrade";get_tree().paused=true;return
	var audio_children_before:=audio.get_child_count()
	super.interact()
	if state=="archive":_audio_feedback.finish_modal_since(audio,audio_children_before,"tap")
	if _pending_sector<0:_level_transition_snapshot.clear()
func choose_sight(accept:bool)->void:
	if state=="choice" and is_instance_valid(companion):companion.sight_chosen(accept)
	super.choose_sight(accept)
	_apply_build()
	if is_instance_valid(art):art.set_sight_enabled(not blind)
	if is_instance_valid(actor_paint):actor_paint.set_sight_enabled(not blind)
	if is_instance_valid(object_paint):object_paint.set_sight_enabled(not blind)
func _on_window_focus_exited()->void:
	if not is_inside_tree():return
	if state not in ["playing","transition","intro"] and _pending_sector<0 and not _pending_retry:return
	_capture_input_boundary()
	_focus_resume_state="intro" if state=="intro" else "playing"
	_focus_pause_active=true
	state="paused"
	get_tree().paused=true

func _unhandled_key_input(event:InputEvent)->void:
	if state!="playing":_capture_input_boundary()
	_handle_campaign_key(event)
	if state!="playing" or _pending_sector>=0 or _pending_retry:_capture_input_boundary()
func _handle_campaign_key(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	var key:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	# Mute is global, including journal/upgrade/final choice and queued loads.
	if key==KEY_M:
		audio.toggle_mute();return
	if _focus_pause_active:
		if key==KEY_ESCAPE:
			_focus_pause_active=false
			state="transition" if _pending_sector>=0 else _focus_resume_state
			get_tree().paused=state=="intro";return
		if key==KEY_R:
			_cancel_sector_transition()
			_pending_sector=-1;_pending_retry=true;return
		if key==KEY_N:
			_pending_sector=-1;_pending_retry=false;_focus_pause_active=false
			show_title();return
	if _pending_sector>=0 or _pending_retry:return
	if state=="title" and key in [KEY_1,KEY_2,KEY_3]:
		lens={KEY_1:"neutral",KEY_2:"strength",KEY_3:"agility"}[key];return
	if key==KEY_F8:
		debug_wireframe=not debug_wireframe
		if is_instance_valid(actor_paint):actor_paint.set_debug_wireframe(debug_wireframe)
		if is_instance_valid(object_paint):object_paint.set_debug_wireframe(debug_wireframe)
		return
	if state=="playing" and key==KEY_TAB:
		journal_page=0;state="journal";get_tree().paused=true;return
	if state=="journal":
		if key in [KEY_LEFT,KEY_A]:journal_page=maxi(0,journal_page-1);return
		if key in [KEY_RIGHT,KEY_D]:journal_page=mini(maxi(0,ceili(_journal_rows().size()/5.0)-1),journal_page+1);return
		if key in [KEY_TAB,KEY_ESCAPE]:state="playing";get_tree().paused=false
		return
	if state=="upgrade":
		if key in [KEY_J,KEY_K,KEY_L]:
			upgrades.append({KEY_J:"force",KEY_K:"agility",KEY_L:"vitality"}[key])
			_pending_sector=sector+1;state="transition";get_tree().paused=false
		return
	if state=="final_choice":
		if key in [KEY_J,KEY_K]:
			campaign_ending="public_record" if key==KEY_J else "local_custody"
			metrics.append({"sector":sector,"seconds":sector_elapsed,"blind":blind,"health":health.current_health})
			level_receipts.append({"level":5,"active_seconds":level_seconds.get("5",0),"completed_district":sectors[sector].id})
			complete_run()
		return
	if event.physical_keycode==0:
		var normalized:InputEventKey=event.duplicate()
		normalized.physical_keycode=key
		super._unhandled_key_input(normalized)
	else:super._unhandled_key_input(event)
func _cancel_sector_transition()->void:
	if _level_transition_snapshot.is_empty():return
	metrics.resize(mini(metrics.size(),int(_level_transition_snapshot.metrics)))
	level_receipts.resize(mini(level_receipts.size(),int(_level_transition_snapshot.receipts)))
	upgrades.resize(mini(upgrades.size(),int(_level_transition_snapshot.upgrades)))
	_level_transition_snapshot.clear()
func show_title()->void:
	_cancel_sector_transition()
	_pending_sector=-1;_pending_retry=false;_focus_pause_active=false
	super.show_title()
func complete_run()->void:
	state="complete";get_tree().paused=true;sonar.set_blind(false)
	if is_instance_valid(art):art.set_sight_enabled(true)
	audio.play_sound("win",-8,1)
	if save_enabled:
		var file=FileAccess.open("user://moksha_five_levels_results.json",FileAccess.WRITE)
		if file:file.store_string(JSON.stringify({"ending":campaign_ending,"active_seconds":elapsed,"levels":level_receipts,"districts":metrics,"lens":lens,"upgrades":upgrades,"deaths":deaths,"kills":kills},"\t"))
func _on_noise(origin:Vector2,kind:StringName,loudness:float,source:Node)->void:
	var audio_request_before:Dictionary=audio.last_spatial_sound if is_instance_valid(audio) else {}
	var audio_children_before:=audio.get_child_count() if is_instance_valid(audio) else 0
	super._on_noise(origin,kind,loudness,source)
	if is_instance_valid(audio) and kind==&"player_damage" and not is_same(audio.last_spatial_sound,audio_request_before):
		_audio_feedback.observe_damage(audio,audio_children_before)
func _on_defeat()->void:
	var was_playing:=state=="playing"
	super._on_defeat()
	if was_playing and state=="dead":_audio_feedback.finish_damage()
func _read_checkpoint()->Dictionary:
	var result:=_decode_campaign_checkpoint()
	_checkpoint_error=""
	if not result.get("ok",false) and FileAccess.file_exists(CAMPAIGN_SAVE):
		_checkpoint_error=str(result.get("error","The campaign checkpoint contains incomplete or invalid progress."))
	return result
func _decode_campaign_checkpoint()->Dictionary:
	return CheckpointStore.read(CAMPAIGN_SAVE,sectors)
func _save_checkpoint()->void:
	if not save_enabled or _loading_campaign:return
	var encoded:Dictionary=Checkpoint.encode({"metrics":metrics,"sector":sector,"blind":blind,"caches":caches,"kills":kills,"deaths":deaths,"seconds":elapsed},sectors)
	if not encoded.ok:
		_report_checkpoint_write_error("Campaign progress could not be encoded: "+str(encoded.get("error","invalid progress")))
		return
	if not _preserve_invalid_checkpoint():return
	blackboard.set_value("build",{"lens":lens,"upgrades":upgrades.duplicate()})
	var raw:Dictionary={"campaign_version":CampaignCheckpoint.VERSION,"progress":encoded.data}
	raw.merge(RunSnapshot.capture({"lens":lens,"upgrades":upgrades,"rewards":rewards,"level_seconds":level_seconds,"level_receipts":level_receipts}))
	var result:=CheckpointStore.commit(CAMPAIGN_SAVE,raw)
	if not result.ok:
		_report_checkpoint_write_error(str(result.error));return
	continue_available=true;_checkpoint_write_error="";_checkpoint_error=""
func _report_checkpoint_write_error(message:String)->void:
	_checkpoint_write_error=message
	continue_available=_decode_campaign_checkpoint().get("ok",false)
	announce("CHECKPOINT NOT SAVED · Keep the game open; check disk space and folder access.",8)
func _preserve_invalid_checkpoint()->bool:
	var result:=CheckpointStore.preserve_invalid(CAMPAIGN_SAVE,sectors)
	if not result.ok:_report_checkpoint_write_error(str(result.error))
	return result.ok
func continue_run()->void:
	var saved:=_read_checkpoint()
	if not saved.get("ok",false):continue_available=false;return
	_level_transition_snapshot.clear()
	_focus_pause_active=false
	var extra:Dictionary=saved.campaign
	lens=extra.lens;upgrades.assign(extra.upgrades);rewards=extra.rewards
	level_seconds=extra.get("level_seconds",{});level_receipts.assign(extra.get("level_receipts",[]))
	blind=saved.blind;caches.assign(saved.caches);kills=saved.kills;deaths=saved.deaths;elapsed=saved.seconds;metrics.assign(saved.metrics)
	load_sector(saved.sector)
func _hud_snapshot()->Dictionary:
	var snapshot:Dictionary=super._hud_snapshot()
	var required:=goals.filter(func(goal):return is_instance_valid(goal) and not goal.optional)
	snapshot.merge({"district_index":sector+1,"district_count":sectors.size(),
		"level_index":int(sectors[sector].get("level",1)),"lens":lens,"input_device":gamepad_navigation.input_device if is_instance_valid(gamepad_navigation) else "keyboard",
		"required_done":required.filter(func(goal):return goal.completed).size(),
		"required_total":required.size(),"gate_open":is_instance_valid(room) and room.gate_open,
		"guidance":_journal_next_step() if is_instance_valid(room) else "Begin the ascent."})
	if state=="title":
		snapshot.merge({"panel_override":true,"panel_title":"MOKSHA / FIVE ASCENTS","panel_body":"A city and four floors. One old operative.\n\nChoose a starting lens: 1 Neutral / 2 Strength / 3 Agility\nCURRENT: "+lens.to_upper()+"\nStrength: +40% strikes,75 health,-6% run\nAgility: +12% run,50 health. Neutral:60 health.\n\nOpen civilian routes. Reach the Crown. Decide who holds its keys.","panel_footer":"ENTER New campaign"+("   C Continue" if continue_available else "")})
	elif state=="upgrade":
		snapshot.merge({"panel_override":true,"panel_title":"LEVEL SECURED / SPECIALIZE","panel_body":"The onward elevator is yours. Choose a persistent upgrade.\n\nJ  FORCE: +25% base strike damage\nK  AGILITY: +10% base run speed\nL  VITALITY: +15 maximum health\n\nUpgrades stack additively and survive checkpoints.","panel_footer":"J / K / L  Choose and ascend"})
	elif state=="final_choice":
		snapshot.merge({"panel_override":true,"panel_title":"THE COMMAND NETWORK IS YOURS","panel_body":"The Warden is down. Evacuation channels remain live.\nThe monopoly has lost its command of the tower.\n\nJ  Publish its records to every district.\nK  Transfer control to the district custodians.\n\nNeither choice deletes your progress or sacrifices civilians.","panel_footer":"J  PUBLIC RECORD    K  LOCAL CUSTODY"})
	elif state=="complete":
		snapshot.merge({"panel_override":true,"panel_title":"MOKSHA / THE FIVE ASCENTS","panel_body":("The records are public. No single voice can erase them." if campaign_ending=="public_record" else "The districts hold their own keys. No central lock remains.")+"\nEvacuation lights carry on below. You lower your weapon.\nThe old operative leaves the tower to its people.\n\nFive levels complete · active time %d:%02d\n%d deaths · %d defeated · %s lens"%[int(elapsed)/60,int(elapsed)%60,deaths,kills,lens],"panel_footer":"N / ENTER  Title · new run keeps this result"})
	elif state=="paused":
		snapshot.merge({"panel_override":true,"panel_title":"PAUSED","panel_body":"A/D or arrows  Move     Space / C  Jump, then air jump\nJ  Fresh-tap strike combo     K  Raise / hold shield\nShift  Roll     S + Space  Drop / dive\nW / S  Climb ladders     Q  Sound tap\nE  Interact     TAB  Field journal     M  Mute\n\nR resets this district's objectives, guards and cargo.\nYour build, sight choice and archives are kept.","panel_footer":"ESC Resume    R Reset district    N Title"})
	elif state=="journal":
		var rows:=_journal_rows()
		var pages:=maxi(1,ceili(rows.size()/5.0))
		journal_page=clampi(journal_page,0,pages-1)
		var lines:="%s · Page %d/%d\n\n"%[sectors[sector].title,journal_page+1,pages]
		for i in range(journal_page*5,mini(rows.size(),journal_page*5+5)):lines+=rows[i]+"\n"
		lines+="\nNext: "+_journal_next_step()+"\nBuild: "+lens+(" / "+", ".join(upgrades) if not upgrades.is_empty() else "")
		snapshot.merge({"panel_override":true,"panel_title":"FIELD JOURNAL","panel_body":lines,"panel_footer":"A / D or arrows Pages    TAB / ESC Return"})
	elif state=="playing":
		if _input_gate.has_held_blocker(_raw_campaign_input()):
			snapshot.guidance="Center the stick and release held buttons." if snapshot.input_device=="controller" else "Release held keys, then press again."
		snapshot.sector_title="L%d · %s"%[sectors[sector].level,sectors[sector].title]
		for goal in goals:
			if not goal.completed and not goal.optional:snapshot.objective=goal.label+(" [J]" if goal.kind=="breaker" else " [E]")+" · TAB journal";break
		if sectors[sector].get("captain_required",false) and enemies.any(func(enemy):return is_instance_valid(enemy) and not enemy.dead and str(enemy.kind).begins_with("captain_")):
			snapshot.objective="Captain holds the seal · evade commitment, punish recovery"
		var nearby:=_nearby_objective(true)
		if is_instance_valid(nearby):
			var missing:Array[String]=[]
			for id in nearby.required_ids:
				if not goal_done(id):missing.append(_objective_label(id))
			if nearby.completed and nearby.kind!="route":snapshot.prompt="COMPLETE · "+nearby.label
			elif not missing.is_empty():snapshot.prompt="Requires: "+", ".join(missing)
			else:snapshot.prompt=("[J] "+nearby.label) if nearby.kind=="breaker" else ("[E] "+nearby.label) if nearby.kind!="plate" else "Move a cargo onto the marked plate"
	if state=="title" and not _checkpoint_write_error.is_empty():
		var retained:="Continue uses the previous successfully saved district." if continue_available else "No new checkpoint was saved."
		snapshot.merge({"panel_override":true,"panel_title":"CHECKPOINT NOT UPDATED",
			"panel_body":_checkpoint_write_error+"\n\n"+retained+"\nKeep the game open. Check free disk space and folder access before closing.",
			"panel_footer":"ENTER New campaign"+("   C Previous checkpoint" if continue_available else "")},true)
	elif state=="title" and not _checkpoint_error.is_empty():
		snapshot.merge({"panel_override":true,"panel_title":"CHECKPOINT UNAVAILABLE",
			"panel_body":_checkpoint_error+"\n\nThe existing checkpoint has not been changed.\nStarting a new campaign preserves a separate copy before replacing it.",
			"panel_footer":"ENTER New campaign"},true)
	if is_instance_valid(companion):companion.decorate(snapshot)
	return snapshot

func _journal_rows()->Array[String]:
	var rows:Array[String]=[]
	var d:Dictionary=sectors[sector]
	for i in _relay_points().size():rows.append(("✓ " if relay_states.has(i) else "○ ")+"Activate relay %d [E]"%(i+1))
	if d.has("freight"):rows.append(("✓ " if room.freight_receiver.is_latched else "○ ")+"Seat intact freight in receiver [J launch]")
	for goal in goals:rows.append(("✓ " if goal.completed else "○ ")+goal.label+(" (optional)" if goal.optional else ""))
	if d.get("captain_required",false):
		var alive:=enemies.any(func(enemy):return is_instance_valid(enemy) and not enemy.dead and str(enemy.kind).begins_with("captain_"))
		rows.append(("○ " if alive else "✓ ")+"Defeat the captain holding the exit seal")
	elif d.get("lock",false):rows.append(("✓ " if remaining_enemies()==0 else "○ ")+"Release security seal: %d threats remain"%remaining_enemies())
	rows.append(("✓ " if room.gate_open else "○ ")+"Open the onward passage")
	return rows
func _journal_next_step()->String:
	if room.gate_open:return "Use the onward door [E]."
	for goal in goals:
		if not goal.optional and not goal.completed and goal.required_ids.all(func(id):return goal_done(id)):
			return goal.label+(" [J]" if goal.kind=="breaker" else " [E]")
	if sectors[sector].has("freight") and not room.freight_receiver.is_latched:return "Strike freight toward its receiver; E at cradle replaces it."
	if not relay_on and not _relay_points().is_empty():return "Find an unlit relay and activate it [E]."
	return "Evade the sealed exit's defenders, then punish recovery."

func _objective_label(id:String)->String:
	for goal in goals:
		if goal.objective_id==id:return goal.label
	return id

func _nearby_objective(include_completed:=false)->Node:
	# The prompt and E use one selector/radius, never authoring array order.
	# An unusable housing must not steal E from a nearby active terminal.
	if not is_instance_valid(player):return null
	var candidate:Node=null
	var candidate_rank:=3
	var nearest:=INF
	for goal in goals:
		if not is_instance_valid(goal):continue
		var finished:bool=goal.completed and goal.kind!="route"
		if finished and not include_completed:continue
		var distance:float=player.global_position.distance_to(goal.global_position)
		if distance>=52:continue
		var ready:bool=goal.required_ids.all(func(id):return goal_done(id))
		var rank:=2 if finished else 0 if ready and goal.kind not in ["plate","breaker"] else 1
		if rank<candidate_rank or (rank==candidate_rank and distance<nearest):
			candidate=goal;candidate_rank=rank;nearest=distance
	return candidate
