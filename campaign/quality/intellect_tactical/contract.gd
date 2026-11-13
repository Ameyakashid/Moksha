extends SceneTree
## Seeded actual-actor observation contract, not earned or native gameplay.
class Driver extends Node:
	var job:Callable
	var ticks:=0
	func _physics_process(_dt:float)->void:
		if job.is_valid():
			var work:=job;job=Callable();work.call()
		ticks+=1
var host:Node
var enemy:Node
var observer:Node
var driver:Driver
var hz:=60
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second=hz;run.call_deferred()
func tick(job:Callable=Callable())->void:
	var target:=driver.ticks+1;driver.job=job
	while driver.ticks<target:await physics_frame;await process_frame
func stage(deaf:=false)->void:
	enemy.reset_actor(Vector2(260,300),-1);host.player.reset_actor(Vector2(180,300),1)
	host.camera.position=Vector2(320,180);host.camera.force_update_scroll()
	host.state="playing";host.blind=false;host.hearing_retained=not deaf;host._apply_senses()
	host.notice_left=0;host.chapter_left=0;host._pending_sector=-1;host._pending_retry=false
	host.actor_paint.set_sight_enabled(true);observer.enabled=true;observer.bind_room()
	host.hud.set_snapshot(host._hud_snapshot())
func attack()->void:enemy.physics_tick(1.0/hz,{"attack":true})
func snapshot()->Dictionary:
	var data:Dictionary={"state":"playing","notice_visible":false,"chapter_visible":false,"prompt":""}
	observer.decorate(data);return data
func run()->void:
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true)
	for i in host.sectors.size():
		if host.sectors[i].id=="quarantine_intake":host.load_sector(i);break
	host.set_physics_process(false)
	for e in host.enemies:
		e.get_node("IntentDriver").automatic_driver=false
		if e.kind=="captain_lancer":enemy=e
	observer=host.tactical_companion
	driver=Driver.new();driver.process_physics_priority=90;root.add_child(driver)
	for deaf in [false,true]:
		stage(deaf);await tick();await tick(attack)
		var data:=snapshot();check(data.get("notice","")=="Step aside.","actual visible windup warning hearing="+str(not deaf))
		check(not observer._warning_seen,"query does not acknowledge")
		check(host.hud.set_snapshot(data) and observer._warning_seen,"typed HUD accepted warning")
		check(enemy.late_windup_snapshot().is_empty()==(not deaf),"existing hearing FOCUS policy unchanged")
		await tick(func():enemy._advance_melee(1.2));await tick(func():enemy.physics_tick(1.0/hz,{}));await tick(func():enemy._advance_melee(.4))
		check(enemy.weapon_phase==&"recovery","actual recovery reached")
		data=snapshot();check(data.get("notice","")=="An opening.","same-attack observed recovery followup")
		host.hud.set_snapshot(data);check(observer._recovery_seen,"followup acknowledged")
		await tick(func():enemy._advance_melee(2.0));check(not snapshot().get("notice_visible",false),"idle not recovery")
		await tick(attack);check(not snapshot().get("notice_visible",false),"once per room warning budget")
	stage();await tick();await tick(attack)
	for override in [{"chapter_visible":true},{"prompt":"Use"},{"notice_visible":true,"notice":"OBJECTIVE"},{"panel_override":true},{"state":"journal"}]:
		var data:Dictionary={"state":"playing","notice_visible":false,"prompt":""};data.merge(override,true);var before:=data.duplicate(true);observer.decorate(data);check(data==before,"priority blocks "+str(override))
	var before_owner:Dictionary=host.hud._snapshot.duplicate(true)
	check(not host.hud.set_snapshot({"tactical_line_id":5}) and host.hud._snapshot==before_owner,"typed rejection atomic")
	host.hud.set_snapshot({});check(host.hud._snapshot.tactical_line_id=="","omission clears tactical ID")
	var data:=snapshot();host.companion.safe=true;host.companion.director.active={"event":"captain","id":"captain","text":"quiet"};host.companion.decorate(data);check(data.notice=="Step aside.","quiet companion cannot replace tactical")
	for mode in ["blind","paused","retry","transition","hidden","offscreen","reset","configuration","session","disabled"]:
		stage();await tick();await tick(attack)
		match mode:
			"blind":host.blind=true
			"paused":host.state="paused"
			"retry":host._pending_retry=true
			"transition":host._pending_sector=1
			"hidden":enemy.get_node("CampaignSecuritySkin").visible=false
			"offscreen":enemy.position.x=1000
			"reset":enemy.reset_actor(enemy.position,-1)
			"configuration":enemy.melee_chain=enemy.melee_chain.duplicate(true)
			"session":host.session_generation+=1
			"disabled":observer.enabled=false
		check(not snapshot().get("notice_visible",false),"immediate suppression "+mode)
		await tick();check(observer._candidate.is_empty(),"retired candidate "+mode)
	stage();await tick()
	var wall:=StaticBody2D.new();wall.position=Vector2(220,270);var shape:=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=Vector2(12,100);shape.shape=rect;wall.add_child(shape);host.room.add_child(wall)
	await tick();await tick(attack);check(not snapshot().get("notice_visible",false),"wall blocks admission");wall.free()
	stage();await tick();await tick(attack);data=snapshot();host.hud.set_snapshot(data)
	enemy.reset_actor(enemy.position,-1);observer._acknowledge(str(data.tactical_line_id),str(data.notice));check(not snapshot().get("notice_visible",false),"stale acknowledgment cannot resurrect attack")
	stage();await tick();await tick(attack);data=snapshot()
	host.hud.companion_presentation_accepted.connect(func(_id:String,_blocked:bool):host.hud.set_snapshot({"state":"playing","notice_visible":true,"notice":"Priority replacement"}),CONNECT_ONE_SHOT)
	host.hud.set_snapshot(data)
	check(not observer._warning_seen and host.hud._snapshot.notice=="Priority replacement","reentrant HUD replacement does not acknowledge superseded cue")
	stage();await tick();await tick(attack);host.load_sector(0);check(observer._actor==null and observer._candidate.is_empty(),"room teardown unbinds")
	host.free();driver.free();await process_frame;await process_frame
	print("INTELLECT_CONTRACT "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"hz":hz}));quit(0 if failures.is_empty() else 1)
