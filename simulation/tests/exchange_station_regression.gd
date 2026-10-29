extends SceneTree
const Marker = preload("res://simulation/world/exchange_station.tscn")
const Appearance = preload("res://demo/views/exchange_station_appearance.gd")
const Support = preload("res://simulation/tests/exchange_station_support.gd")
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
		var m=fresh.exchange_station
		if data.has("station"):
			count+=1
			check(m.position==data.station and m.raster_reference==m.position,"authored station placement/reference")
			check(m.show_behind_parent and m.z_index>fresh.onward_marker.z_index and m.z_index<0,"mission-only render depths preserve layers")
			check(fresh.get_child(fresh.get_child_count()-1)==fresh.onward_marker,"onward traversal remains last")
			m.appearance.ink=Color.RED
			check(Support.topology(old,[])==Support.topology(fresh,[]) and Support.contours(old)==Support.contours(fresh),"paint cannot change physics or sonar geometry")
		else: check(m==null,"no invented station in other rooms")
		var sa=sonar_for(old);var sb=sonar_for(fresh)
		var origin: Vector2=data.get("station",Vector2(float(data.width)-45,float(data.get("gate_y",300))))+Vector2(-60,-21)
		sa._on_noise_emitted(origin,&"weapon_tap",1.0,old);sb._on_noise_emitted(origin,&"weapon_tap",1.0,fresh)
		check(sa.accepted_event_count==1 and sb.accepted_event_count==1,"actual scoped production sonar admits source")
		for frame in range(hz*3):
			sa.advance_simulation(1.0/hz);sb.advance_simulation(1.0/hz)
			check(alphas(sa)==alphas(sb),"actual contour pulse timing/alpha parity")
		check(sa.pulses.is_empty() and sb.pulses.is_empty(),"real pulses expire")
		sa.free();sb.free();world.free()
	check(count==2,"both production stations extracted")
	var world:=Node2D.new();root.add_child(world)
	var a=Marker.instantiate();var b=Marker.instantiate();a.appearance.label="TRADE"
	world.add_child(a);world.add_child(b)
	check(a.get_node("View").appearance.label=="TRADE","explicit state before tree entry")
	check(a.appearance!=b.appearance and a.get_node("StationContour/Shape").shape!=b.get_node("StationContour/Shape").shape,"per-instance appearance and shape resources")
	var original:=Support.contours(a)
	a.appearance.ink=Color.RED;a.appearance.label="EXIT";a.appearance.label="THE EXCHANGE"
	check(b.appearance.ink==Color("e9d2ab") and b.appearance.label=="THE EXCHANGE","paint and state edits isolated")
	check(Support.contours(a)==original,"all state/paint inputs leave contour invariant")
	var retired=a.appearance;var replacement=Appearance.new();a.appearance=replacement
	check(not retired.changed.is_connected(a.get_node("View").queue_redraw) and replacement.changed.is_connected(a.get_node("View").queue_redraw),"replacement removes retired redraw subscription")
	var font:=preload("res://fonts/DejaVuSansMono.ttf").duplicate(true);replacement.font=font
	check(font.changed.is_connected(replacement._font_changed),"custom font changes propagate")
	replacement.font=null;check(not font.changed.is_connected(replacement._font_changed),"old font subscription disconnected")
	b.appearance=replacement;replacement.font_size=13;check(b.appearance.font_size==13,"explicit appearance sharing is intentional")
	b.appearance=replacement.duplicate(true);replacement.font_size=17;check(b.appearance.font_size==13,"explicit deep copy isolates edits")
	a.raster_reference=Vector2(-20.75,-0.25);a.raster_reference=Vector2(NAN,0);replacement.font_size=0
	check(a.raster_reference==Vector2(-20.75,-0.25) and replacement.font_size==17,"invalid input keeps last valid configuration")
	var parent:=Node2D.new();parent.position=Vector2(30,-50);parent.rotation=0.3;parent.scale=Vector2(1.3,0.8);world.add_child(parent)
	a.reparent(parent);a.position=Vector2(12.5,-4.75);a.rotation=-0.2;a.scale=Vector2(0.8,1.2)
	check(a.raster_reference==Vector2(-20.75,-0.25),"raster reference remains fixed under parent/root transforms")
	check(a.get_node("StationContour").global_transform.is_equal_approx(a.global_transform*Transform2D(0,Vector2(0,-21))),"contour follows native composed transform")
	var sonar=sonar_for(parent)
	check(sonar.geometry.size()==1 and not sonar.geometry[0].dynamic,"real static contour survives nested transform")
	a.hide();a.appearance=null;sonar.refresh_geometry();check(sonar.geometry.size()==1,"hidden/null paint preserves sonar as legacy")
	parent.remove_child(a);sonar.refresh_geometry();check(sonar.geometry.is_empty(),"detached marker leaves no geometry")
	a.appearance=Appearance.new();a.appearance.label="TRADE";parent.add_child(a);sonar.refresh_geometry()
	check(sonar.geometry.size()==1 and a.get_node("View").appearance.label=="TRADE","reattachment restores contour and current state")
	a.show()
	var pack:=PackedScene.new();check(pack.pack(a)==OK,"configured marker packs")
	check(ResourceSaver.save(pack,"user://exchange_station_roundtrip.tscn")==OK,"configured marker saves")
	var restored=load("user://exchange_station_roundtrip.tscn").instantiate();world.add_child(restored)
	check(restored.appearance.label=="TRADE" and restored.raster_reference==a.raster_reference and restored.transform==a.transform,"state/placement/reference survive serialization")
	check(restored.appearance!=a.appearance and restored.get_node("StationContour/Shape").shape!=a.get_node("StationContour/Shape").shape,"serialized instance resources isolated")
	a.get_node("View").free();a.appearance=Appearance.new();sonar.refresh_geometry();check(sonar.geometry.size()==1,"removed optional view preserves actual contour")
	a.free();sonar.refresh_geometry();check(sonar.geometry.is_empty(),"deleted contour cannot ghost");sonar.free()
	world.free()
	await passage_test()
	await mission_test()
	var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"production_markers":count,"scope":"Geometry/state/sonar tests and direct-state mission contract fixtures; not input-driven routes."}
	FileAccess.open("res://simulation/evidence/exchange_station_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("EXCHANGE STATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func passage_test() -> void:
	var world:=Node2D.new();root.add_child(world)
	var marker=Marker.instantiate();world.add_child(marker)
	var actor=preload("res://combat_pc/player.tscn").instantiate()
	actor.automatic_physics=false;world.add_child(actor)
	actor.position=Vector2(-80,-21)
	await physics_frame
	var hit=actor.move_and_collide(Vector2(160,0))
	check(hit==null and actor.position.is_equal_approx(Vector2(80,-21)),"real shared actor crosses enabled station without blocking")
	var cargo:=RigidBody2D.new();cargo.gravity_scale=0;cargo.collision_layer=8;cargo.collision_mask=1
	var shape:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(12,12);shape.shape=box;cargo.add_child(shape)
	cargo.position=Vector2(-80,-21);cargo.linear_velocity=Vector2(160,0);world.add_child(cargo)
	for frame in range(hz): await physics_frame
	check(cargo.position.x>40,"real solver-driven rigid cargo crosses enabled contour")
	world.free()
func mission_test() -> void:
	var host=load("res://demo/mission.tscn").instantiate();root.add_child(host);host.save_enabled=false;host.start_new(true)
	host.set_process(false);host.set_physics_process(false)
	for sector in [2,5]:
		host.blind=false;host.load_sector(sector)
		var at:Vector2=host.sectors[sector].station
		for distance in [45.01,45.0,44.99]:
			host.player.reset_actor(at+Vector2(-distance,0),1);host.interact()
			check((host.state=="choice")==(distance<45),"station strict E boundary preserved")
			if host.state=="choice":host.choose_sight(false)
		host.player.reset_actor(at,1);check(host.state=="playing" and not host.blind,"proximity alone cannot force trade")
		host.interact();check(host.state=="choice" and paused,"E opens explicit paused choice")
		host.choose_sight(false);check(not host.blind and not paused and host.state=="playing","refusal retains sight and resumes")
		var base:float=host.player.profile.run_speed
		var rolls:Array=[host.player.combat_profile.roll_start_speed,host.player.combat_profile.roll_end_speed,host.player.combat_profile.roll_exit_speed_limit]
		host.interact();host.sonar.clear_pulses();host.choose_sight(true)
		check(host.blind and host.sonar.blind and not paused and host.health.current_health==60,"acceptance activates blackout and restores health")
		check(is_equal_approx(host.player.profile.run_speed,base*1.25),"exact nonstacking 25 percent speed")
		check(is_equal_approx(host.player.combat_profile.roll_start_speed,rolls[0]*1.25) and is_equal_approx(host.player.combat_profile.roll_end_speed,rolls[1]*1.25) and is_equal_approx(host.player.combat_profile.roll_exit_speed_limit,rolls[2]*1.25),"exact 25 percent roll tuning")
		check(host.sonar.pulses.size()==1 and host.sonar.pulses[0].origin.is_equal_approx(host.player.global_position-Vector2(0,16)) and host.sonar.pulses[0].source_id==host.player.get_instance_id(),"accepted trade noise retains actual player origin")
		host.interact();check(host.state!="choice" and is_equal_approx(host.player.profile.run_speed,base*1.25),"already blind cannot repeat station trade")
		host.load_sector(sector);check(host.blind and is_equal_approx(host.player.profile.run_speed,base*1.25),"reload retains trade without stacking")
	host.start_new(true);check(not host.blind,"new run clears sight trade")
	paused=false;host.free();await process_frame
