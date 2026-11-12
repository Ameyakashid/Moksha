extends Node
## Room-local read-only adapter. No world mutation, noise subscription or save state.
const Query=preload("res://campaign/perception/local_scent_query.gd")
var host:Node
var view:Node2D
var observed_room:WeakRef
var observed_session:=-1
var sources:Array[Dictionary]=[]
var connections:Array[Dictionary]=[]
var snapshot:Array[Dictionary]=[]
var remaining:=0.0
var enabled:=true
var cache_claimed:=false
func bind(owner_host:Node)->void:
	host=owner_host;process_mode=Node.PROCESS_MODE_ALWAYS
	var layer:=CanvasLayer.new();layer.layer=22;add_child(layer)
	view=preload("res://campaign/perception/scent_view.gd").new();layer.add_child(view)
	view.allowed=presentation_allowed
	view.safe_bounds=read_safe_bounds
func retire()->void:
	for connection in connections:
		var node=connection.ref.get_ref()
		if is_instance_valid(node) and node.is_connected(connection.signal_name,connection.callback):node.disconnect(connection.signal_name,connection.callback)
	connections.clear();sources.clear();snapshot.clear();observed_room=null;remaining=0
	if is_instance_valid(view):view.clear()
func invalidate(_a:Variant=null,_b:Variant=null,_c:Variant=null)->void:
	snapshot.clear();remaining=0
	if is_instance_valid(view):view.clear()
func watch(node:Node,signal_name:String)->void:
	if not node.has_signal(signal_name):return
	var callback:=Callable(self,"invalidate")
	if node.is_connected(signal_name,callback):return
	node.connect(signal_name,callback);connections.append({"ref":weakref(node),"signal_name":signal_name,"callback":callback})
func presentation_allowed()->bool:
	return enabled and is_instance_valid(host) and not host._loading_campaign and host.state=="playing" and not get_tree().paused and observed_session==host.session_generation and observed_room!=null and is_instance_valid(observed_room.get_ref()) and observed_room.get_ref()==host.room and is_instance_valid(host.player) and not host.player.is_queued_for_deletion()
func register_room()->void:
	retire();observed_session=host.session_generation;observed_room=weakref(host.room)
	cache_claimed=host.caches.has(host.sector)
	for enemy in host.enemies:
		if sources.size()>=Query.MAX_SOURCES:break
		if not is_instance_valid(enemy) or not host.room.is_ancestor_of(enemy):continue
		sources.append({"ref":weakref(enemy),"kind":"life"});watch(enemy,"tree_exiting")
		if is_instance_valid(enemy._health):
			watch(enemy._health,"health_changed");watch(enemy._health,"depleted")
	for goal in host.goals:
		if sources.size()>=Query.MAX_SOURCES:break
		if is_instance_valid(goal) and goal.optional and goal.kind=="recover" and not str(goal.specification.get("reward","")).is_empty():
			sources.append({"ref":weakref(goal),"kind":"supply"});watch(goal,"changed");watch(goal,"tree_exiting")
func collect()->Array:
	var facts:Array=[]
	for source in sources:
		var node=source.ref.get_ref()
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not host.room.is_ancestor_of(node):continue
		if source.kind=="life":
			if node.dead or not is_instance_valid(node._health) or node._health.current_health<=0:continue
			facts.append({"kind":"life","offset":node.global_position-host.player.global_position,"wounded":node._health.current_health<node._health.capacity})
		else:
			var reward_id:=str(host.sectors[host.sector].id)+"/"+str(node.objective_id)
			if node.completed or host.rewards.has(reward_id) or not node.required_ids.all(func(id):return host.goal_done(id)):continue
			facts.append({"kind":"supply","offset":node.global_position-host.player.global_position})
	var district:Dictionary=host.sectors[host.sector]
	if district.has("cache") and not host.caches.has(host.sector) and facts.size()<Query.MAX_SOURCES:
		facts.append({"kind":"supply","offset":Vector2(district.cache)-host.player.position})
	return facts
func _process(dt:float)->void:
	if not is_instance_valid(host):retire();return
	if not enabled or host.state!="playing" or get_tree().paused or host._loading_campaign or not is_instance_valid(host.room) or not is_instance_valid(host.player):retire();return
	if observed_session!=host.session_generation or observed_room==null or observed_room.get_ref()!=host.room:register_room()
	if cache_claimed!=host.caches.has(host.sector):
		cache_claimed=host.caches.has(host.sector);invalidate()
	remaining-=dt
	if remaining<=0:
		snapshot=Query.sample(collect());remaining=.25
	var anchor:Vector2=host.player.global_position-host.camera.position+Vector2(320,180)+Vector2(0,-20)
	view.present(snapshot,anchor)
func _exit_tree()->void:retire()

func read_snapshot()->Array[Dictionary]:
	if not presentation_allowed():return []
	return snapshot.duplicate(true)

func read_safe_bounds()->Rect2:
	if not is_instance_valid(host) or not is_instance_valid(host.hud):return Rect2()
	return host.hud.caption_safe_rect().intersection(Rect2(Vector2.ZERO,get_viewport().get_visible_rect().size))
