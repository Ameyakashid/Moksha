extends SceneTree
const Adapter=preload("res://campaign/presentation/object_presentation.gd")
var failures: Array[String]=[]
var checks:=0
func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var room:=Node2D.new();root.add_child(room)
	var cargo=load("res://simulation/world/mission_cargo.tscn").instantiate();room.add_child(cargo)
	cargo.freeze=true
	var ladder=load("res://simulation/world/mission_ladder.tscn").instantiate();ladder.position=Vector2(200,300);ladder.height=180;room.add_child(ladder)
	var station=load("res://simulation/world/exchange_station.tscn").instantiate();room.add_child(station)
	var station_shape=station.get_node("StationContour/Shape").shape
	var collision=cargo.get_node("CollisionShape2D").shape
	var transform:Transform2D=cargo.get_node("Sprite").transform
	var sensor=ladder.get_node("SensorShape").shape
	var original_geometry:Dictionary=ladder.climb_geometry()
	var adapter:=Node.new();adapter.set_script(Adapter);room.add_child(adapter);adapter.bind(room)
	await process_frame
	check(adapter.records.size()==3,"recognizes exact physical cargo and ladder")
	check(cargo.get_node("Sprite").visible and cargo.self_modulate.a==0,"original textured sprite replaces root blueprint")
	check(cargo.get_node("Sprite").transform==transform,"preserves original sprite alignment")
	check(cargo.get_node("CollisionShape2D").shape==collision,"identical cargo collider resource")
	check(ladder.get_node("SensorShape").shape==sensor and ladder.climb_geometry()==original_geometry,"identical climb sensor and contact geometry")
	check(not station.get_node("View").visible and station.get_node("CampaignStationSkin").visible,"textured terminal replaces blueprint")
	check(station.get_node("StationContour/Shape").shape==station_shape and station_shape.size==Vector2(32,42),"station original contour resource/bounds unchanged")
	var skin=ladder.get_node("CampaignLadderSkin")
	var paint:Dictionary=skin.paint_geometry()
	check(paint.rails==PackedVector2Array([Vector2(-6,0),Vector2(-6,-180),Vector2(6,0),Vector2(6,-180)]),"rails exact original endpoints")
	check(paint.rungs[0]==Vector2(-6,-4) and paint.rungs[2]==Vector2(-6,-16),"same climb rung phase and spacing")
	cargo.charge=1.0
	await physics_frame;await process_frame
	check(cargo.get_node("Sprite").self_modulate==Color(1.2,1.1,.9),"real inherited charge tint preserved")
	adapter.set_sight_enabled(false)
	check(not cargo.get_node("Sprite").visible and cargo.self_modulate.a==0,"no textured or debug cargo paint when blind")
	check(not skin.visible and not ladder.draw_guide,"no ladder paint when blind")
	check(not station.get_node("View").visible and not station.get_node("CampaignStationSkin").visible,"no station material/label leak while blind")
	check(ladder.get_node("SonarRails").collision_layer==0 and ladder.climb_geometry()==original_geometry,"sonar contour and climb geometry remain")
	var spawned=load("res://simulation/world/mission_cargo.tscn").instantiate();room.add_child(spawned);spawned.freeze=true
	await process_frame;await process_frame
	check(adapter.records.size()==4 and not spawned.get_node("Sprite").visible,"replacement cargo automatically registered and blind")
	adapter.set_sight_enabled(true);adapter.set_debug_wireframe(true)
	check(not cargo.get_node("Sprite").visible and cargo.self_modulate.a==1 and ladder.draw_guide and not skin.visible,"F8 restores original debug paint")
	adapter.set_debug_wireframe(false)
	check(cargo.get_node("Sprite").visible and skin.visible,"styled paint reselected")
	adapter.clear()
	check(station.get_node("View").visible,"station original view restored on detach")
	check(cargo.self_modulate.a==1 and not cargo.get_node("Sprite").visible and ladder.draw_guide,"detach restores original settings")
	room.queue_free();await process_frame
	if failures.is_empty():print("OBJECT_SKIN_CONTRACT_PASS: ",checks," checks")
	else:for failure in failures:push_error(failure)
	quit(0 if failures.is_empty() else 1)
