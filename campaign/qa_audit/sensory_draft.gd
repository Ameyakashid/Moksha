extends SceneTree
var fails:Array[String]=[]
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	call_deferred("run")
func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:fails.append(label)
func run()->void:
	var m=load("res://campaign/campaign.tscn").instantiate();m.save_enabled=false;root.add_child(m);m.start_new(true)
	for i in m.sectors.size():
		if m.sectors[i].has("station"):
			m.load_sector(i);m.player.position=m.sectors[i].station;m.interact();m.choose_sight(true);break
	check(m.blind,"real station choice activated from controlled placement")
	for i in m.sectors.size():
		m.load_sector(i);m._physics_process(0.0);m.sonar.refresh_geometry()
		check(m.sonar.blind and not m.art.visible,m.sectors[i].id+" blackout state/paint")
		for g in m.goals:
			var tracked:=false
			for record in m.sonar.geometry:
				var anchor:Node=record.anchor.get_ref()
				if is_instance_valid(anchor) and g.is_ancestor_of(anchor):tracked=true
			check(tracked,m.sectors[i].id+" sonar geometry "+g.objective_id)
			check(not g.get_node("Presentation").visible,m.sectors[i].id+" hidden objective paint "+g.objective_id)
		for h in m.room.get_children():
			if h.get_script()!=load("res://campaign/logic/hazard.gd"):continue
			m.bus.clear_history();h.clock=h.period-0.4-h.phase;h._physics_process(0.01)
			check(h.warning and m.bus.event_history.any(func(e):return e.source_id==h.get_instance_id() and e.kind==&"enemy_windup"),m.sectors[i].id+" real hazard warning event")
			check(m.sonar.event_history.any(func(e):return e.get("kind")==&"enemy_windup"),m.sectors[i].id+" warning accepted by sonar")
	print("SENSORY_FAILURES "+JSON.stringify(fails));quit(0 if fails.is_empty() else 1)
