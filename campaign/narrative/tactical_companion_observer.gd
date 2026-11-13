extends Node
## Read-only, visible Quarantine lancer coaching. No clocks, inputs or save authority.
var enabled := true:
	set(value):
		enabled=value
		if not value:_invalidate_heard()
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
	_unbind_heard()
	var actor:Node=_actor.get_ref() if _actor!=null else null
	if is_instance_valid(actor) and actor.movement_event.is_connected(_on_event):actor.movement_event.disconnect(_on_event)
	_actor=null;_room=null;_candidate.clear();_warning_token.clear()
	_warning_seen=false;_recovery_seen=false;_age=0

func bind_room()->void:
	retire()
	var host:Node=_host.get_ref() if _host!=null else null
	if not is_instance_valid(host):return
	_session=host.session_generation
	if str(host.sectors[host.sector].id)=="l3_drainage_commons":
		_bind_heard(host);return
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
	if _hearing_room:
		_heard_age+=dt
		if not _heard_live():_invalidate_heard();return
		var listener:Node=_host.get_ref().player
		if listener.noise_generation()!=_listener_generation:
			_listener_generation=listener.noise_generation();_invalidate_heard();return
		if not _heard_current():_retire_heard()
		elif HearingQuery.sample(listener,_heard_origin,_heard_loudness,_actor.get_ref(),_hearing_profile).is_empty():_retire_heard()
		return
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
	if _hearing_room:
		_decorate_heard(snapshot);return
	if snapshot.get("state","")!="playing" or snapshot.get("panel_override",false) or snapshot.get("chapter_visible",false) or snapshot.get("notice_visible",false) or not str(snapshot.get("prompt","")).is_empty() or not _current():return
	snapshot.notice=_candidate.text;snapshot.notice_visible=true;snapshot.tactical_line_id=_id()

func _acknowledge(id:String,text:String)->void:
	if _hearing_room:
		if _heard_current() and id==_heard_fact.get("id","") and text=="Be ready.":_heard_seen=true
		return
	if id.is_empty() or not _current() or id!=_id() or text!=_candidate.text:return
	if _candidate.phase=="windup":_warning_seen=true;_warning_token=_candidate.token.duplicate()
	elif _candidate.phase=="recovery":_recovery_seen=true

func _exit_tree()->void:retire()

# Hearing path intentionally never polls attack plan, hidden position or type.
const HearingQuery = preload("res://simulation/components/hearing_query.gd")
const HearingProfile = preload("res://simulation/resources/hearing_profile.gd")
var _hearing_room := false
var _relay:WeakRef
var _heard_player:WeakRef
var _heard_callback:Callable
var _heard_binding := 0
var _rearm_after_frame := -1
var _dedup_frame := -1
var _listener_generation := -1
var _heard_fact:Dictionary = {}
var _heard_origin := Vector2.ZERO
var _heard_loudness := 0.0
var _heard_age := 0.0
var _heard_seen := false
var _heard_receipts:Dictionary = {}
var _source_generation := -1
var _player_generation := -1
var _hearing_profile:Resource

func _retire_heard()->void:
	_heard_fact={};_heard_age=0

func _invalidate_heard()->void:
	_retire_heard()
	_rearm_after_frame=Engine.get_physics_frames()

func senses_changed()->void:
	_invalidate_heard()

func _on_heard_lifecycle(kind:StringName,_packet:Dictionary)->void:
	if kind==&"reset":_invalidate_heard()

func _unbind_heard()->void:
	for ref in [_actor,_heard_player]:
		var owner:Node=ref.get_ref() if ref!=null else null
		if is_instance_valid(owner):
			if owner.tree_exiting.is_connected(_invalidate_heard):owner.tree_exiting.disconnect(_invalidate_heard)
			if owner.movement_event.is_connected(_on_heard_lifecycle):owner.movement_event.disconnect(_on_heard_lifecycle)
	_heard_player=null
	var relay:Node=_relay.get_ref() if _relay!=null else null
	if is_instance_valid(relay) and _heard_callback.is_valid() and relay.forwarded.is_connected(_heard_callback):relay.forwarded.disconnect(_heard_callback)
	_heard_binding+=1;_hearing_room=false;_relay=null;_heard_seen=false;_heard_receipts.clear();_retire_heard()

func _bind_heard(host:Node)->void:
	_hearing_room=true;_room=weakref(host.room)
	_hearing_profile=HearingProfile.new()
	_hearing_profile.hearing_enabled=true
	_hearing_profile.range_at_unit_loudness=340.0;_hearing_profile.gain=1.0
	_hearing_profile.minimum_loudness_scale=.2;_hearing_profile.maximum_loudness_scale=2.0
	_hearing_profile.ear_offset=Vector2(0,-20);_hearing_profile.ignore_own_source=true
	_hearing_profile.terrain_mask=1;_hearing_profile.contact_endpoint_tolerance=.1
	_listener_generation=host.player.noise_generation();_invalidate_heard()
	_hearing_profile.terrain_attenuation_enabled=true
	_hearing_profile.blocked_range_multiplier=0.0
	for actor in host.enemies:
		if is_instance_valid(actor) and str(actor.kind)=="captain_lancer":
			_actor=weakref(actor)
			var relay:Node=actor.get_node_or_null("NoiseRelay")
			if is_instance_valid(relay):
				_relay=weakref(relay);_heard_callback=_on_forwarded.bind(_heard_binding)
				_heard_player=weakref(host.player)
				for owner in [actor,host.player]:
					owner.tree_exiting.connect(_invalidate_heard)
					owner.movement_event.connect(_on_heard_lifecycle)
				relay.forwarded.connect(_heard_callback)
			break

func _heard_live()->bool:
	var host:Node=_host.get_ref() if _host!=null else null
	var room:Node=_room.get_ref() if _room!=null else null
	var actor:Node=_actor.get_ref() if _actor!=null else null
	var relay:Node=_relay.get_ref() if _relay!=null else null
	return enabled and _hearing_room and is_inside_tree() and can_process() and is_physics_processing() and is_instance_valid(host) and is_instance_valid(room) and room==host.room and not room.is_queued_for_deletion() and _session==host.session_generation and host.state=="playing" and host.blind and host.hearing_retained and not host.get_tree().paused and not host._loading_campaign and host._pending_sector<0 and not host._pending_retry and is_instance_valid(host.player) and _heard_player!=null and host.player==_heard_player.get_ref() and host.player.is_inside_tree() and room.is_ancestor_of(host.player) and not host.player.is_queued_for_deletion() and host.player.can_process() and host.player.is_physics_processing() and not host.player.is_defeated() and is_instance_valid(actor) and not actor.is_queued_for_deletion() and room.is_ancestor_of(actor) and actor.can_process() and actor.is_physics_processing() and is_instance_valid(relay) and relay.enabled and relay.is_inside_tree() and not relay.is_queued_for_deletion() and relay.get_parent()==actor

func _view_admits(origin:Vector2)->bool:
	var host:Node=_host.get_ref()
	var viewport:Viewport=host.get_viewport()
	if viewport!=host.get_tree().root or host.global_transform!=Transform2D.IDENTITY:return false
	if not viewport.is_audio_listener_2d() or viewport.get_audio_listener_2d()!=null:return false
	if not is_instance_valid(host.audio) or host.audio.get_script()!=preload("res://campaign/presentation/hearing_audio.gd"):return false
	if not host.audio.hearing_enabled or not host.audio.cache.get("guard_draw") is AudioStreamWAV:return false
	if host.audio.get_viewport()!=viewport or host.audio.get_parent()!=host:return false
	var transform:Transform2D=viewport.get_global_canvas_transform()*viewport.get_canvas_transform()
	if not transform.is_finite() or is_zero_approx(transform.determinant()):return false
	var center:Vector2=transform.affine_inverse()*(viewport.get_visible_rect().size*.5)
	return center.is_finite() and center.distance_to(origin)<=260.0

func _on_forwarded(receipt:Dictionary,binding:int)->void:
	if binding!=_heard_binding or not Engine.is_in_physics_frame():return
	if not _heard_live():_invalidate_heard();return
	if _heard_seen or Engine.get_physics_frames()<=_rearm_after_frame:return
	var listener:Node=_host.get_ref().player
	if listener.noise_generation()!=_listener_generation:
		_listener_generation=listener.noise_generation();_invalidate_heard();return
	var relay:Node=_relay.get_ref()
	if not relay.is_forwarding_receipt(receipt) or not receipt.is_read_only():return
	if receipt.get("kind")!=&"enemy_windup" or not receipt.get("origin") is Vector2 or not receipt.origin.is_finite():return
	if not receipt.get("serial") is int or not receipt.get("generation") is int:return
	var key:String="%d:%d"%[receipt.generation,receipt.serial]
	var frame:=Engine.get_physics_frames()
	if frame!=_dedup_frame:_heard_receipts.clear();_dedup_frame=frame
	# Bound same-frame pathological reentrancy. Overflow fails closed this frame.
	if _heard_receipts.has(key) or _heard_receipts.size()>=64:return
	# Consume before querying/callbacks, including rejected facts. Never replay.
	_heard_receipts[key]=true
	if not _heard_fact.is_empty() or not _view_admits(receipt.origin):return
	var host:Node=_host.get_ref()
	var admitted:Dictionary=HearingQuery.sample(host.player,receipt.origin,receipt.loudness,_actor.get_ref(),_hearing_profile)
	if admitted.is_empty() or binding!=_heard_binding or not _heard_live() or not relay.is_forwarding_receipt(receipt):return
	_heard_origin=receipt.origin;_heard_loudness=receipt.loudness;_heard_age=0
	_source_generation=receipt.generation;_player_generation=host.player.noise_generation()
	_heard_fact={"id":"hearing:%d:%d:%s"%[_session,_heard_binding,key],"modality":"hearing","category":"weapon_draw_heard","text":"Be ready."}
	_heard_fact.make_read_only()

func _heard_current()->bool:
	if _heard_fact.is_empty():return false
	if not _heard_live() or _heard_age>=.60:
		_retire_heard();return false
	var host:Node=_host.get_ref()
	if _actor.get_ref().noise_generation()!=_source_generation or host.player.noise_generation()!=_player_generation or not _view_admits(_heard_origin):
		_retire_heard();return false
	# Presentation uses frozen evidence, never current hidden actor geometry.
	if (host.player.global_position+Vector2(0,-20)).distance_to(_heard_origin)>340.0*clampf(_heard_loudness,.2,2.0):
		_retire_heard();return false
	return true

func _decorate_heard(snapshot:Dictionary)->void:
	if not _heard_current():return
	if snapshot.get("state","")!="playing" or snapshot.get("panel_override",false) or snapshot.get("chapter_visible",false) or snapshot.get("notice_visible",false) or not str(snapshot.get("prompt","")).is_empty():
		_retire_heard();return
	snapshot.notice="Be ready.";snapshot.notice_visible=true;snapshot.tactical_line_id=_heard_fact.id

func _notification(what:int)->void:
	if what in [NOTIFICATION_PAUSED,NOTIFICATION_DISABLED]:_invalidate_heard()
