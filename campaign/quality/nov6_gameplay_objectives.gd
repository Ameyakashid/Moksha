extends SceneTree
## Overlapping interaction fixtures and contact-time dependency regression.
## Breaker outcome uses actual J input, production strike contact and health.
var failures:Array[String]=[]
var checks:=0
var host:Node
var route:Node
var breaker:Node
var revoked:=false
var baseline_contact:=""
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
		if arg.begins_with("--baseline-contact="):baseline_contact=arg.trim_prefix("--baseline-contact=")
	run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:int)->void:
	for index in count:await physics_frame;await process_frame
func objective(id:String,kind:String,at:Vector2,requires:Array=[])->Node:
	var goal=load("res://campaign/logic/objective.tscn").instantiate()
	goal.configure({"id":id,"label":id,"kind":kind,"at":at,"target":0,"requires":requires},host)
	host.room.add_child(goal);goal.changed.connect(host._goal_changed.bind(goal));host.goals.append(goal)
	return goal
func revoke_on_active(kind:StringName,payload:Dictionary)->void:
	if not revoked and kind==&"attack_phase_changed" and payload.get("phase")==&"active":
		revoked=true
		route.interact()
		check(breaker.breaker_health.enabled and not host.goal_done("power"),"fixture changes route after cached enabled update and before contact")
func run()->void:
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host)
	host.start_new(true);host.input_override={}
	for enemy in host.enemies:enemy.queue_free()
	await frames(4)
	var farther:=objective("far terminal","terminal",Vector2(120,300))
	var nearer:=objective("near terminal","terminal",Vector2(85,300))
	check(host._hud_snapshot().prompt=="[E] near terminal","prompt chooses closest active objective rather than array order")
	host.interact()
	check(nearer.completed and not farther.completed,"E activates the same closest objective shown in prompt")
	var housing:=objective("locked housing","breaker",Vector2(76,300),["absent"])
	check(host._hud_snapshot().prompt=="[E] far terminal","locked housing does not steal a nearby available terminal")
	host.interact();check(farther.completed,"available terminal can be used beside a locked housing")
	host.interact();check(host.notice=="Requires: absent","blocked interaction names only missing prerequisites")
	for goal in host.goals:goal.queue_free()
	host.goals.clear();await frames(2)
	var outside:=objective("out of reach","terminal",Vector2(130,300))
	check(not "out of reach" in host._hud_snapshot().prompt,"prompt does not advertise E outside its actual radius")
	host.interact();check(not outside.completed,"outside-radius E cannot activate objective")
	outside.queue_free();host.goals.clear();await frames(2)
	route=objective("power","route",Vector2(600,300))
	breaker=objective("housing","breaker",Vector2(110,300),["power"])
	if not baseline_contact.is_empty():breaker.get_node("StrikeContact").set_script(load(baseline_contact))
	route.interact();await frames(3)
	check(breaker.breaker_health.enabled,"powered breaker enables normal strike receiver")
	host.player.movement_event.connect(revoke_on_active)
	host.input_override={"attack":true};await frames(1);host.input_override={}
	await frames(ceili(Engine.physics_ticks_per_second*0.7))
	check(revoked and breaker.breaker_health.resolved_count==0 and not breaker.completed,"same-tick prerequisite revocation rejects real player strike")
	host.player.movement_event.disconnect(revoke_on_active)
	route.interact();route.interact();await frames(3)
	for attempt in 3:
		host.input_override={"attack":true};await frames(1);host.input_override={}
		await frames(ceili(Engine.physics_ticks_per_second*0.75))
	check(breaker.completed and breaker.breaker_health.resolved_count>=1,"restored route permits real strikes and breaker completion")
	var count:int=breaker.breaker_health.resolved_count
	breaker.get_node("StrikeContact").receive_strike({})
	check(breaker.breaker_health.resolved_count==count,"completed housing cannot process further contacts")
	print("NOV6_GAMEPLAY_OBJECTIVES_RESULT "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"hz":Engine.physics_ticks_per_second,"failures":failures,"scope":"Controlled placements and real breaker contacts; not all authored puzzle traversal."}))
	host.free();quit(0 if failures.is_empty() else 1)
