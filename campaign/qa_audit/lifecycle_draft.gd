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
	var m=load("res://campaign/campaign.tscn").instantiate();m.save_enabled=false;root.add_child(m);m.start_new(true);paused=true
	var base:float=load("res://combat_pc/resources/responsive_chain.tres").steps[0].damage
	m.lens="strength";m._apply_build()
	check(is_equal_approx(base,load("res://combat_pc/resources/responsive_chain.tres").steps[0].damage),"strength leaves shared strike resource immutable")
	var clinic:=0
	for i in m.sectors.size():
		if m.sectors[i].id=="city_clinic":clinic=i
	m.load_sector(clinic);paused=true
	var reward:Node
	for g in m.goals:
		if g.objective_id=="medic":reward=g
	reward.interact();var count:int=m.rewards.size();var capacity:float=m.health.capacity
	m._goal_changed(reward);check(m.rewards.size()==count,"duplicate objective notification cannot repeat reward")
	m.load_sector(clinic);paused=true
	for g in m.goals:
		if g.objective_id=="medic":reward=g
	reward.interact();check(m.rewards.size()==count and is_equal_approx(m.health.capacity,capacity),"retry and re-collect cannot farm vitality")
	var h=load("res://campaign/logic/hazard.tscn").instantiate();h.host=m;m.room.add_child(h)
	for state in ["paused","archive","choice","journal","upgrade","final_choice","complete","dead","title"]:
		m.state=state;var before:float=h.clock;h._physics_process(0.5);check(is_equal_approx(h.clock,before),"hazard clock frozen in "+state)
	m.state="playing";h.position=m.player.position-Vector2(0,12);h.clock=0;h.cooldown=0
	var hp:float=m.health.current_health;h._physics_process(0.1)
	check(m.health.current_health<hp,"hazard real overlap admits damage")
	check(h.cooldown>0,"hazard arms hit cooldown")
	# Per-frame timing observation without invoking player updates.
	m.state="paused";var total:float=m.elapsed;var level_total:Dictionary=m.level_seconds.duplicate(true);m._physics_process(0.25)
	check(is_equal_approx(m.elapsed,total) and m.level_seconds==level_total,"pause freezes campaign and level clocks")
	print("LIFECYCLE_FAILURES "+JSON.stringify(fails));quit(0 if fails.is_empty() else 1)
