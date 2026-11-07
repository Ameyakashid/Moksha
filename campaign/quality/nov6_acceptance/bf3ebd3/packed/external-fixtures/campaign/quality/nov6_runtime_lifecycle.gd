extends SceneTree
## Deterministic campaign lifecycle/cache fixtures, not traversal or renderer QA.
const CampaignSonar = preload("res://campaign/presentation/campaign_sonar.gd")
const DemoSonar = preload("res://demo/components/mission_sonar.gd")
var failures:Array[String]=[]
var checks:=0
var failed_checks:=0
var failure_counts:Dictionary={}
var output_path:=""
var rows:Array[Dictionary]=[]
var baseline:Dictionary={}
var host:Node
var oracle:CanvasLayer
var hz:=60
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
		if arg.begins_with("--output="):output_path=arg.trim_prefix("--output=")
	Engine.physics_ticks_per_second=hz
	run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failed_checks+=1
		failure_counts[label]=int(failure_counts.get(label,0))+1
		if failures.size()<120:failures.append(label)
func settle()->void:
	await process_frame
	await process_frame
func cache_sizes()->Dictionary:
	return {"nodes":get_node_count(),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"shape_cache":host.sonar._shape_cache.size(),"bounds_cache":host.sonar._bounds_cache.size(),"watches":host.sonar._watched_shapes.size(),"paint":host.object_paint.records.size(),"contours":host.sonar.geometry.size()}
func bounded(label:String)->void:
	var node_ids:Dictionary={};var shape_ids:Dictionary={};var bound_keys:Dictionary={}
	for record in host.sonar.geometry:
		var anchor=record.anchor.get_ref()
		check(is_instance_valid(anchor) and host.room.is_ancestor_of(anchor),label+" live current contour")
		if anchor is CollisionShape2D:
			node_ids[anchor.get_instance_id()]=true;shape_ids[anchor.shape.get_instance_id()]=true
		bound_keys[str(record.key)+":"+str(record.fingerprint)]=true
	check(host.sonar._shape_cache.size()==node_ids.size(),label+" bounded shape cache")
	check(host.sonar._watched_shapes.size()==shape_ids.size(),label+" bounded shape watches")
	for key in host.sonar._bounds_cache:check(bound_keys.has(key),label+" no stale bounds")
	for id in host.sonar._watched_shapes:check(is_instance_id_valid(id),label+" no dead shape ID")
	host.object_paint._sync()
	for record in host.object_paint.records:check(is_instance_valid(record.node.get_ref()),label+" no stale paint record")
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)==0,label+" no orphan nodes")
func compare_geometry()->void:
	check(host.sonar.geometry.size()==oracle.geometry.size(),"oracle contour count")
	for i in mini(host.sonar.geometry.size(),oracle.geometry.size()):
		var actual:Dictionary=host.sonar.geometry[i];var expected:Dictionary=oracle.geometry[i]
		for key in ["key","body_id","a","b","arc","length","closed","dynamic","enemy","fingerprint"]:
			check(actual[key]==expected[key],"oracle geometry "+key)
func compare_pulses()->void:
	check(host.sonar.pulses.size()==oracle.pulses.size(),"oracle pulse count")
	for i in mini(host.sonar.pulses.size(),oracle.pulses.size()):
		var actual:Dictionary=host.sonar.pulses[i];var expected:Dictionary=oracle.pulses[i]
		for key in actual:
			if key!="tracks":check(actual[key]==expected[key],"oracle pulse "+str(key))
		check(actual.tracks.keys()==expected.tracks.keys(),"oracle track keys")
		for key in actual.tracks:
			if not expected.tracks.has(key):continue
			var track:Dictionary=actual.tracks[key];var other:Dictionary=expected.tracks[key]
			for field in track:
				if field!="geometry":check(track[field]==other[field],"oracle propagation "+str(field))
	for i in mini(host.sonar.geometry.size(),oracle.geometry.size()):
		check(host.sonar._segment_alphas(host.sonar.geometry[i])==oracle._segment_alphas(oracle.geometry[i]),"oracle alpha array")
func run()->void:
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true)
	host.set_process(false);host.set_physics_process(false);host.sonar.set_process(false);paused=true
	await settle()
	check(host.sonar.get_script()==CampaignSonar,"campaign uses cleanup adapter")
	check(host.sonar._canvas.sonar==host.sonar,"new sonar canvas owns correct sonar")
	var sonar_connections:=0
	for connection in host.bus.noise_emitted.get_connections():
		if connection.callable.get_method()=="_on_noise_emitted":sonar_connections+=1
	check(sonar_connections==1,"exactly one campaign sonar listener")
	# Every actual district, actual retry handler, and title/resume, four times.
	for sweep in 4:
		for index in host.sectors.size():
			var old_room=weakref(host.room);var old_player=weakref(host.player)
			host.blind=(sweep%2==1);host.load_sector(index);paused=true;await settle();host.sonar.refresh_geometry()
			check(old_room.get_ref()==null and old_player.get_ref()==null,"room and actor actually freed")
			bounded("load")
			host._pending_retry=true;host._physics_process(1.0/hz);paused=true;await settle();host.sonar.refresh_geometry();bounded("retry")
			host.show_title();await settle();check(host.state=="title" and paused,"title pauses")
			host.load_sector(index);paused=true;await settle();host.sonar.refresh_geometry();bounded("title resume")
			var counts:=cache_sizes();counts["sweep"]=sweep;counts["district"]=index
			if sweep<=1:baseline[index]=counts
			else:
				# First sweep warms the two captain archetypes and Warden resources.
				for key in ["nodes","resources","shape_cache","watches","paint","contours"]:check(counts[key]==baseline[index][key],"stable per-district "+key)
			rows.append(counts)
	# New and preserved adapter share exactly the same live geometry and noise.
	oracle=CanvasLayer.new();oracle.set_script(DemoSonar);oracle.tuning=host.sonar.tuning.duplicate(true);root.add_child(oracle);oracle.set_process(false)
	for index in host.sectors.size():
		host.load_sector(index);paused=true;await settle();host.sonar.set_process(false)
		host.sonar.bind_level(host.room,host.player);oracle.bind_level(host.room,host.player)
		host.sonar.set_blind(host.blind);oracle.set_blind(host.blind)
		compare_geometry()
		paused=false
		for kind in ["weapon_tap","prop_impact","enemy_attack"]:
			host.bus.emit_noise(host.player.position,kind,1.4,host.player)
			for dt in [0.0,0.01,1.0/hz,0.12,0.35]:
				host.sonar.advance_simulation(dt);oracle.advance_simulation(dt);compare_pulses()
		paused=true
	# Two live colliders intentionally share one resource. Both sonar consumers
	# must receive changes exactly once; retiring ours must leave the observer.
	var shared:=RectangleShape2D.new();shared.size=Vector2(35,35)
	var holders:Array[StaticBody2D]=[]
	for index in 2:
		var body:=StaticBody2D.new();body.collision_layer=0;body.position=host.player.position+Vector2(150+index*70,-80)
		var shape:=CollisionShape2D.new();shape.shape=shared;body.add_child(shape);host.room.add_child(body);holders.append(body)
	host.sonar.refresh_geometry();oracle.refresh_geometry();compare_geometry()
	var actual_callback:=Callable(host.sonar,"_invalidate_shape_cache")
	var observer_callback:=Callable(oracle,"_invalidate_shape_cache")
	check(shared.changed.is_connected(actual_callback) and shared.changed.is_connected(observer_callback),"both shared-shape observers subscribed")
	check(shared.changed.get_connections().filter(func(connection):return connection.callable==actual_callback).size()==1,"one callback for a resource shared by two colliders")
	shared.size=Vector2(53,41)
	check(host.sonar._shape_cache.is_empty() and oracle._shape_cache.is_empty(),"live shared shape invalidates both caches")
	host.sonar.refresh_geometry();oracle.refresh_geometry();compare_geometry();compare_pulses()
	holders[0].free();host.sonar.refresh_geometry();oracle.refresh_geometry()
	check(shared.changed.is_connected(actual_callback),"remaining live collider keeps watch")
	holders[1].free();host.sonar.refresh_geometry();oracle.refresh_geometry();compare_geometry();compare_pulses()
	check(not shared.changed.is_connected(actual_callback),"last collider retirement disconnects campaign callback")
	check(shared.changed.is_connected(observer_callback),"campaign cleanup preserves other observer callback")
	var size_before:int=host.sonar._shape_cache.size();shared.size=Vector2(61,49)
	check(host.sonar._shape_cache.size()==size_before,"retired shared resource leaves current campaign cache intact")
	check(oracle._shape_cache.is_empty(),"other observer still receives retired resource changes")
	shared=null
	oracle.queue_free();await settle()
	# Real local replacements must not retain weak paint records or cached tracks.
	var freight:=-1
	for i in host.sectors.size():
		if host.sectors[i].id=="l2_freight":freight=i
	check(freight>=0,"freight fixture found")
	host.load_sector(freight);paused=true;await settle();host.sonar.refresh_geometry();host.object_paint._sync()
	var before:=cache_sizes();var cradle:Node
	for node in host.room.find_children("*","",true,false):
		if node.has_method("replace_cargo"):cradle=node;break
	for i in 200:
		var old=weakref(cradle.cargo);check(cradle.replace_cargo(),"replacement accepted");await settle();host.sonar.refresh_geometry();bounded("replacement")
		check(old.get_ref()==null,"old cargo freed")
		var counts:=cache_sizes()
		for key in ["nodes","resources","shape_cache","watches","paint","contours"]:check(counts[key]==before[key],"replacement constant "+key)
	# Retained old resources must lose only this adapter's subscription.
	var old_shape:Shape2D=host.sonar.geometry[0].anchor.get_ref().shape
	var callback:=Callable(host.sonar,"_invalidate_shape_cache")
	check(old_shape.changed.is_connected(callback),"live shape subscribed")
	host.load_sector(0);paused=true;await settle();host.sonar.refresh_geometry()
	check(not old_shape.changed.is_connected(callback),"old retained shape unsubscribed")
	var cached_before:int=host.sonar._shape_cache.size();old_shape.emit_changed()
	check(host.sonar._shape_cache.size()==cached_before,"old shape cannot invalidate current cache")
	old_shape=null
	# Reject non-finite external noise and simulation deltas without poisoning state.
	paused=false
	var count:int=host.sonar.accepted_event_count;var elapsed:float=host.sonar.elapsed
	for value in [NAN,INF,-INF]:
		host.bus.emit_noise(Vector2(value,0),&"weapon_tap",1,host.player)
		host.bus.emit_noise(Vector2.ZERO,&"weapon_tap",value,host.player)
		host.sonar.advance_simulation(value)
	check(host.sonar.accepted_event_count==count and host.sonar.elapsed==elapsed,"invalid noise and dt leave sonar finite and unchanged")
	# Finite but extreme event intensity is clamped by inherited tuning.
	for intensity in [1.0e-30,1.0e30]:
		host.bus.emit_noise(host.player.position,&"weapon_tap",intensity,host.player)
		host.sonar.advance_simulation(0.1)
		for pulse in host.sonar.pulses:
			for field in ["radius","strength","trail","age","lifetime"]:check(is_finite(pulse[field]),"finite extreme sound profile")
		for contour in host.sonar.geometry:
			for value in host.sonar._segment_alphas(contour):check(is_finite(value) and value>=0 and value<=1,"bounded finite sound alpha")
	paused=true
	# Smooth camera remains a bounded finite presentation-only calculation over
	# authored districts, reversals, teleports, zero/negative and long frame gaps.
	var rig=preload("res://campaign/presentation/camera_follow.gd").new()
	var random:=RandomNumberGenerator.new();random.seed=609316
	var steps:=[-0.1,0.0,1.0e-9,1.0/120,1.0/60,0.1,1.0,10.0]
	for district in host.sectors:
		var untouched:Dictionary=district.duplicate(true)
		rig.reset(district.get("spawn",Vector2(75,300)),district)
		for i in 2048:
			var point:=Vector2(random.randf_range(-200,float(district.width)+200),random.randf_range(float(district.get("top",-100))-200,700))
			var speed:=Vector2(random.randf_range(-2000,2000),random.randf_range(-4000,4000))
			var view:Vector2=rig.follow(point,speed,district,steps[i%steps.size()])
			check(view.is_finite(),"camera finite")
			check(view.x>=320 and view.x<=maxf(320,float(district.width)-320) and view.y>=minf(180,float(district.get("top",-100))+180) and view.y<=180,"camera inside authored bounds")
		check(district==untouched,"camera does not mutate level data")
	var old_host=weakref(host);host.queue_free();await settle();await settle()
	check(old_host.get_ref()==null and get_node_count()==2,"whole host teardown returns to root and bus")
	check(root.get_node("NoiseBus").noise_emitted.get_connections().is_empty(),"no bus listeners after teardown")
	check(node_added.get_connections().is_empty(),"no tree listeners after teardown")
	var result={"hz":hz,"checks":checks,"failed_checks":failed_checks,"failures":failures,"failure_counts":failure_counts,"passed":failures.is_empty(),"district_sweeps":4,"district_retry_title_loads":384,"cargo_replacements":200,"oracle_districts":32,"samples":rows,"scope":"Deterministic lifecycle, inherited sonar output equality, finite noise/dt rejection. Not a gameplay traversal or target-hardware FPS claim."}
	if not output_path.is_empty():
		var output=FileAccess.open(output_path,FileAccess.WRITE)
		if output:output.store_string(JSON.stringify(result,"\t"));output.close()
	print("NOV6_RUNTIME_LIFECYCLE_RESULT "+JSON.stringify(result));quit(0 if failures.is_empty() else 1)
