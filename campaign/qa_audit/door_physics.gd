extends SceneTree
class Host extends Node:
	var enabled:=false
	var sonar:Node
	func goal_done(_id:String)->bool:return enabled
var host:Host
var probe:CharacterBody2D
var door:StaticBody2D
var frame:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	host=Host.new();root.add_child(host)
	door=load("res://campaign/logic/objective_door.tscn").instantiate();door.position=Vector2(200,200);door.door_size=Vector2(24,200);door.required_ids.assign(["power"]);door.host=host;root.add_child(door)
	probe=CharacterBody2D.new();probe.position=Vector2(100,200);probe.collision_layer=2;probe.collision_mask=1
	var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(20,40);shape.shape=rect;probe.add_child(shape);root.add_child(probe)
func _physics_process(_dt:float)->bool:
	frame+=1
	probe.velocity=Vector2(180 if frame<125 else -180,0);probe.move_and_slide()
	if frame==60:
		check(probe.position.x<179,"closed objective door physically obstructs moving body")
		host.enabled=true
	if frame==120:
		check(probe.position.x>240 and door.opened,"completed dependency opens physically passable door")
		host.enabled=false
	if frame==180:
		check(probe.position.x>221 and not door.opened,"unset route closes door and obstructs return")
		host.enabled=true
	if frame==240:
		check(probe.position.x<180,"restored route reopens physical return")
		print("DOOR_FAILURES "+JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
	return false
