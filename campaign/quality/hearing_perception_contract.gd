extends SceneTree
## Seeded real campaign/physics boundary fixtures. Not natural traversal.
class Driver extends Node:
	var job:Callable
	var ticks:=0
	func _physics_process(_dt:float)->void:
		if job.is_valid():
			var work:=job;job=Callable();work.call()
		ticks+=1
var host:Node
var enemy:Node
var driver:Driver
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func tick(job:Callable=Callable())->void:
	var target:=driver.ticks+1;driver.job=job
	while driver.ticks<target:await physics_frame;await process_frame
func stage()->void:
	enemy.reset_actor(Vector2(260,300),-1)
	host.player.reset_actor(Vector2(200,300),1)
	host.camera.position=Vector2(320,180);host.camera.force_update_scroll()
	host.state="playing";host.blind=false;host.hearing_retained=false;host._apply_senses()
	host.notice_left=0;host.chapter_left=0;host._pending_sector=-1;host._pending_retry=false
	host.actor_paint.set_sight_enabled(true)
	host.hud.set_snapshot(host._hud_snapshot())
func attack()->void:
	enemy.physics_tick(1.0/60.0,{"attack":true})
func run()->void:
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true);host.load_sector(1);host.set_physics_process(false)
	for e in host.enemies:e.get_node("IntentDriver").automatic_driver=false
	enemy=host.enemies[0]
	driver=Driver.new();driver.process_physics_priority=90;root.add_child(driver)
	stage();await tick();await tick(attack)
	check(not enemy.late_windup_snapshot().is_empty(),"visible unobstructed melee admits lease at real physics input commit")
	await tick(func():enemy._advance_melee(.45))
	check(not host.focus_observer.visible_marks().is_empty(),"admitted late tail has local bracket snapshot")
	var lease:Dictionary=enemy.late_windup_snapshot()
	host.player.position.x+=1
	check(host.focus_observer.visible_marks().is_empty(),"same-frame player move retires cached visibility")
	check(not enemy.late_windup_snapshot().is_empty(),"visibility retirement does not revoke committed controller lease")
	await tick()
	host.state="journal";check(host.focus_observer.visible_marks().is_empty(),"modal hides cue immediately");host.state="playing"
	host._pending_retry=true;check(host.focus_observer.visible_marks().is_empty(),"pending retry hides cue immediately");host._pending_retry=false
	host._pending_sector=1;check(host.focus_observer.visible_marks().is_empty(),"pending room transition hides cue immediately");host._pending_sector=-1
	stage();host.hearing_retained=true;host._apply_senses();await tick();await tick(attack)
	check(enemy.late_windup_snapshot().is_empty(),"hearing retained receives no timing modification")
	stage();enemy.position.x=900;await tick();await tick(attack)
	check(enemy.late_windup_snapshot().is_empty(),"offscreen commit not admitted")
	enemy.position=Vector2(260,300);await tick()
	check(enemy.late_windup_snapshot().is_empty(),"entering view mid-windup cannot re-admit")
	stage();enemy.position=Vector2(260,42);await tick();await tick(attack)
	check(enemy.late_windup_snapshot().is_empty(),"opaque header excludes nominally onscreen enemy")
	stage();enemy.get_node("CampaignSecuritySkin").visible=false;await tick();await tick(attack)
	check(enemy.late_windup_snapshot().is_empty(),"hidden actor paint cannot grant visible focus")
	stage()
	var wall:=StaticBody2D.new();wall.position=Vector2(230,270);var collider:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(12,100);collider.shape=shape;wall.add_child(collider);host.room.add_child(wall)
	await tick();await tick(attack)
	check(enemy.late_windup_snapshot().is_empty(),"physical wall blocks focus admission")
	wall.free();stage();await tick();await tick(attack);await tick(func():enemy._advance_melee(.45))
	check(not host.focus_observer.visible_marks().is_empty(),"clear route restores eligible bracket")
	host.goals[0].changed.emit()
	check(host.focus_observer.visible_marks().is_empty(),"same-frame objective/door change retires cached mark")
	check(not enemy.late_windup_snapshot().is_empty(),"door-related mark retirement does not rewrite committed timing")
	var sentry=load("res://demo/components/shared_sentry.tscn").instantiate();host.room.add_child(sentry);sentry.configure(host.player,host.bus);sentry.get_node("IntentDriver").automatic_driver=false;host.enemies.append(sentry)
	var skin:=Node2D.new();skin.name="CampaignSecuritySkin";sentry.add_child(skin)
	host.focus_observer.bind_room();sentry.reset_actor(Vector2(260,300),-1)
	await tick();await tick(func():sentry.physics_tick(1.0/60.0,{"attack":true}))
	check(sentry.attack_serial>0 and sentry.late_windup_snapshot().is_empty(),"committed sentry projectile explicitly excluded by campaign")
	# Listener cost: world event still reaches the enemy sensor, not our sonar/audio.
	stage();await tick()
	var sensor=enemy.get_node("HearingSensor");var count:int=sensor.heard_count
	host.bus.emit_noise(host.player.global_position-Vector2(0,18),&"weapon_tap",1.0,host.player)
	check(sensor.heard_count>count,"hearing loss leaves real enemy NoiseBus hearing intact")
	check(host.sonar.pulses.is_empty() and host.sonar.event_history.is_empty(),"deaf listener rejects emitted world noise")
	check(host.audio.last_spatial_sound.is_empty(),"deaf listener rejects informative spatial audio")
	var was_muted:bool=host.audio.muted;host.audio.toggle_mute();host.audio.toggle_mute()
	check(host.audio.muted==was_muted and not host.audio.hearing_enabled,"global mute independent from sensory loss")
	var voice:=AudioStreamPlayer2D.new();host.audio.add_child(voice)
	host.audio.set_hearing_enabled(true);host.audio.set_hearing_enabled(false)
	check(voice.is_queued_for_deletion(),"existing world voice retired on loss")
	check(not host.audio.ambient.playing,"ambience stopped by loss")
	host.hearing_retained=true;host._apply_senses()
	host.bus.emit_noise(host.player.global_position-Vector2(0,18),&"weapon_tap",1.0,host.player)
	check(not host.sonar.event_history.is_empty() and not host.audio.last_spatial_sound.is_empty(),"retained listener restores ordinary noise intake")
	driver.free();host.free();await process_frame
	print(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"seeded perception/audio boundaries; real physics input commits, no native/audio listening claim"}))
	quit(0 if failures.is_empty() else 1)
