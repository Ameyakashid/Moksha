extends SceneTree
var fails:Array[String]=[]
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	call_deferred("run")
func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:fails.append(label)
func key(m:Node,k:int)->void:
	var e:=InputEventKey.new();e.physical_keycode=k;e.pressed=true;m._unhandled_key_input(e)
func run()->void:
	var m=load("res://campaign/campaign.tscn").instantiate();m.save_enabled=false;root.add_child(m);m.start_new(true)
	for i in 3:
		key(m,KEY_TAB);check(m.state=="journal" and paused,"journal opens paused "+str(i))
		var elapsed:float=m.elapsed;var at:Vector2=m.player.position
		m.input_override={"right":true,"attack":true};m._physics_process(0.25);key(m,KEY_E)
		check(m.state=="journal" and m.elapsed==elapsed and m.player.position==at,"journal blocks combat/interaction/movement/clock "+str(i))
		key(m,KEY_ESCAPE);check(m.state=="playing" and not paused,"journal Escape restores play "+str(i))
	key(m,KEY_ESCAPE);check(m.state=="paused" and paused,"Escape pause")
	key(m,KEY_R);m._physics_process(0.0);check(m.state=="playing" and not paused,"paused retry restarts playable checkpoint")
	m.input_override={}
	var route=load("res://campaign/logic/objective.tscn").instantiate();route.configure({"id":"qa_route","label":"qa route","kind":"route","target":0,"at":Vector2(100,300)},m);m.room.add_child(route);route.changed.connect(m._goal_changed.bind(route))
	check(route.setting==-1 and not route.completed,"route starts explicitly unrouted")
	route.interact();check(route.completed and m.goal_done("qa_route"),"target zero activates on first choice")
	var install=load("res://campaign/logic/objective.tscn").instantiate();install.configure({"id":"qa_install","label":"qa install","kind":"install","at":Vector2(150,300),"requires":["qa_route"]},m);m.room.add_child(install);install.changed.connect(m._goal_changed.bind(install));install.interact()
	check(install.completed,"dependent install accepts powered route")
	route.interact();check(not route.completed and not m.goal_done("qa_route"),"route can be unset after install")
	check(install.completed and m.goal_done("qa_install"),"installed result intentionally latches after route unset")
	print("UI_DEPENDENCY_FAILURES "+JSON.stringify(fails));quit(0 if fails.is_empty() else 1)
