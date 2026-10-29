extends "res://demo/mission.gd"
## Campaign orchestrator. Original controller, damage pipeline and demo stay intact.
const CampaignData=preload("res://campaign/logic/campaign_data.gd")
const ObjectiveScene=preload("res://campaign/logic/objective.tscn")
const DoorScene=preload("res://campaign/logic/objective_door.tscn")
const HazardScene=preload("res://campaign/logic/hazard.tscn")
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
func _ready()->void:
	blackboard=preload("res://campaign/vendor/beehave/blackboard.gd").new()
	add_child(blackboard)
	sectors=CampaignData.sectors()
	super._ready()
	hud.get_node("View").set_script(preload("res://campaign/views/campaign_hud.gd"))
func start_new(skip_intro:=false)->void:
	rewards.clear();upgrades.clear();level_seconds.clear();level_receipts.clear();campaign_ending=""
	_completed_snapshot.clear()
	super.start_new(skip_intro)
func load_sector(index:int)->void:
	_loading_campaign=true
	goals.clear();completed_goals.clear();art=null;actor_paint=null;object_paint=null
	if is_instance_valid(blackboard):blackboard.set_value("objectives",{})
	super.load_sector(index)
	# Swap only the optional health quantity adapter; the actor stays unchanged.
	var defeat=player.get_node("DefeatResponse")
	defeat.unbind()
	health.free()
	health=Node.new();health.set_script(preload("res://campaign/logic/build_health.gd"));health.name="Health"
	player.add_child(health);health.depleted.connect(_on_defeat);defeat.bind(player,health)
	# Every contact adapter caches its health authority. Replacing the optional
	# quantity store requires explicit rebinds, otherwise physical hits retire.
	player.get_node("BodyShape/IncomingStrikeReceiver").bind(player)
	player.get_node("PhysicalImpactReceiver").bind(player,health,player)
	player.get_node("BoundaryReceiver").bind(player,health)
	player.get_node("ProjectileReceiver").bind(player)
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
	var speed:=1.0;var force:=1.0;var capacity:=60.0
	if lens=="agility":speed=1.12;capacity=50
	elif lens=="strength":speed=0.94;force=1.4;capacity=75
	for value in rewards.values():
		if value=="vitality":capacity+=5
		elif value=="force":force+=0.08
		elif value=="agility":speed+=0.03
	for value in upgrades:
		if value=="vitality":capacity+=15
		elif value=="force":force+=0.25
		elif value=="agility":speed+=0.1
	player.profile.run_speed*=speed
	player.melee_chain=preload("res://combat_pc/resources/responsive_chain.tres").duplicate(true)
	for step in player.melee_chain.steps:step.damage*=force
	health.set_capacity(capacity,_loading_campaign)
func _physics_process(dt:float)->void:
	var before_elapsed:=elapsed
	super._physics_process(dt)
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
	for goal in goals:
		if _near(goal.global_position,52) and (not goal.completed or goal.kind=="route"):
			if not goal.interact():announce("Requires: "+", ".join(goal.required_ids.map(func(id):return _objective_label(id))) if not goal.available else "Strike the circuit breaker [J]" if goal.kind=="breaker" else "Move a physical cargo onto the pressure plate",3)
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
		var next_level:int=int(sectors[sector+1].get("level",1))
		if next_level!=int(d.get("level",1)):
			metrics.append({"sector":sector,"seconds":sector_elapsed,"blind":blind,"health":health.current_health})
			level_receipts.append({"level":d.level,"active_seconds":level_seconds.get(str(d.level),0),"completed_district":d.id})
			state="upgrade";get_tree().paused=true;return
	super.interact()
func choose_sight(accept:bool)->void:
	super.choose_sight(accept)
	_apply_build()
	if is_instance_valid(art):art.set_sight_enabled(not blind)
	if is_instance_valid(actor_paint):actor_paint.set_sight_enabled(not blind)
	if is_instance_valid(object_paint):object_paint.set_sight_enabled(not blind)
func _unhandled_key_input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	var key:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
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
	super._unhandled_key_input(event)
func complete_run()->void:
	state="complete";get_tree().paused=true;sonar.set_blind(false)
	if is_instance_valid(art):art.set_sight_enabled(true)
	audio.play_sound("win",-8,1)
	if save_enabled:
		var file=FileAccess.open("user://moksha_five_levels_results.json",FileAccess.WRITE)
		if file:file.store_string(JSON.stringify({"ending":campaign_ending,"active_seconds":elapsed,"levels":level_receipts,"districts":metrics,"lens":lens,"upgrades":upgrades,"deaths":deaths,"kills":kills},"\t"))
func _read_checkpoint()->Dictionary:
	if not FileAccess.file_exists(CAMPAIGN_SAVE):return {"ok":false}
	var raw=JSON.parse_string(FileAccess.get_file_as_string(CAMPAIGN_SAVE))
	if not raw is Dictionary or raw.get("campaign_version")!=1:return {"ok":false}
	var decoded:Dictionary=Checkpoint.decode(raw.get("progress"),sectors)
	if not decoded.ok:return decoded
	if raw.get("lens") not in ["neutral","strength","agility"] or not raw.get("upgrades") is Array or not raw.get("rewards") is Dictionary:return {"ok":false}
	for upgrade in raw.upgrades:
		if upgrade not in ["force","agility","vitality"]:return {"ok":false}
	if raw.upgrades.size()>4:return {"ok":false}
	for reward in raw.rewards.values():
		if reward not in ["force","agility","vitality"]:return {"ok":false}
	if not raw.get("level_seconds",{}) is Dictionary or not raw.get("level_receipts",[]) is Array:return {"ok":false}
	for value in raw.get("level_seconds",{}).values():
		if not Checkpoint.number(value):return {"ok":false}
	for receipt in raw.get("level_receipts",[]):
		if not receipt is Dictionary or not Checkpoint.whole(receipt.get("level")) or int(receipt.level)<1 or int(receipt.level)>5 or not Checkpoint.number(receipt.get("active_seconds")):return {"ok":false}
	decoded["campaign"]=raw
	return decoded
func _save_checkpoint()->void:
	if not save_enabled or _loading_campaign:return
	var encoded:Dictionary=Checkpoint.encode({"metrics":metrics,"sector":sector,"blind":blind,"caches":caches,"kills":kills,"deaths":deaths,"seconds":elapsed},sectors)
	if not encoded.ok:return
	blackboard.set_value("build",{"lens":lens,"upgrades":upgrades.duplicate()})
	var raw:Dictionary={"campaign_version":1,"progress":encoded.data,"lens":lens,"upgrades":upgrades,"rewards":rewards,"level_seconds":level_seconds,"level_receipts":level_receipts}
	var file=FileAccess.open(CAMPAIGN_SAVE+".pending",FileAccess.WRITE)
	if not file:_checkpoint_write_error="Campaign checkpoint write failed";return
	file.store_string(JSON.stringify(raw));file.flush();var error=file.get_error();file.close()
	if error!=OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(CAMPAIGN_SAVE+".pending"),ProjectSettings.globalize_path(CAMPAIGN_SAVE))!=OK:
		_checkpoint_write_error="Campaign checkpoint commit failed";return
	continue_available=true;_checkpoint_write_error=""
func continue_run()->void:
	var saved:=_read_checkpoint()
	if not saved.get("ok",false):return
	var extra:Dictionary=saved.campaign
	lens=extra.lens;upgrades.assign(extra.upgrades);rewards=extra.rewards
	level_seconds=extra.get("level_seconds",{});level_receipts.assign(extra.get("level_receipts",[]))
	blind=saved.blind;caches.assign(saved.caches);kills=saved.kills;deaths=saved.deaths;elapsed=saved.seconds;metrics.assign(saved.metrics)
	load_sector(saved.sector)
func _hud_snapshot()->Dictionary:
	var snapshot:Dictionary=super._hud_snapshot()
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
		snapshot.sector_title="L%d · %s"%[sectors[sector].level,sectors[sector].title]
		for goal in goals:
			if not goal.completed and not goal.optional:snapshot.objective=goal.label+(" [J]" if goal.kind=="breaker" else " [E]")+" · TAB journal";break
		if sectors[sector].get("captain_required",false) and enemies.any(func(enemy):return is_instance_valid(enemy) and not enemy.dead and str(enemy.kind).begins_with("captain_")):
			snapshot.objective="Captain holds the seal · evade commitment, punish recovery"
		for goal in goals:
			if _near(goal.global_position,60):
				var missing:Array[String]=[]
				for id in goal.required_ids:
					if not goal_done(id):missing.append(_objective_label(id))
				if goal.completed and goal.kind!="route":snapshot.prompt="COMPLETE · "+goal.label
				elif not missing.is_empty():snapshot.prompt="Requires: "+", ".join(missing)
				else:snapshot.prompt=("[J] "+goal.label) if goal.kind=="breaker" else ("[E] "+goal.label) if goal.kind!="plate" else "Move a cargo onto the marked plate"
				break
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
