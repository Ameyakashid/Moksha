extends "res://campaign/quality/intellect_tactical/contract.gd"
## Seeded listener-policy contract, not earned/native or measured audibility.
func stage(deaf:=false)->void:
	enemy.reset_actor(Vector2(260,300),-1);host.player.reset_actor(Vector2(180,300),1)
	host.camera.position=Vector2(320,180);host.camera.force_update_scroll()
	host.state="playing";host.blind=true;host.hearing_retained=not deaf;host._apply_senses()
	host.notice_left=0;host.chapter_left=0;host._pending_sector=-1;host._pending_retry=false
	observer.enabled=true;observer.bind_room()
func run()->void:
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true)
	for i in host.sectors.size():
		if host.sectors[i].id=="l3_drainage_commons":host.load_sector(i);break
	host.set_physics_process(false)
	for e in host.enemies:
		e.get_node("IntentDriver").automatic_driver=false
		if e.kind=="captain_lancer":enemy=e
	observer=host.tactical_companion
	driver=Driver.new();driver.process_physics_priority=90;root.add_child(driver)
	stage();await tick();await tick(attack)
	check(snapshot().get("notice","")=="Be ready.","actual committed weapon draw admits blind caution")
	var fact:Dictionary=observer._heard_fact.duplicate()
	check(fact.keys().size()==4 and fact.get("modality")=="hearing" and fact.get("category")=="weapon_draw_heard","stripped four-field fact")
	check(not observer._heard_seen,"query not acknowledgment")
	host.hud.set_snapshot(snapshot());check(observer._heard_seen,"typed notice acknowledgment")
	await tick(func():enemy._advance_melee(1.5))
	check(snapshot().get("notice","")!="An opening.","no hidden recovery inference")
	for i in range(hz):await tick()
	check(observer._heard_fact.is_empty(),"finite age expires")
	for mode in ["deaf","sighted","muted","pause","reset","player_reset","disabled","session","modal"]:
		stage();await tick()
		if mode=="deaf":host.hearing_retained=false;host._apply_senses()
		if mode=="sighted":host.blind=false;host._apply_senses()
		if mode=="muted":host.audio.muted=true
		await tick(attack)
		if mode in ["deaf","sighted"]:
			check(observer._heard_fact.is_empty(),mode+" rejects")
			continue
		check(not observer._heard_fact.is_empty(),mode+" initial admission")
		match mode:
			"pause":host.state="paused"
			"reset":enemy.reset_actor(enemy.position)
			"player_reset":host.player.reset_actor(host.player.position)
			"disabled":observer.enabled=false
			"session":host.session_generation+=1
			"modal":
				var s:Dictionary={"state":"playing","chapter_visible":true};observer.decorate(s)
		if mode=="muted":check(snapshot().get("notice","")=="Be ready.","mute independent of sense");host.audio.muted=false
		else:check(not snapshot().get("notice_visible",false),mode+" retires")
	stage();await tick()
	var relay:Node=enemy.get_node("NoiseRelay")
	var fake:Dictionary={"actor_id":enemy.get_instance_id(),"generation":enemy.noise_generation(),"serial":90000,"origin":Vector2(260,274),"kind":&"enemy_windup","loudness":.8};fake.make_read_only()
	await tick(func():relay.forwarded.emit(fake))
	check(observer._heard_fact.is_empty(),"manual forwarded outside scope rejected")
	await tick(func():host.bus.emit_noise(Vector2(260,274),&"enemy_windup",.8,enemy))
	check(observer._heard_fact.is_empty(),"raw bus injection rejected")
	var wall:=StaticBody2D.new();wall.position=Vector2(220,270);var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(12,100);shape.shape=rect;wall.add_child(shape);host.room.add_child(wall)
	await tick();await tick(attack);check(observer._heard_fact.is_empty(),"terrain blocks caption");wall.free()
	stage();await tick();await tick(attack);host.hearing_retained=false;host._apply_senses();host.hearing_retained=true;host._apply_senses()
	check(observer._heard_fact.is_empty(),"hearing regain never replays")
	for distance in [271.9,272.0,272.1]:
		stage();host.player.reset_actor(Vector2(180,120));await tick()
		await tick(func():enemy._commit_noise(Vector2(180+distance,100),&"enemy_windup",.8,enemy.noise_generation()))
		check(not observer._heard_fact.is_empty()==(distance<=272.0),"ear boundary "+str(distance))
	for distance in [259.9,260.0,260.1]:
		stage();host.player.reset_actor(Vector2(500,200));await tick()
		await tick(func():enemy._commit_noise(Vector2(320+distance,180),&"enemy_windup",.8,enemy.noise_generation()))
		check(not observer._heard_fact.is_empty()==(distance<=260.0),"view boundary "+str(distance))
	stage();await tick()
	var replaying: Array[bool]=[false]
	var replay:Callable=func(event:Dictionary):
		if replaying[0]:return
		replaying[0]=true
		var before:Dictionary=observer._heard_fact.duplicate()
		relay.forwarded.emit(event)
		check(observer._heard_fact==before,"identical reentrant replay idempotent")
	relay.forwarded.connect(replay)
	await tick(attack);relay.forwarded.disconnect(replay)
	var original:Dictionary=observer._heard_fact.duplicate()
	enemy.position=Vector2(1000,100);enemy.facing=1
	check(observer._heard_fact==original and snapshot().get("notice","")=="Be ready.","hidden motion cannot enrich frozen heard fact")
	stage();await tick();await tick(attack)
	var admitted:Dictionary=snapshot()
	host.hud.companion_presentation_accepted.connect(func(_id:String,_blocked:bool):
		var replaced:Dictionary=admitted.duplicate();replaced.chapter_visible=true;host.hud.set_snapshot(replaced),CONNECT_ONE_SHOT)
	host.hud.set_snapshot(admitted)
	check(not observer._heard_seen,"nested same-ID priority replacement cannot acknowledge")
	for mode in ["hearing","enabled","player","source"]:
		stage();await tick()
		var invalidate:Callable=func(_origin:Vector2,_kind:StringName,_volume:float,_source:Node):
			match mode:
				"hearing":
					host.hearing_retained=false;host._apply_senses();host.hearing_retained=true;host._apply_senses()
				"enabled":observer.enabled=false;observer.enabled=true
				"player":host.player.reset_actor(host.player.position)
				"source":enemy.reset_actor(enemy.position)
		host.bus.noise_emitted.connect(invalidate,CONNECT_ONE_SHOT)
		await tick(attack)
		check(observer._heard_fact.is_empty(),"nested loss/regain rejects in-flight "+mode)
	stage();await tick()
	await tick(func():
		for i in 1000:enemy._commit_noise(Vector2(2000,100),&"enemy_windup",.8,enemy.noise_generation()))
	check(observer._heard_receipts.size()<=64 and observer._heard_fact.is_empty(),"many rejected events use bounded frame cache")
	await tick(attack);check(snapshot().get("notice","")=="Be ready.","next-frame fresh receipt survives bounded overflow")
	host.hud.set_snapshot(snapshot())
	var budget_size:int=observer._heard_receipts.size()
	await tick(func():
		for i in 1000:enemy._commit_noise(Vector2(260,274),&"enemy_windup",.8,enemy.noise_generation()))
	check(observer._heard_receipts.size()==budget_size,"exhausted shown budget adds no history")
	stage();await tick();await tick(attack)
	var explicit_listener:=AudioListener2D.new();host.add_child(explicit_listener);explicit_listener.make_current()
	check(not snapshot().get("notice_visible",false),"unexpected explicit audio listener fails closed")
	explicit_listener.clear_current();explicit_listener.free()
	stage();await tick();await tick(attack)
	var saved_audio:Node=host.audio;host.audio=Node.new();host.add_child(host.audio)
	check(not snapshot().get("notice_visible",false),"unsupported audio adapter fails closed without property errors")
	host.audio.free();host.audio=saved_audio
	stage();await tick();await tick(attack)
	var intervening:=StaticBody2D.new();intervening.position=Vector2(220,270)
	var collider:=CollisionShape2D.new();var box:=RectangleShape2D.new();box.size=Vector2(12,100);collider.shape=box;intervening.add_child(collider);host.room.add_child(intervening)
	await tick();await tick()
	check(observer._heard_fact.is_empty(),"new terrain retires existing evidence at physics recheck")
	intervening.free()
	for owner_kind in ["actor","player"]:
		stage();await tick();await tick(attack)
		var owner:Node=enemy if owner_kind=="actor" else host.player
		var original_parent:Node=owner.get_parent()
		original_parent.remove_child(owner);original_parent.add_child(owner)
		check(observer._heard_fact.is_empty(),"remove and readd cannot retain "+owner_kind+" fact")
	stage();await tick();await tick(attack)
	var original_player:Node=host.player
	var replacement:Node=host.enemies[0]
	# Compatible existing actor, with no reset/removal to trigger lifecycle hooks.
	# Temporarily align only the observer's comparison generation to isolate identity.
	observer._player_generation=replacement.noise_generation()
	observer._listener_generation=replacement.noise_generation()
	host.player=replacement
	check(not observer._heard_live() and not snapshot().get("notice_visible",false) and observer._heard_fact.is_empty(),"replacement actor cannot inherit bound listener fact")
	host.player=original_player
	print("HEARD_CONTRACT "+JSON.stringify({"checks":checks,"failures":failures,"hz":hz,"scope":"seeded"}))
	host.free();driver.free();await process_frame;quit(0 if failures.is_empty() else 1)
