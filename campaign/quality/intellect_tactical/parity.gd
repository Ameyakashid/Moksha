extends SceneTree
## Seeded encounter, then actual InputEventKey only. No earned-route claim.
class Driver extends Node:
	var job:Callable
	func _physics_process(_dt:float)->void:if job.is_valid():job.call()
var host:Node
var driver:Driver
var frame:=0
var limit:=480
var hz:=60
var enabled:=true
var deaf:=false
var out:=""
var samples:Array=[]
var keys:Array=[]
var cues:Dictionary={}
var held:Dictionary={}
var failures:Array=[]
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
		if arg.begins_with("--output="):out=arg.trim_prefix("--output=")
		if arg=="--disabled":enabled=false
		if arg=="--deaf":deaf=true
	Engine.physics_ticks_per_second=hz;limit=hz*8;seed(9183);run.call_deferred()
func press(code:int,value:bool)->void:
	if held.get(code,false)==value:return
	var e:=InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=value;Input.parse_input_event(e);Input.flush_buffered_events();held[code]=value
	keys.append({"tick":frame,"key":code,"pressed":value})
func on_tick()->void:
	if frame>=limit:return
	var enemy_rows:Array=[]
	for enemy in host.enemies:
		enemy_rows.append({"position":enemy.position,"velocity":enemy.velocity,"health":enemy.health,"action":enemy.main_action,"weapon":enemy.weapon_phase,"serial":enemy.attack_serial,"dead":enemy.dead})
	samples.append({"position":host.player.position,"velocity":host.player.velocity,"health":host.health.current_health,"action":host.player.main_action,"weapon":host.player.weapon_phase,"shield":host.player.shield_phase,"serial":host.player.attack_serial,"enemies":enemy_rows,"override_null":host.input_override==null})
	if host.input_override!=null:failures.append("unexpected input override")
	var seconds:=float(frame)/hz
	press(KEY_K,seconds<2.5 or seconds>=5)
	press(KEY_J,seconds>=3 and seconds<3.12 or seconds>=4 and seconds<4.12)
	press(KEY_SPACE,seconds>=2.7 and seconds<3.1)
	frame+=1
func run()->void:
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.lens="strength";host.start_new(true)
	for i in host.sectors.size():
		if host.sectors[i].id=="quarantine_intake":host.load_sector(i);break
	host.player.reset_actor(Vector2(1900,300),1);host.camera.position=Vector2(1900,180);host.camera.force_update_scroll()
	host.hearing_retained=not deaf;host._apply_senses();host.chapter_left=0;host.notice_left=0
	host.tactical_companion.enabled=enabled
	host.hud.tactical_presentation_accepted.connect(func(id:String,text:String):cues[id]=text)
	driver=Driver.new();driver.process_physics_priority=1000;driver.job=on_tick;root.add_child(driver)
	while frame<limit:await physics_frame;await process_frame
	driver.job=Callable()
	for code in held:press(code,false)
	var receipt:Dictionary={"enabled":enabled,"deaf":deaf,"hz":hz,"samples":samples,"keys":keys,"cues":cues,"failures":failures,"scope":"Seeded real encounter with actual physical key events; no mid-run state writes; not earned/native play"}
	FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify(receipt))
	host.free();driver.free();await process_frame;await process_frame
	print("INTELLECT_PARITY_CAPTURE "+JSON.stringify({"passed":failures.is_empty(),"samples":samples.size(),"cues":cues,"hz":hz,"enabled":enabled,"deaf":deaf}));quit(0 if failures.is_empty() else 1)
