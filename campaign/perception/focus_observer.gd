extends Node
## Campaign admission policy, never a writer of actor clocks or resources.
const Emitter=preload("res://simulation/components/projectile_emitter.gd")
var _host:WeakRef
var _room:WeakRef
var _bindings:Array=[]
var _marks:Array=[]
var _goal_refs:Array=[]
var _generation:=-1
var admitted_count:=0
func bind(host:Node)->void:
	_host=weakref(host)
	get_tree().tree_changed.connect(_clear_marks)
	process_physics_priority=100
	var view=preload("res://campaign/presentation/focus_view.gd").new()
	add_child(view);view.bind(self)
func _clear_marks()->void:_marks.clear()
func retire()->void:
	_marks.clear()
	for ref in _goal_refs:
		var goal=ref.get_ref()
		if is_instance_valid(goal) and goal.changed.is_connected(_clear_marks):goal.changed.disconnect(_clear_marks)
	_goal_refs.clear()
	for binding in _bindings:
		var actor=binding.ref.get_ref()
		if is_instance_valid(actor) and actor.movement_event.is_connected(binding.callback):actor.movement_event.disconnect(binding.callback)
	_bindings.clear();_room=null
func bind_room()->void:
	retire()
	var host=_host.get_ref()
	if not is_instance_valid(host) or not is_instance_valid(host.room):return
	_room=weakref(host.room);_generation=host.session_generation
	for goal in host.goals:
		if is_instance_valid(goal):goal.changed.connect(_clear_marks);_goal_refs.append(weakref(goal))
	for enemy in host.enemies.slice(0,64):
		if not is_instance_valid(enemy) or not enemy.has_method("late_windup_admission_snapshot"):continue
		var ref=weakref(enemy)
		var callback=_on_event.bind(ref)
		enemy.movement_event.connect(callback)
		_bindings.append({"ref":ref,"callback":callback})
func _live(actor:Node)->bool:
	var host=_host.get_ref() if _host!=null else null
	var room=_room.get_ref() if _room!=null else null
	return is_instance_valid(host) and is_instance_valid(room) and not room.is_queued_for_deletion() and room==host.room and host._pending_sector<0 and not host._pending_retry and host.session_generation==_generation and host.state=="playing" and not host.get_tree().paused and not host._loading_campaign and host.sense_capabilities().get("focus",false) and is_instance_valid(host.player) and not host.player.is_defeated() and is_instance_valid(actor) and not actor.is_queued_for_deletion() and room.is_ancestor_of(actor) and not actor.is_defeated() and actor.can_process() and actor.is_physics_processing()
func _onscreen(actor:Node)->bool:
	var host=_host.get_ref()
	var skin=actor.get_node_or_null("CampaignSecuritySkin")
	if not is_instance_valid(skin) or not skin.is_visible_in_tree():return false
	var screen:Vector2=host.get_viewport().get_canvas_transform()*(actor.global_position-Vector2(0,actor.body_height*.5))
	var ink:=Rect2(screen-Vector2(18,15),Vector2(36,30))
	var safe:Rect2=host.hud.caption_safe_rect()
	if not safe.encloses(ink):return false
	for exclusion in host.hud.caption_exclusion_rects():
		if exclusion.intersects(ink):return false
	return true
func _perceivable(actor:Node)->bool:
	if not _live(actor) or not _onscreen(actor):return false
	var host=_host.get_ref()
	var from:Vector2=host.player.global_position-Vector2(0,host.player.body_height*.5)
	var to:Vector2=actor.global_position-Vector2(0,actor.body_height*.5)
	var ray=PhysicsRayQueryParameters2D.create(from,to,1,[host.player.get_rid(),actor.get_rid()]);ray.hit_from_inside=true
	return host.player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
func _on_event(kind:StringName,_packet:Dictionary,ref:WeakRef)->void:
	if kind!=&"attack_started" or not Engine.is_in_physics_frame():return
	var actor=ref.get_ref()
	if not _perceivable(actor) or Emitter.registered(actor)!=null:return
	if actor.request_late_windup(actor.late_windup_admission_snapshot(),0.18,0.5):admitted_count+=1
func _physics_process(_dt:float)->void:
	_marks.clear()
	var host=_host.get_ref() if _host!=null else null
	if not is_instance_valid(host) or not host.sense_capabilities().get("focus",false):return
	for binding in _bindings:
		var actor=binding.ref.get_ref()
		if not _live(actor):continue
		var timing:Dictionary=actor.late_windup_snapshot()
		if timing.get("active",false) and _perceivable(actor):
			_marks.append({"ref":binding.ref,"serial":timing.serial,"position":actor.global_position,"player_position":host.player.global_position,"frame":Engine.get_physics_frames()})
func visible_marks()->Array:
	var result:Array=[]
	for mark in _marks:
		var actor=mark.ref.get_ref()
		if not _live(actor) or not _onscreen(actor) or actor.global_position!=mark.position or _host.get_ref().player.global_position!=mark.player_position or Engine.get_physics_frames()!=mark.frame:continue
		var timing:Dictionary=actor.late_windup_snapshot()
		if timing.get("serial")!=mark.serial or not timing.get("active",false):continue
		result.append({"center":actor.global_position-Vector2(0,actor.body_height*.5)})
	return result
func _exit_tree()->void:
	retire()
	if get_tree().tree_changed.is_connected(_clear_marks):get_tree().tree_changed.disconnect(_clear_marks)
