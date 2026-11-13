extends Node
## Read-only, visible Quarantine lancer coaching. No clocks, inputs or save authority.
var enabled := true
var _host:WeakRef
var _room:WeakRef
var _actor:WeakRef
var _session := -1
var _candidate:Dictionary = {}
var _warning_token:Dictionary = {}
var _warning_seen := false
var _recovery_seen := false
var _age := 0.0

func bind(host:Node)->void:
	_host=weakref(host)
	process_mode=Node.PROCESS_MODE_ALWAYS
	process_physics_priority=100
	host.hud.tactical_presentation_accepted.connect(_acknowledge)

func retire()->void:
	var actor:Node=_actor.get_ref() if _actor!=null else null
	if is_instance_valid(actor) and actor.movement_event.is_connected(_on_event):actor.movement_event.disconnect(_on_event)
	_actor=null;_room=null;_candidate.clear();_warning_token.clear()
	_warning_seen=false;_recovery_seen=false;_age=0

func bind_room()->void:
	retire()
	var host:Node=_host.get_ref() if _host!=null else null
	if not is_instance_valid(host):return
	_session=host.session_generation
	if str(host.sectors[host.sector].id)!="quarantine_intake":return
	_room=weakref(host.room)
	for actor in host.enemies:
		if is_instance_valid(actor) and str(actor.kind)=="captain_lancer":
			_actor=weakref(actor);actor.movement_event.connect(_on_event);break

func _live()->bool:
	var host:Node=_host.get_ref() if _host!=null else null
	var room:Node=_room.get_ref() if _room!=null else null
	var actor:Node=_actor.get_ref() if _actor!=null else null
	return enabled and is_instance_valid(host) and is_instance_valid(room) and room==host.room and not room.is_queued_for_deletion() and _session==host.session_generation and host.state=="playing" and not host.blind and not host.get_tree().paused and not host._loading_campaign and host._pending_sector<0 and not host._pending_retry and is_instance_valid(host.player) and not host.player.is_defeated() and is_instance_valid(actor) and not actor.is_queued_for_deletion() and room.is_ancestor_of(actor) and not actor.is_defeated() and actor.can_process() and actor.is_physics_processing()

func _visible()->bool:
	if not _live():return false
	var host:Node=_host.get_ref()
	var actor:Node=_actor.get_ref()
	var skin:Node=actor.get_node_or_null("CampaignSecuritySkin")
	if not is_instance_valid(skin) or not skin.is_visible_in_tree():return false
	var screen:Vector2=host.get_viewport().get_canvas_transform()*(actor.global_position-Vector2(0,actor.body_height*.5))
	var ink:=Rect2(screen-Vector2(18,15),Vector2(36,30))
	if not host.hud.caption_safe_rect().encloses(ink):return false
	for exclusion in host.hud.caption_exclusion_rects():
		if exclusion.intersects(ink):return false
	var ray:=PhysicsRayQueryParameters2D.create(host.player.global_position-Vector2(0,host.player.body_height*.5),actor.global_position-Vector2(0,actor.body_height*.5),1,[host.player.get_rid(),actor.get_rid()])
	ray.hit_from_inside=true
	return host.player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func _identity(plan:Dictionary)->Dictionary:
	return {"serial":plan.serial,"generation":plan.generation,"configuration_epoch":plan.configuration_epoch}

func _current()->bool:
	if _candidate.is_empty() or not _visible():return false
	var plan:Dictionary=_actor.get_ref().attack_plan_snapshot()
	return plan.get("committed",false) and plan.get("pose_id")==&"lancer_thrust" and _identity(plan)==_candidate.token and str(plan.phase)==_candidate.phase and _age<_candidate.limit

func _on_event(kind:StringName,packet:Dictionary)->void:
	if not _live():_candidate.clear();_warning_token.clear();return
	var plan:Dictionary=_actor.get_ref().attack_plan_snapshot()
	if not plan.get("committed",false) or plan.get("pose_id")!=&"lancer_thrust":_candidate.clear();_warning_token.clear();return
	if kind==&"attack_started":
		_candidate.clear();_warning_token.clear()
		if not _warning_seen and packet.get("serial")==plan.serial and plan.phase==&"windup" and _visible():
			_candidate={"token":_identity(plan),"phase":"windup","text":"Step aside.","limit":.78};_age=0
	elif kind==&"attack_phase_changed" and packet.get("serial")==plan.serial:
		if plan.phase==&"recovery":
			_candidate.clear()
			if not _recovery_seen and _warning_token==_identity(plan) and _visible():
				_candidate={"token":_identity(plan),"phase":"recovery","text":"An opening.","limit":1.05};_age=0
		elif plan.phase!=&"windup":_candidate.clear()

func _physics_process(dt:float)->void:
	if not _live():_candidate.clear();_warning_token.clear();return
	if not _candidate.is_empty():
		_age+=dt
		if not _current():_candidate.clear()
	# Lose followup authority if an admitted attack is interrupted or no longer visible.
	if not _warning_token.is_empty():
		var plan:Dictionary=_actor.get_ref().attack_plan_snapshot()
		if not plan.get("committed",false) or _identity(plan)!=_warning_token or not _visible():_warning_token.clear()

func _id()->String:
	return "%d:%d:%d:%d:%s"%[_session,_candidate.token.generation,_candidate.token.configuration_epoch,_candidate.token.serial,_candidate.phase] if not _candidate.is_empty() else ""

func decorate(snapshot:Dictionary)->void:
	if snapshot.get("state","")!="playing" or snapshot.get("panel_override",false) or snapshot.get("chapter_visible",false) or snapshot.get("notice_visible",false) or not str(snapshot.get("prompt","")).is_empty() or not _current():return
	snapshot.notice=_candidate.text;snapshot.notice_visible=true;snapshot.tactical_line_id=_id()

func _acknowledge(id:String,text:String)->void:
	if id.is_empty() or not _current() or id!=_id() or text!=_candidate.text:return
	if _candidate.phase=="windup":_warning_seen=true;_warning_token=_candidate.token.duplicate()
	elif _candidate.phase=="recovery":_recovery_seen=true

func _exit_tree()->void:retire()
