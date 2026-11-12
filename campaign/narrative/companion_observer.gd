extends Node
## Reads host facts; never mutates player, goals, enemies, checkpoints or input.
const Director=preload("res://campaign/narrative/companion_director.gd")
var director=Director.new()
var host:Node
var last_room:Node
var previous_state:="title"
var previous_health:=0.0
var quiet_after_damage:=0.0
var choice_event:=""
var choice_room:=""
var safe:=false
var mote:Node2D
var ui_blocked:=true
func bind(owner_host:Node)->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	host=owner_host
	mote=preload("res://campaign/narrative/companion_mote.gd").new()
	host.add_child(mote)
func reset_session()->void:
	director.reset();choice_event="";choice_room="";last_room=null
func sight_chosen(accepted:bool)->void:
	choice_event="sight_traded" if accepted else "sight_kept"
	choice_room=str(host.sectors[host.sector].id)
func _process(dt:float)->void:
	if not is_instance_valid(host):return
	# New/Continue starts from title; retry does not, and retains consumed chatter.
	if previous_state=="title" and host.state in ["intro","playing"]:reset_session()
	previous_state=host.state
	if not is_instance_valid(host.player) or not is_instance_valid(host.room):
		safe=false;director.retire();mote.visible=false;return
	if last_room!=host.room:
		last_room=host.room;director.retire();quiet_after_damage=2
		previous_health=host.health.current_health
	var current:float=host.health.current_health
	if current<previous_health:quiet_after_damage=3
	previous_health=current
	if host.state=="playing":quiet_after_damage=maxf(0,quiet_after_damage-dt)
	var danger:=false
	for enemy in host.enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.global_position.distance_to(host.player.global_position)<360:
			danger=true;break
	safe=not ui_blocked and host.state=="playing" and quiet_after_damage<=0 and not danger and host.notice_left<=0 and host.chapter_left<=0
	# Suppress near all interactables, not just authored objectives.
	if safe:
		if host._nearby_objective()!=null:safe=false
	var room_id:=str(host.sectors[host.sector].id)
	director.tick(dt,room_id,events(room_id),safe)
	mote.visible=safe and director.enabled and not host.blind
	mote.global_position=host.player.global_position+Vector2(-22,-38)
func events(id:String)->Array[String]:
	var result:Array[String]=[]
	var p:Vector2=host.player.position
	match id:
		"rainline":
			if p.x>600 and p.x<1700:result.append("rain_roof" if p.y<225 else "rain_street")
			if host.relay_on:result.append("rain_relay")
		"city_clinic":
			if host.goal_done("cell") and not host.goal_done("generator"):result.append("clinic_cell")
			if host.goal_done("generator") and not host.goal_done("patients"):result.append("clinic_power")
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
			if captain_alive and p.x>1200 and p.x<1600:result.append("captain")
			if not captain_alive and host.room.gate_open:result.append("captain_down")
	if choice_room==id and not choice_event.is_empty():result.append(choice_event)
	return result
func decorate(snapshot:Dictionary)->void:
	# Snapshot-only presentation: ordinary notice/prompt and modal state always win.
	ui_blocked=snapshot.get("state","")!="playing" or snapshot.get("notice_visible",false) or snapshot.get("chapter_visible",false) or not str(snapshot.get("prompt","")).is_empty()
	if ui_blocked:
		director.retire()
		if is_instance_valid(mote):mote.visible=false
		return
	if not safe:return
	var line:=director.text()
	if line.is_empty():return
	snapshot.notice=line;snapshot.notice_visible=true
	director.acknowledge()
