extends SceneTree
## Actual in-flight strike plus live reward/build adapter regression.
var failures:Array[String]=[]
var checks:=0
var host:Node
var baseline_script:=""
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
		if arg.begins_with("--baseline-host="):baseline_script=arg.trim_prefix("--baseline-host=")
	run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:int)->void:
	for index in count:await physics_frame;await process_frame
func augment(id:String,reward:String)->Node:
	var goal=load("res://campaign/logic/objective.tscn").instantiate()
	goal.configure({"id":id,"label":id,"kind":"recover","at":host.player.position,"optional":true,"reward":reward},host)
	host.room.add_child(goal);goal.changed.connect(host._goal_changed.bind(goal));host.goals.append(goal)
	return goal
func run()->void:
	host=load("res://campaign/campaign.tscn").instantiate()
	if not baseline_script.is_empty():host.set_script(load(baseline_script))
	host.save_enabled=false;root.add_child(host);host.start_new(true);host.input_override={}
	for enemy in host.enemies:enemy.queue_free()
	await frames(4)
	var base=load("res://combat_pc/resources/responsive_chain.tres")
	var base_damage:float=base.steps[0].damage
	var initial_capacity:float=host.health.capacity
	for reward in ["vitality","agility"]:
		host.input_override={"attack":true};await frames(1);host.input_override={}
		check(host.player.weapon_phase==&"windup",reward+" fixture begins a real strike")
		var chain:Resource=host.player.melee_chain
		var serial:int=host.player.attack_serial
		var hp:float=host.health.current_health
		var goal:=augment(reward,reward)
		host.interact()
		check(goal.completed and host.player.melee_chain==chain,reward+" pickup leaves unchanged melee resource live")
		check(is_equal_approx(host.health.current_health,hp),reward+" pickup does not heal")
		await frames(3)
		check(host.player.weapon_phase!=&"idle" and host.player.attack_serial==serial,reward+" pickup preserves in-progress strike")
		await frames(Engine.physics_ticks_per_second)
	var force_goal:=augment("force","force")
	host.interact()
	check(force_goal.completed and is_equal_approx(host.player.melee_chain.steps[0].damage,base_damage*1.08),"force pickup applies exactly one additive damage bonus")
	var chain:Resource=host.player.melee_chain
	var speed:float=host.player.profile.run_speed
	for repeat in 5:host._apply_build()
	check(host.player.melee_chain==chain and is_equal_approx(host.player.profile.run_speed,speed),"idempotent reapply does not replace strikes or stack speed")
	check(is_equal_approx(base.steps[0].damage,base_damage),"shared original melee resource stays immutable")
	host.input_override={};host.load_sector(0);await frames(3)
	check(is_equal_approx(host.health.capacity,initial_capacity+5) and is_equal_approx(host.health.current_health,host.health.capacity),"retry preserves capacity augment and restores district health")
	check(is_equal_approx(host.player.profile.run_speed,speed) and is_equal_approx(host.player.melee_chain.steps[0].damage,base_damage*1.08),"retry applies bonuses once to new actor")
	print("NOV6_GAMEPLAY_BUILD_RESULT "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"hz":Engine.physics_ticks_per_second,"failures":failures,"scope":"Live reward interaction and actual shared strike lifecycle; not full combat balance acceptance."}))
	host.free();quit(0 if failures.is_empty() else 1)
