extends SceneTree
## Seeded entry then ordinary controller inputs; real campaign AI remains enabled.
class Driver extends Node:
	var test: SceneTree
	func _physics_process(dt: float) -> void: test.tick(dt)
var host: Node
var actor: Node
var district := "l3_refuge_terraces"
var lens := "retained"
var build := "neutral"
var route := "ground"
var hz := 60
var output := ""
var linger := 0.0
var enemy_irritant_hears := 0
var elapsed := 0.0
var stage := 0
var finished := false
var jump_started := -100.0
var field: Node
var coughs := 0
var was_cough := false
var cue_seen := false
var samples: Array = []
var settings: Dictionary
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--district="): district=arg.trim_prefix("--district=")
		if arg.begins_with("--build="): build=arg.trim_prefix("--build=")
		if arg.begins_with("--lens="): lens=arg.trim_prefix("--lens=")
		if arg.begins_with("--route="): route=arg.trim_prefix("--route=")
		if arg.begins_with("--hz="): hz=int(arg.trim_prefix("--hz="))
		if arg.begins_with("--linger="): linger=float(arg.trim_prefix("--linger="))
		if arg.begins_with("--output="): output=arg.trim_prefix("--output=")
	Engine.physics_ticks_per_second=hz;setup.call_deferred()
func setup() -> void:
	settings={"l3_refuge_terraces":{"ladder":820.0,"top":190.0,"jump":1060.0,"end":1370.0,"center":1150.0,"return_jump":1255.0,"end_top":130.0},"works_baffle_hall":{"ladder":510.0,"top":80.0,"jump":945.0,"end":1320.0,"center":1200.0,"return_jump":1095.0,"end_top":80.0},"crown_manual_governor":{"ladder":4540.0,"top":80.0,"jump":4700.0,"end":4960.0,"center":4740.0,"return_jump":4860.0,"end_top":135.0}}[district]
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host)
	host.start_new(true)
	host.lens=build
	host.blind=lens=="blind";host.hearing_retained=lens!="deaf"
	for i in host.sectors.size():
		if host.sectors[i].id==district:host.load_sector(i);break
	host.set_physics_process(false);host.blind=lens=="blind";host.hearing_retained=lens!="deaf";host._apply_senses();host.sonar.set_blind(host.blind)
	actor=host.player;actor.automatic_physics=false
	actor.reset_actor(Vector2(settings.ladder-50 if route=="bypass" else settings.center-260,300),1)
	if district=="crown_manual_governor" and route=="ground":actor.reset_actor(Vector2(4540,300),1)
	if route=="return":actor.reset_actor(Vector2(settings.end,settings.end_top),-1)
	for enemy in host.enemies:
		var sensor=enemy.get_node_or_null("HearingSensor")
		if sensor!=null:sensor.heard.connect(func(receipt):
			if receipt.get("kind",&"") in [&"irritant_warning",&"irritant_hiss"]:enemy_irritant_hears+=1)
	field=host.irritant_dispersers[0]
	var driver:=Driver.new();driver.test=self;host.add_child(driver)
func tick(dt: float) -> void:
	if finished:return
	elapsed+=dt
	var input:Dictionary={}
	if elapsed<linger or (district=="crown_manual_governor" and route=="ground" and elapsed<.6):pass
	elif route=="return":
		if stage==0:
			input={"left":true}
			if actor.position.x<=settings.return_jump:input.jump=true;jump_started=elapsed;stage=1
		elif stage==1:
			input={"left":true,"jump":elapsed-jump_started<.35}
			if actor.position.x<=settings.ladder+2:stage=2
		elif stage==2:
			input={"down":true}
			if actor.main_action!=&"climb" and (actor.position.y>=299.9 or (district=="crown_manual_governor" and actor.position.y>settings.top+40)):stage=3
		else:input={"left":true}
	elif route=="bypass":
		if stage==0:
			if actor.position.x<settings.ladder-2:input={"right":true}
			else:stage=1
		elif stage==1:
			input={"up":true}
			if actor.position.y<=settings.top+.05 and actor.main_action!=&"climb":stage=2
		elif stage==2:
			input={"right":true}
			if actor.position.x>=settings.jump:input.jump=true;jump_started=elapsed;stage=3
		else:input={"right":true,"jump":elapsed-jump_started<.35}
	else:input={"right":true,"attack":int(elapsed*4)%2==0}
	actor.physics_tick(dt,input)
	host.camera.position=host.camera_follow.step(actor.global_position,host.sectors[host.sector],dt) if host.camera_follow.has_method("step") else actor.global_position
	var snap:Dictionary=actor.irritant_snapshot()
	if snap.coughing and not was_cough:coughs+=1
	was_cough=snap.coughing;cue_seen=cue_seen or not host.cough_feedback.snapshot().is_empty()
	var nearest:=100000.0
	for enemy in host.enemies:
		if is_instance_valid(enemy) and not enemy.dead:nearest=minf(nearest,enemy.global_position.distance_to(actor.global_position))
	samples.append({"at":[actor.position.x,actor.position.y],"cough":snap.coughing,"hp":host.health.current_health,"nearest_enemy":nearest,"phase":String(field.phase),"action":String(actor.main_action)})
	var reached:bool=actor.position.x<settings.ladder-(25 if district=="crown_manual_governor" else 45) and stage==3 if route=="return" else actor.position.x>settings.end
	if reached or elapsed>18+linger or actor.is_defeated():
		finished=true
		var passed:bool=reached and not actor.is_defeated() and (coughs==0 if route in ["bypass","return"] else true)
		var result={"passed":passed,"district":district,"lens":lens,"build":build,"route":route,"hz":hz,"seconds":elapsed,"coughs":coughs,"cue_seen":cue_seen,"hp":host.health.current_health,"stage":stage,"enemy_irritant_hears":enemy_irritant_hears,"linger":linger,"samples":samples,"scope":"Seeded local entry; ordinary input thereafter, real enabled enemy AI; not full district completion or human play"}
		if not output.is_empty():var f:=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify(result));f.close()
		result.erase("samples");print(JSON.stringify(result));finish.call_deferred(passed)
func finish(passed:bool)->void:
	host.queue_free();paused=false;await process_frame;await process_frame;quit(0 if passed else 1)
