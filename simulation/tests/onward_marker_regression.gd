extends SceneTree
const CampaignIdentity=preload("res://demo/tests/campaign_identity.gd")
const Marker = preload("res://simulation/world/onward_marker.tscn")
const Appearance = preload("res://demo/views/onward_marker_appearance.gd")
const Support = preload("res://simulation/tests/onward_marker_support.gd")
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
		var m=fresh.onward_marker;count+=1
		check(m.position==Vector2(float(data.width)-45,float(data.get("gate_y",300))) and m.raster_reference==m.position and m.ending==data.get("ending",false),"authored marker placement/reference/ending")
		check(m.show_behind_parent and fresh.get_child(fresh.get_child_count()-1)==m,"foreground paint and contour traversal insertion order")
		for value in [true,false,true]:
			old.gate_open=value;fresh.gate_open=value
			check(m.is_open==value and m.get_node("View").is_open==value,"synchronous host state forwarding")
			check(Support.topology(old,[])==Support.topology(fresh,[]) and Support.contours(old)==Support.contours(fresh),"state cannot change physics or sonar geometry")
		var sa=sonar_for(old);var sb=sonar_for(fresh)
		var origin: Vector2=m.position+Vector2(-60,-38)
		sa._on_noise_emitted(origin,&"weapon_tap",1.0,old);sb._on_noise_emitted(origin,&"weapon_tap",1.0,fresh)
		check(sa.accepted_event_count==1 and sb.accepted_event_count==1,"actual scoped production sonar admits source")
		for frame in range(hz*3):
			sa.advance_simulation(1.0/hz);sb.advance_simulation(1.0/hz)
			check(alphas(sa)==alphas(sb),"actual contour pulse timing/alpha parity")
		check(sa.pulses.is_empty() and sb.pulses.is_empty(),"real pulses expire")
		sa.free();sb.free();world.free()
	check(count==9,"all nine production onward markers extracted")
	var world:=Node2D.new();root.add_child(world)
	var a=Marker.instantiate();var b=Marker.instantiate();a.is_open=true;a.ending=true
	world.add_child(a);world.add_child(b)
	check(a.get_node("View").is_open and a.get_node("View").ending,"explicit state before tree entry")
	check(a.appearance!=b.appearance and a.get_node("GateContour/Shape").shape!=b.get_node("GateContour/Shape").shape,"per-instance appearance and shape resources")
	var original:=Support.contours(a)
	a.appearance.closed_ink=Color.RED;a.appearance.onward_label="EXIT";a.is_open=false;a.ending=false
	check(b.appearance.closed_ink==Color("cd946a") and b.appearance.onward_label=="ONWARD" and not b.is_open,"paint and state edits isolated")
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
	check(a.get_node("GateContour").global_transform.is_equal_approx(a.global_transform*Transform2D(0,Vector2(0,-38))),"contour follows native composed transform")
	var sonar=sonar_for(parent)
	check(sonar.geometry.size()==1 and not sonar.geometry[0].dynamic,"real static contour survives nested transform")
	a.hide();a.appearance=null;sonar.refresh_geometry();check(sonar.geometry.size()==1,"hidden/null paint preserves sonar as legacy")
	parent.remove_child(a);sonar.refresh_geometry();check(sonar.geometry.is_empty(),"detached marker leaves no geometry")
	a.is_open=true;a.ending=true;parent.add_child(a);sonar.refresh_geometry()
	check(sonar.geometry.size()==1 and a.get_node("View").is_open and a.get_node("View").ending,"reattachment restores contour and current state")
	a.show();a.appearance=Appearance.new()
	var pack:=PackedScene.new();check(pack.pack(a)==OK,"configured marker packs")
	check(ResourceSaver.save(pack,"user://onward_marker_roundtrip.tscn")==OK,"configured marker saves")
	var restored=load("user://onward_marker_roundtrip.tscn").instantiate();world.add_child(restored)
	check(restored.is_open and restored.ending and restored.raster_reference==a.raster_reference and restored.transform==a.transform,"state/placement/reference survive serialization")
	check(restored.appearance!=a.appearance and restored.get_node("GateContour/Shape").shape!=a.get_node("GateContour/Shape").shape,"serialized instance resources isolated")
	a.free();sonar.refresh_geometry();check(sonar.geometry.is_empty(),"deleted contour cannot ghost");sonar.free()
	world.free()
	await passage_test()
	await mission_test()
	var report={"hz":hz,"checks":checks,"failures":failures,"passed":failures.is_empty(),"production_markers":count,"scope":"Geometry/state/sonar tests and direct-state mission contract fixtures; not input-driven routes."}
	FileAccess.open("res://simulation/evidence/onward_marker_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("ONWARD MARKER ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
func passage_test() -> void:
	var world:=Node2D.new();root.add_child(world)
	var marker=Marker.instantiate();world.add_child(marker)
	var actor:=CharacterBody2D.new();actor.collision_layer=1;actor.collision_mask=0xffffffff
	var collider:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(8,16);collider.shape=shape;actor.add_child(collider);world.add_child(actor)
	for state in [false,true]:
		marker.is_open=state;actor.position=Vector2(-80,-38)
		await physics_frame
		var hit:=actor.move_and_collide(Vector2(160,0))
		check(hit==null and actor.position.is_equal_approx(Vector2(80,-38)),"real actor crosses both closed/open indicator without collision")
	world.free()
func mission_test() -> void:
	var host=load("res://demo/mission.tscn").instantiate();root.add_child(host);host.save_enabled=false;host.start_new(true)
	host.set_process(false);host.set_physics_process(false)
	var gate:=Vector2(float(host.sectors[0].width)-45,float(host.sectors[0].get("gate_y",300)))
	host.player.reset_actor(gate,1);host.interact()
	check(host._pending_sector==-1 and not host.room.onward_marker.is_open,"closed E does not advance")
	host.player.reset_actor(host.sectors[0].relay,1);host.interact()
	check(host.room.gate_open and host.room.onward_marker.is_open,"actual relay objective publishes presentation state")
	for distance in [65.0,65.01,64.99]:
		host.player.reset_actor(gate+Vector2(-distance,0),1);host.interact()
		check((host._pending_sector==1)==(distance<65),"strict E distance boundary retained")
	host.load_sector(0);check(not host.room.onward_marker.is_open,"retry rebuild resets objective input")
	host.load_sector(CampaignIdentity.index(host.sectors,"above_the_rain"));gate=Vector2(float(host.sectors[host.sector].width)-45,float(host.sectors[host.sector].get("gate_y",300)))
	check(host.room.onward_marker.ending and host.room.onward_marker.is_open,"ending marker is LIFT and receives host objective")
	host.player.reset_actor(gate,1);check(host.state=="playing","position at LIFT cannot auto-complete")
	host.interact();check(host.state=="complete" and paused,"only host E interaction completes ending")
	paused=false;host.free();await process_frame
