extends SceneTree
## Staged flat Clinic encounter; subsequent inputs/AI/damage are ordinary physics.
class Driver extends Node:
	var host:Node
	var enemy:Node
	var ticks:=0
	var limit:=0
	var hz:=60
	var started:=-1
	var events:Array=[]
	var trace:Array=[]
	func event(kind:StringName,packet:Dictionary)->void:
		if kind==&"attack_started" and started<0:started=ticks
		if kind in [&"attack_started",&"attack_phase_changed",&"attack_cancelled",&"attack_finished"]:
			events.append({"tick":ticks,"event":str(kind),"serial":packet.get("serial"),"phase":packet.get("phase","")})
	func _physics_process(dt:float)->void:
		if ticks>=limit:return
		# Same fixed reaction delay in both branches, not an automated perfect parry.
		var shield:=started>=0 and ticks-started>=ceili(hz*.65) and ticks-started<ceili(hz*.85)
		host.player.physics_tick(dt,{"shield":shield})
		trace.append({"tick":ticks,"health":host.health.current_health,"player_action":str(host.player.main_action),"shield":str(host.player.shield_phase),"defense":str(host.player.telemetry().last_defense_outcome),"enemy_phase":str(enemy.weapon_phase),"enemy_elapsed":enemy._weapon_elapsed,"position":[host.player.position.x,host.player.position.y]})
		ticks+=1
var hz:=60
var output:=""
var results:Dictionary={}
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	if hz not in [60,120] or not output.is_absolute_path() or output.begins_with(ProjectSettings.globalize_path("res://")) or FileAccess.file_exists(output):quit(2);return
	Engine.physics_ticks_per_second=hz;run.call_deferred()
func run()->void:
	for retained in [true,false]:
		var host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true);host.load_sector(1);host.set_physics_process(false)
		for e in host.enemies:e.ai_enabled=false
		var enemy=host.enemies[0]
		host.player.reset_actor(Vector2(200,300),1);enemy.reset_actor(Vector2(238,300),-1)
		host.hearing_retained=retained;host._apply_senses();host.notice_left=0;host.chapter_left=0
		host.camera.position=Vector2(320,180);host.camera.force_update_scroll();host.hud.set_snapshot(host._hud_snapshot())
		var driver:=Driver.new();driver.host=host;driver.enemy=enemy;driver.hz=hz;driver.limit=hz*2;driver.process_physics_priority=-10
		enemy.movement_event.connect(driver.event);root.add_child(driver);enemy.ai_enabled=true
		while driver.ticks<driver.limit:await physics_frame;await process_frame
		results["retained" if retained else "traded"]={"trace":driver.trace.duplicate(true),"events":driver.events.duplicate(true),"admissions":host.focus_observer.admitted_count,"health":host.health.current_health}
		driver.free();host.free();await process_frame
	var data:={"physics_hz":hz,"scope":"Staged same flat Clinic encounter; ordinary player shield input at0.65s after first real AI commitment; no clock/health/goal writes during encounter","cases":results}
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file==null:quit(2);return
	file.store_string(JSON.stringify(data));file.flush();var error:=file.get_error();file.close()
	if error!=OK or not JSON.parse_string(FileAccess.get_file_as_string(output)) is Dictionary:quit(2);return
	print("HEARING_ENCOUNTER_TRACE ",JSON.stringify({"hz":hz,"retained_health":results.retained.health,"traded_health":results.traded.health,"admissions":results.traded.admissions}))
	quit(0)
