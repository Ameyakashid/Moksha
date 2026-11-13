extends Node
## Reads host facts; never mutates player, goals, enemies, checkpoints or input.
const Director=preload("res://campaign/narrative/companion_director.gd")
var director=Director.new()
var host:Node
var last_room:Node
var observed_session:=-1
var previous_health:=0.0
var quiet_after_damage:=0.0
var choice_event:=""
var choice_room:=""
var safe:=false
var mote:Node2D
var ui_blocked:=true
var no_progress:=0.0
var furthest_x:=0.0
var highest_y:=300.0
func bind(owner_host:Node)->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	host=owner_host
	mote=preload("res://campaign/narrative/companion_mote.gd").new()
	host.add_child(mote)
	host.hud.companion_presentation_accepted.connect(_presentation_accepted)
func reset_session()->void:
	director.reset();choice_event="";choice_room="";last_room=null;no_progress=0;furthest_x=0;highest_y=300
func sight_chosen(accepted:bool)->void:
	choice_event="sight_traded" if accepted else "sight_kept"
	choice_room=str(host.sectors[host.sector].id)
func _process(dt:float)->void:
	if not is_instance_valid(host):return
	# Host increments explicitly on successful New/Continue, even within one frame.
	if observed_session!=host.session_generation:
		reset_session();observed_session=host.session_generation
	if not is_instance_valid(host.player) or not is_instance_valid(host.room):
		safe=false;director.retire();mote.visible=false;return
	if last_room!=host.room:
		last_room=host.room;director.preempt();quiet_after_damage=2
		no_progress=0;furthest_x=host.player.position.x;highest_y=host.player.position.y
		previous_health=host.health.current_health
	if host.state=="playing":
		no_progress+=dt
		if host.player.position.x>furthest_x+80 or host.player.position.y<highest_y-55:
			no_progress=0;furthest_x=maxf(furthest_x,host.player.position.x);highest_y=minf(highest_y,host.player.position.y)
	var current:float=host.health.current_health
	if current<previous_health:quiet_after_damage=3
	previous_health=current
	if host.state=="playing":quiet_after_damage=maxf(0,quiet_after_damage-dt)
	var danger:bool=host.player.main_action not in [&"locomotion", &"climb"]
	# Blind quiet policy uses only the operator's own action/damage, never hidden foes.
	if not host.blind:
		for enemy in host.enemies:
			if is_instance_valid(enemy) and not enemy.dead and enemy.global_position.distance_to(host.player.global_position)<240:
				danger=true;break
	safe=not ui_blocked and host.state=="playing" and quiet_after_damage<=0 and not danger and host.notice_left<=0 and host.chapter_left<=0
	# Suppress near all interactables, not just authored objectives.
	if safe:
		if host._nearby_objective()!=null:safe=false
	var room_id:=str(host.sectors[host.sector].id)
	director.tick(dt,room_id,events(room_id),safe)
	var screen_position:Vector2=host.player.global_position-host.camera.position+Vector2(320,180)+Vector2(-22,-38)
	mote.visible=host.state=="playing" and not ui_blocked and quiet_after_damage<=0 and host.player.main_action==&"locomotion" and director.enabled and not host.blind and Rect2(12,112,616,205).has_point(screen_position)
	mote.global_position=host.player.global_position+Vector2(-22,-38)
func events(id:String)->Array[String]:
	var result:Array[String]=[]
	var p:Vector2=host.player.position
	match id:
		"rainline":
			if not host.relay_on and host.player.grounded:
				if p.x>600 and p.x<1700 and p.y<225:result.append("rain_roof")
				if no_progress>=20:result.append("rain_street")
			if host.relay_on:result.append("rain_relay")
		"city_clinic":
			if host.goal_done("cell") and not host.goal_done("generator"):result.append("clinic_cell")
			if host.goal_done("generator") and shortcut_open() and not host.goal_done("patients"):result.append("clinic_power")
			if host.goal_done("patients"):result.append("clinic_rescue")
		"city_tram_depot":
			if host.goal_done("schematic") and not host.goal_done("auxiliary"):result.append("tram_map")
			if host.goal_done("auxiliary") and not host.goal_done("brake"):result.append("tram_power")
		"city_records":
			if host.goal_done("record"):result.append("records")
		"city_evac_spine":
			if host.goal_done("west")!=host.goal_done("east"):result.append("evac")
		"quarantine_intake":
			var captain_alive:=false
			for enemy in host.enemies:
				if is_instance_valid(enemy) and not enemy.dead and str(enemy.kind).begins_with("captain_"):captain_alive=true
			if captain_alive and not host.blind:
				for enemy in host.enemies:
					if is_instance_valid(enemy) and not enemy.dead and str(enemy.kind).begins_with("captain_"):
						var screen:Vector2=enemy.global_position-host.camera.position+Vector2(320,180)
						if Rect2(20,110,600,215).has_point(screen):result.append("captain")
			if not captain_alive and host.room.gate_open:result.append("captain_down")
	if choice_room==id and not choice_event.is_empty():result.append(choice_event)
	return result
func shortcut_open()->bool:
	for door in host.room.get_children():
		if door.get_script()==preload("res://campaign/logic/objective_door.gd") and absf(door.position.x-2850)<1:
			var shape=door.get_node_or_null("CollisionShape2D")
			return door.opened and is_instance_valid(shape) and shape.disabled
	return false
func decorate(snapshot:Dictionary)->void:
	if observed_session!=host.session_generation:return
	# Pure snapshot construction: queries cannot retire, acknowledge or consume lines.
	var blocked:bool=snapshot.get("state","")!="playing" or snapshot.get("notice_visible",false) or snapshot.get("chapter_visible",false) or not str(snapshot.get("prompt","")).is_empty()
	if blocked or not str(snapshot.get("tactical_line_id","")).is_empty() or not safe or director.active.is_empty():return
	if not events(str(host.sectors[host.sector].id)).has(director.active.event):return
	var line:=director.text()
	if line.is_empty():return
	snapshot.notice=line;snapshot.notice_visible=true;snapshot.companion_line_id=str(director.active.id)
func _presentation_accepted(id:String,blocked:bool)->void:
	ui_blocked=blocked
	if blocked:
		director.preempt()
		if is_instance_valid(mote):mote.visible=false
		return
	if safe and not director.active.is_empty() and director.active.id==id:director.acknowledge()
