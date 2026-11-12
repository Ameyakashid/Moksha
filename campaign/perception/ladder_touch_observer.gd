extends Node
## Original campaign-only contact observation; never invokes a climb command.
const REACH:=24.0
const HALF_WINDOW:=18.0
var host:Node
var view:Node2D
var enabled:=true
var snapshot:Dictionary={}
var target_ref:WeakRef
var room_ref:WeakRef
var session:=-1
var sampled_position:=Vector2.ZERO
var sampled_transform:=Transform2D.IDENTITY
var sampled_size:=Vector2.ZERO
var shape:=RectangleShape2D.new()
func bind(owner_host:Node)->void:
	host=owner_host;process_mode=Node.PROCESS_MODE_ALWAYS;process_physics_priority=100
	var layer:=CanvasLayer.new();layer.layer=23;add_child(layer)
	view=preload("res://campaign/perception/ladder_touch_view.gd").new();layer.add_child(view)
	view.reader=read_visible_snapshot
func retire()->void:
	snapshot.clear();target_ref=null;room_ref=null;session=-1
	if is_instance_valid(view):view.queue_redraw()
func active()->bool:
	return enabled and is_instance_valid(host) and not host._loading_campaign and host.state=="playing" and not get_tree().paused and is_instance_valid(host.player) and not host.player.is_queued_for_deletion() and is_instance_valid(host.room)
func _process(_dt:float)->void:
	if not active():retire()
	if is_instance_valid(view):view.queue_redraw()
func _physics_process(_dt:float)->void:
	retire()
	if not active():return
	var player:Node2D=host.player
	shape.size=Vector2(player.profile.body_width-.04,player.body_height+3.96)
	var query:=PhysicsShapeQueryParameters2D.new();query.shape=shape
	query.transform=Transform2D(0,player.global_position+Vector2(0,-player.body_height*.5))
	query.collision_mask=player.climbable_mask;query.collide_with_areas=true;query.collide_with_bodies=false
	query.exclude=player._query_excludes()
	var selected:Area2D
	var selected_geometry:Dictionary={}
	var nearest:=INF
	for hit in player.get_world_2d().direct_space_state.intersect_shape(query,64):
		var ladder=hit.collider
		if not ladder is Area2D or ladder.is_queued_for_deletion() or not host.room.is_ancestor_of(ladder) or not ladder.has_method("climb_geometry"):continue
		if (ladder.collision_layer & player.climbable_mask)==0:continue
		var geometry:Dictionary=ladder.climb_geometry()
		if geometry.is_empty() or geometry.get("type","")!="ladder":continue
		var chest:Vector2=player.global_position-Vector2(0,player.body_height*.5)
		var touch:=Vector2(geometry.axis_x,clampf(chest.y,geometry.top_y,geometry.bottom_y))
		if touch.distance_to(chest)>REACH:continue
		if player.global_position.y<geometry.top_y-2 or player.global_position.y-player.body_height>geometry.bottom_y+2:continue
		# Current geometry narrows potentially stale broadphase overlap.
		if absf(player.global_position.x-geometry.axis_x)>(player.profile.body_width+geometry.width)*.5:continue
		var ray:=PhysicsRayQueryParameters2D.create(chest,touch,player.terrain_mask,player._query_excludes())
		ray.collide_with_areas=false;ray.hit_from_inside=true
		if not chest.is_equal_approx(touch) and not player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty():continue
		var distance:=chest.distance_squared_to(touch)
		if player.main_action==&"climb" and is_instance_valid(player._climb_target) and player._climb_target==ladder:distance=-1.0
		if selected==null or distance<nearest:
			selected=ladder;selected_geometry=geometry;nearest=distance
	if selected==null:return
	var geometry:=selected_geometry
	var chest_y:float=player.global_position.y-player.body_height*.5
	var top:=maxf(float(geometry.top_y),chest_y-HALF_WINDOW)
	var bottom:=minf(float(geometry.bottom_y),chest_y+HALF_WINDOW)
	if bottom-top<2:return
	var half_width:=minf(6.0,float(geometry.width)*.3)
	var segments:=PackedVector2Array()
	for side in [-1.0,1.0]:
		segments.append(Vector2(geometry.axis_x+side*half_width,top)-player.global_position)
		segments.append(Vector2(geometry.axis_x+side*half_width,bottom)-player.global_position)
	var rung:float=geometry.bottom_y-float(geometry.get("rung_origin_offset",4.0))
	var spacing:=maxf(8.0,float(geometry.get("rung_spacing",12.0)))
	rung-=ceilf((rung-bottom)/spacing)*spacing
	var count:=0
	while rung>=top and count<3:
		segments.append(Vector2(geometry.axis_x-half_width,rung)-player.global_position)
		segments.append(Vector2(geometry.axis_x+half_width,rung)-player.global_position)
		rung-=spacing;count+=1
	snapshot={"segments":segments,"held":player.main_action==&"climb" and is_instance_valid(player._climb_target) and player._climb_target==selected}
	target_ref=weakref(selected);room_ref=weakref(host.room);session=host.session_generation
	sampled_position=player.global_position;sampled_transform=selected.global_transform
	sampled_size=Vector2(geometry.width,float(geometry.bottom_y)-float(geometry.top_y))
	view.position=player.global_position-host.camera.position+Vector2(320,180)
func read_snapshot()->Dictionary:
	if not active() or snapshot.is_empty() or session!=host.session_generation or room_ref==null or room_ref.get_ref()!=host.room or target_ref==null:return {}
	var target=target_ref.get_ref()
	if not is_instance_valid(target) or target.is_queued_for_deletion() or not host.room.is_ancestor_of(target) or target.global_transform!=sampled_transform or not host.player.global_position.is_equal_approx(sampled_position):return {}
	if (target.collision_layer & host.player.climbable_mask)==0:return {}
	var geometry:Dictionary=target.climb_geometry()
	if geometry.is_empty() or geometry.get("type","")!="ladder" or Vector2(geometry.width,float(geometry.bottom_y)-float(geometry.top_y))!=sampled_size:return {}
	var current:=snapshot.duplicate(true)
	current.held=host.player.main_action==&"climb" and is_instance_valid(host.player._climb_target) and host.player._climb_target==target
	return current
func _exit_tree()->void:retire()

func read_visible_snapshot()->Dictionary:
	if not is_instance_valid(host) or not host.blind:return {}
	return read_snapshot()
