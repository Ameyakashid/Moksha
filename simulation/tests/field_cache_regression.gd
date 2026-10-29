extends SceneTree
const Marker = preload("res://simulation/world/field_cache.tscn")
const Appearance = preload("res://demo/views/field_cache_appearance.gd")
const Support = preload("res://simulation/tests/field_cache_support.gd")
const Sonar = preload("res://demo/components/mission_sonar.gd")
var hz := 60
var checks := 0
var failures: Array[String] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz=int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second=hz
	_run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label); print("FAIL ",label)
func sonar_for(world: Node2D):
	var sonar=Sonar.new();sonar.tuning=preload("res://resources/sensory/sonar_default.tres").duplicate(true)
	root.add_child(sonar);sonar.set_process(false);sonar.bind_level(world,null);sonar.set_blind(true)
	return sonar
func alphas(sonar) -> Array:
	var result: Array=[]
	for record in sonar.geometry: result.append(sonar._segment_alphas(record))
	return result
func _run() -> void:
	var legacy:=Support.legacy_room_script()
	var count:=0
	for data in preload("res://demo/mission_data.gd").sectors():
		var world:=Node2D.new();root.add_child(world)
		var old=legacy.new();var fresh=preload("res://demo/components/mission_room.gd").new()
		world.add_child(old);world.add_child(fresh);old.build(data);fresh.build(data)
		old.set_process(false);fresh.set_process(false)
		check(Support.topology(old,[])==Support.topology(fresh,[]),"exact ordered physical topology")
		check(Support.contours(old)==Support.contours(fresh),"exact ordered collision-derived sonar contours")
		if data.has("cache"):
			count+=1
			var m=fresh.field_cache
			check(m.position==data.cache and m.raster_reference==data.cache,"authored cache placement/reference")
			check(m.show_behind_parent and m.z_index==-1 and m.z_as_relative and not m.top_level,"mission-only last foreground depth")
			for relay in fresh.relay_markers:check(relay.z_index<m.z_index,"cache paints after every relay")
			check(m.get_node("CacheContour").get_groups().is_empty(),"unfound contour has no sonar exemption")
			m.appearance.ink=Color.RED
			check(Support.topology(old,[])==Support.topology(fresh,[]),"appearance cannot change physics")
		else:check(fresh.field_cache==null,"no invented cache")
		check(fresh.get_child(fresh.get_child_count()-1)==fresh.onward_marker,"onward remains last in physical traversal")
		var sa=sonar_for(old);var sb=sonar_for(fresh)
		var origin:Vector2=data.get("cache",Vector2(float(data.width)-45,300))+Vector2(-60,-9)
		sa._on_noise_emitted(origin,&"weapon_tap",0.8,old);sb._on_noise_emitted(origin,&"weapon_tap",0.8,fresh)
		for frame in range(hz*3):
			sa.advance_simulation(1.0/hz);sb.advance_simulation(1.0/hz)
			check(alphas(sa)==alphas(sb),"actual contour pulse timing/alpha parity")
		check(sa.pulses.is_empty() and sb.pulses.is_empty(),"real pulses expire")
		for found in [true,false]:
			old.set_cache_found(found);fresh.set_cache_found(found);sa.refresh_geometry();sb.refresh_geometry()
			check(Support.topology(old,[])==Support.topology(fresh,[]) and Support.contours(old)==Support.contours(fresh),"found/remove/restore ordered physics and sonar parity")
			check(alphas(sa)==alphas(sb),"found state refresh preserves exact contour records")
		sa.free();sb.free();world.free()
	check(count==5,"all five production caches extracted")
	mixed_topology_test()
	await standalone_test()
	await passage_test()
	await mission_test()
	var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"production_caches":count,"scope":"Actual geometry/sonar/lifecycle/solver passage plus labelled direct-state mission contract probes; full routes remain separate."}
	FileAccess.open("res://simulation/evidence/field_cache_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FIELD CACHE ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func mixed_topology_test() -> void:
	var data:Dictionary={"theme":"interior","width":350,"platforms":[],"station":Vector2(305,300),"relay":Vector2(303,292),"relays":[Vector2(300,290),Vector2(307,295)],"cache":Vector2(310,285)}
	var old=Support.legacy_room_script().new();var fresh=preload("res://demo/components/mission_room.gd").new()
	root.add_child(old);root.add_child(fresh);old.build(data);fresh.build(data);old.set_process(false);fresh.set_process(false)
	for found in [false,true,false]:
		old.set_cache_found(found);fresh.set_cache_found(found)
		check(Support.topology(old,[])==Support.topology(fresh,[]) and Support.contours(old)==Support.contours(fresh),"mixed keys preserve singular-cache-plural physical and sonar order")
	check(fresh.exchange_station.get_index()<fresh.relay_markers[2].get_index() and fresh.relay_markers[2].get_index()<fresh.field_cache.get_index() and fresh.field_cache.get_index()<fresh.relay_markers[0].get_index(),"actual insertion slots station singular cache plural")
	check(fresh.field_cache.z_index>fresh.relay_markers[2].z_index and fresh.field_cache.z_index<0,"cache paints last before ordinary dynamic children")
	old.free();fresh.free()
func standalone_test() -> void:
	var world:=Node2D.new();root.add_child(world)
	var a=Marker.instantiate();var b=Marker.instantiate();a.is_found=true
	world.add_child(a);world.add_child(b)
	check(a.is_found and a.get_node("View").is_found and a.get_node("CacheContour").is_in_group("sonar_ignore"),"found before entry syncs paint and group")
	check(a.z_index==0 and not a.show_behind_parent and a.z_as_relative and not a.top_level,"standalone canvas defaults unchanged")
	check(a.appearance!=b.appearance and a.get_node("CacheContour/Shape").shape!=b.get_node("CacheContour/Shape").shape,"local resources isolated")
	a.appearance.ink=Color.RED
	check(b.appearance.ink==Color("b1c9d1") and not b.is_found,"state and paint isolation")
	var retired=a.appearance;var replacement=Appearance.new();a.appearance=replacement
	check(not retired.changed.is_connected(a.get_node("View").queue_redraw) and replacement.changed.is_connected(a.get_node("View").queue_redraw),"retired resource disconnects")
	b.appearance=replacement;replacement.ink=Color.BLUE;check(b.appearance.ink==Color.BLUE,"explicit sharing supported")
	b.appearance=replacement.duplicate(true);replacement.ink=Color.RED;check(b.appearance.ink==Color.BLUE,"explicit copy isolates")
	a.raster_reference=Vector2(-20.75,-0.25);a.raster_reference=Vector2(NAN,0)
	check(a.raster_reference==Vector2(-20.75,-0.25),"nonfinite raster anchor rejected")
	var parent:=Node2D.new();parent.position=Vector2(30,-50);parent.rotation=0.3;parent.scale=Vector2(1.3,0.8);world.add_child(parent)
	a.reparent(parent);a.position=Vector2(12.5,-4.75);a.rotation=-0.2;a.scale=Vector2(0.8,1.2)
	check(a.get_node("CacheContour").global_transform.is_equal_approx(a.global_transform*Transform2D(0,Vector2(0,-9))),"composed native contour transform")
	var sonar=sonar_for(parent)
	check(sonar.geometry.is_empty(),"found marker contributes no sonar geometry")
	var invalidations:Array=[];a.geometry_invalidated.connect(func():invalidations.append(a.is_found))
	a.geometry_invalidated.connect(sonar.refresh_geometry)
	a.is_found=false
	check(sonar.geometry.size()==1 and invalidations==[false],"explicit consumer connection restores geometry synchronously")
	a.is_found=false;check(invalidations.size()==1,"same state emits no redundant invalidation")
	a.hide();a.appearance=null;sonar.refresh_geometry()
	check(sonar.geometry.size()==1 and not a.get_node("CacheContour/Shape").disabled,"hidden/null appearance retains enabled sonar contour")
	parent.remove_child(a);sonar.refresh_geometry();check(sonar.geometry.is_empty(),"explicit refresh after detach removes contour")
	a.is_found=true;parent.add_child(a);sonar.refresh_geometry();check(sonar.geometry.is_empty(),"detached found update survives reattachment")
	a.is_found=false;check(sonar.geometry.size()==1,"restored state after reattachment returns contour")
	a.show();a.appearance=Appearance.new();a.appearance.ink=Color.CORAL;a.is_found=true
	var pack:=PackedScene.new();check(pack.pack(a)==OK,"configured instance packs")
	check(ResourceSaver.save(pack,"user://field_cache_roundtrip.tscn")==OK,"configured instance saves")
	var restored=load("user://field_cache_roundtrip.tscn").instantiate();world.add_child(restored)
	check(restored.is_found and restored.appearance.ink==Color.CORAL and restored.raster_reference==a.raster_reference and restored.transform==a.transform,"found/style/placement serialize")
	check(restored.appearance!=a.appearance and restored.get_node("CacheContour/Shape").shape!=a.get_node("CacheContour/Shape").shape,"serialized local resources isolated")
	a.get_node("View").free();a.is_found=false;check(sonar.geometry.size()==1,"removed optional view retains contour")
	a.is_found=true;check(sonar.geometry.is_empty() and not a.get_node("CacheContour/Shape").disabled,"found with no View ignores but never disables shape")
	a.is_found=false;a.free();sonar.refresh_geometry();check(sonar.geometry.is_empty(),"deletion leaves no ghost contour")
	sonar.free();world.free()
	var marker=Marker.instantiate();root.add_child(marker);sonar=sonar_for(marker)
	check(sonar.geometry.size()==1 and sonar.geometry[0].a.size()==12,"actual 16x18 contour yields twelve sampled fragments")
	var origin:Vector2=marker.global_position+Vector2(-60,-9)
	sonar._on_noise_emitted(origin,&"weapon_tap",0.8,marker)
	check(sonar.accepted_event_count==1 and sonar.pulses[0].origin==origin,"real scoped emission origin admitted")
	var peak:=0.0;var first_visible:=-1.0
	for frame in range(hz*3):
		sonar.advance_simulation(1.0/hz)
		for alpha in sonar._segment_alphas(sonar.geometry[0]):
			peak=maxf(peak,alpha)
			if alpha>0.015 and first_visible<0:first_visible=float(frame+1)/hz
	check(peak>0.015 and first_visible>0,"actual pulse arrives after propagation delay")
	var residual:=0.0
	for alpha in sonar._segment_alphas(sonar.geometry[0]):residual=maxf(residual,alpha)
	check(sonar.pulses.is_empty() and residual==0.0,"pulse and illumination fully expire")
	sonar._on_noise_emitted(origin,&"weapon_tap",0.8,marker);marker.is_found=true;sonar.refresh_geometry()
	check(sonar.geometry.is_empty() and sonar.pulses[0].tracks.is_empty(),"found invalidation removes existing pulse tracks")
	marker.is_found=false;sonar.refresh_geometry();check(sonar.geometry.size()==1 and sonar.pulses[0].tracks.size()==1,"restore resamples real existing pulse track")
	sonar.free();marker.free()
func passage_test() -> void:
	var world:=Node2D.new();root.add_child(world)
	var marker=Marker.instantiate();world.add_child(marker)
	for scene in [preload("res://combat_pc/player.tscn"),preload("res://simulation/actors/shared_actor.tscn")]:
		var actor=scene.instantiate();actor.automatic_physics=false;world.add_child(actor)
		if actor.has_node("IntentDriver"):actor.get_node("IntentDriver").automatic_driver=false
		for mode in range(4):
			marker.is_found=mode==1
			marker.visible=mode!=2
			if mode==3:marker.appearance=null
			actor.position=Vector2(-80,-9);await physics_frame
			var hit=actor.move_and_collide(Vector2(160,0))
			check(hit==null and actor.position.is_equal_approx(Vector2(80,-9)),"actual PC/shared NPC crosses found/hidden/null cache mode %d"%mode)
			check(not marker.get_node("CacheContour/Shape").disabled,"nonblocking contour remains enabled")
		actor.free()
	marker.get_node("View").free()
	var cargo=preload("res://scenes/props/crate.tscn").instantiate()
	cargo.set_script(preload("res://demo/components/mission_prop.gd"));cargo.collision_mask=43
	cargo.tuning=cargo.tuning.duplicate(true);cargo.tuning.body_gravity_scale=0;cargo.tuning.body_linear_damp=0
	cargo.position=Vector2(-80,-9);world.add_child(cargo);cargo.linear_velocity=Vector2(160,0)
	for frame in range(hz):await physics_frame
	check(cargo.alive and cargo.position.x>40,"real production shared cargo solver crosses enabled contour without view")
	world.free()
func key(host,code:int) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=true;host._unhandled_key_input(event)
func mission_test() -> void:
	var host=load("res://demo/mission.tscn").instantiate();root.add_child(host);host.save_enabled=false;host.start_new(true)
	host.set_process(false);host.set_physics_process(false)
	for sector in host.sectors.size():
		if not host.sectors[sector].has("cache"):continue
		host.load_sector(sector);host.room.process_mode=Node.PROCESS_MODE_DISABLED
		var point:Vector2=host.sectors[sector].cache
		host.player.reset_actor(point,1);check(not host.caches.has(sector) and not host.room.cache_found,"proximity alone never collects cache")
		for distance in [45.01,45.0]:
			host.player.reset_actor(point+Vector2(-distance,0),1);host.bus.clear_history();key(host,KEY_E)
			check(not host.caches.has(sector) and host.bus.event_history.is_empty(),"strict E distance at least 45 excluded")
		host.player.reset_actor(point+Vector2(-44.99,0),1);host.player.receive_attack({"amount":10.0,"hitpause":0.0});host.bus.clear_history();check(host.health.current_health<host.health.capacity,"direct attack receipt reduces Health before collection");key(host,KEY_E)
		check(host.caches.has(sector) and host.room.cache_found and host.room.field_cache.is_found,"E within strict boundary collects and forwards found state")
		check(host.state=="archive" and paused and host.archive_text==host.sectors[sector].get("archive","A field record recovered."),"collection opens correct paused archive")
		check(host.health.current_health==host.health.capacity,"collection resets actual Health to full")
		var events:Array=host.bus.event_history
		check(events.size()==1 and events[0].origin==point-Vector2(0,10) and events[0].kind==&"weapon_tap" and events[0].loudness==0.8 and events[0].source_id==host.room.get_instance_id(),"unchanged exact room-sourced weapon tap")
		check(not host.sonar.geometry.any(func(g):return g.body.get_ref()==host.room.field_cache.get_node("CacheContour")),"mission explicit refresh removes contour immediately")
		host.bus.clear_history();host.interact();check(host.bus.event_history.is_empty(),"nonplaying archive blocks repeated interaction")
		key(host,KEY_E);check(host.state=="playing" and not paused,"E dismisses archive")
		host.interact();check(host.caches.count(sector)==1 and host.bus.event_history.is_empty(),"collected cache cannot heal or emit again")
		host.load_sector(sector);check(host.room.field_cache.is_found and host.caches.has(sector),"retry reconstructs collected state")
	# Same-location synthetic fixture proves station priority; no level data changed.
	var mixed:Dictionary=host.sectors[0].duplicate(true);mixed.station=mixed.cache;mixed.erase("relay");mixed.erase("relays");mixed.enemies=[];mixed.props=[]
	host.sectors[0]=mixed;host.caches.erase(0);host.blind=false;host.load_sector(0);host.player.reset_actor(mixed.cache,1);host.bus.clear_history();key(host,KEY_E)
	check(host.state=="choice" and paused and not host.caches.has(0) and host.bus.event_history.is_empty(),"station retains priority over overlapping cache")
	host.choose_sight(false);key(host,KEY_E);check(host.state=="choice" and not host.caches.has(0),"rejected trade still leaves station ahead of cache")
	host.choose_sight(true);host.bus.clear_history();key(host,KEY_E);check(host.state=="archive" and host.caches.has(0),"traded sight makes cache eligible through unchanged priority")
	# Isolated user directory: preserve any preexisting checkpoint bytes anyway.
	var existed:=FileAccess.file_exists(host.SAVE);var saved:=FileAccess.get_file_as_bytes(host.SAVE) if existed else PackedByteArray()
	host.save_enabled=true;host._save_checkpoint();host.show_title();host.continue_run()
	check(host.caches.has(0) and host.room.field_cache.is_found and host.blind,"actual checkpoint continue retains collection and trade")
	if existed:FileAccess.open(host.SAVE,FileAccess.WRITE).store_buffer(saved)
	else:DirAccess.remove_absolute(ProjectSettings.globalize_path(host.SAVE))
	paused=false;host.free();await process_frame
