extends SceneTree
## Controlled placement/lifecycle and actual station/F8/retry inputs; not route or pixels.
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok:failures.append(label)
func key(m:Node,k:int)->void:
	var e:=InputEventKey.new();e.physical_keycode=k;e.pressed=true;m._unhandled_key_input(e)
func collision_snapshot(m:Node)->Dictionary:
	var result:Dictionary={}
	for node in m.room.find_children("*","CollisionObject2D",true,false):
		result[node.get_instance_id()]=[node.collision_layer,node.collision_mask]
	for node in m.room.find_children("*","CollisionShape2D",true,false):
		result[node.get_instance_id()]=[node.disabled,node.shape.get_instance_id() if node.shape else 0,node.transform]
	return result
func concealed(paint:Node)->bool:
	for record in paint.records:
		var node:Node=record.node.get_ref()
		if not is_instance_valid(node):continue
		if record.kind=="cargo":
			if record.sprite.get_ref().visible or node.self_modulate.a!=0:return false
		else:
			if record.skin.get_ref().visible:return false
			if record.kind=="station" and record.view.get_ref().visible:return false
			if record.kind=="ladder" and node.draw_guide:return false
	return true
func bound(m:Node,label:String)->void:
	check(is_instance_valid(m.object_paint) and m.object_paint.room==m.room,label+" paint bound current room")
	for record in m.object_paint.records:
		check(is_instance_valid(record.node.get_ref()) and m.room.is_ancestor_of(record.node.get_ref()),label+" live owned "+record.kind)
	for goal in m.goals:check(goal.get_node("Presentation").z_index==-1,label+" goal paint under actors "+goal.objective_id)
func run()->void:
	var m=load("res://campaign/campaign.tscn").instantiate();m.save_enabled=false;root.add_child(m);m.start_new(true)
	for i in m.sectors.size():
		var old:WeakRef=weakref(m.object_paint)
		m.load_sector(i);await process_frame
		check(not is_instance_valid(old.get_ref()),m.sectors[i].id+" old paint disposed")
		bound(m,m.sectors[i].id)
		var before:=collision_snapshot(m);var health:Node=m.health;var hp:float=health.current_health
		key(m,KEY_F8);check(m.object_paint.debug_wireframe,"F8 enters debug paint")
		key(m,KEY_F8);check(not m.object_paint.debug_wireframe,"F8 restores material paint")
		check(collision_snapshot(m)==before and m.health==health and m.health.current_health==hp,"F8 preserves collision and Health authority")
	for i in m.sectors.size():
		if not m.sectors[i].has("station"):continue
		m.load_sector(i);m.player.position=m.sectors[i].station;m.interact()
		check(m.state=="choice","actual station enters choice")
		m.choose_sight(true)
		check(m.blind and concealed(m.object_paint),"actual trade conceals all paint synchronously")
		key(m,KEY_F8);check(concealed(m.object_paint),"blind F8 cannot reveal object paint")
		key(m,KEY_F8)
		key(m,KEY_R);m._physics_process(0.0);await process_frame
		bound(m,"blind retry");check(m.blind and concealed(m.object_paint),"retry retains blindness and concealed paint")
		break
	m.start_new(true);await process_frame
	bound(m,"new run");check(not m.blind and m.object_paint.sight_enabled,"new run resets sight and paint")
	print("OBJECT_PAINT_CHECKS ",checks)
	print("OBJECT_PAINT_FAILURES "+JSON.stringify(failures));quit(0 if failures.is_empty() else 1)
