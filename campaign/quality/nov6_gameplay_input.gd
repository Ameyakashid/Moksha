extends SceneTree
## Campaign adapter regression. Real actor simulation; test-only scene/menu setup.
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
func key(code:int,physical:=true)->void:
	var event:=InputEventKey.new();event.pressed=true
	if physical:event.physical_keycode=code
	else:event.keycode=code
	host._unhandled_key_input(event)
func device_key(code:int,pressed:bool)->void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.pressed=pressed
	Input.parse_input_event(event);Input.flush_buffered_events()
func frames(count:int)->void:
	for index in count:await physics_frame;await process_frame
func fresh()->void:
	host.input_override={}
	host.start_new(true)
	await frames(4)
func run()->void:
	host=load("res://campaign/campaign.tscn").instantiate()
	if not baseline_script.is_empty():host.set_script(load(baseline_script))
	host.save_enabled=false;root.add_child(host)
	await frames(4)
	check(host.state=="title" and not is_instance_valid(host.player),"title boot samples no nonexistent actor actions")
	await fresh()
	# Injected raw frames deliberately carry the same held/edge values as devices.
	host.start_new(false)
	host.input_override={"jump":true,"jump_pressed":true}
	key(KEY_SPACE);await frames(4)
	check(host.state=="playing" and not host.player._input.jump and host.player.velocity.y>=0,"intro Space skips without leaking jump")
	host.input_override={};await frames(2)
	host.input_override={"jump":true};await frames(2)
	check(host.player.velocity.y<0,"fresh jump after release still launches")
	await fresh()
	key(KEY_TAB)
	host.input_override={"right":1.0,"attack":true}
	key(KEY_D);key(KEY_ESCAPE)
	var before:Vector2=host.player.position
	await frames(5)
	check(host.player.position.distance_to(before)<1 and host.player.weapon_phase==&"idle","journal navigation and held strike cannot leak into gameplay")
	host.input_override={};await frames(2)
	host.input_override={"right":1.0,"attack":true};await frames(2)
	check(host.player._input.x>0 and host.player.weapon_phase!=&"idle","fresh movement and strike rearm after journal")
	await fresh()
	host.state="choice";paused=true;host.input_override={"attack":true,"attack_pressed":true}
	key(KEY_J);await frames(3)
	check(host.blind and host.player.weapon_phase==&"idle" and not host.player._input.attack,"sight-trade J does not strike")
	await fresh()
	host.state="upgrade";paused=true;host.input_override={"shield":true,"shield_pressed":true}
	key(KEY_K);key(KEY_K);await frames(3)
	check(host.sector==1 and host.upgrades.size()==1 and host.player.shield_phase==&"idle","one upgrade choice transitions once and does not raise shield")
	await fresh()
	host.input_override={"attack":true};key(KEY_ESCAPE);key(KEY_R);await frames(3)
	check(host.state=="playing" and not paused and host.player.weapon_phase==&"idle","paused retry clears held action")
	await fresh()
	key(KEY_ESCAPE,false)
	check(host.state=="paused" and paused,"logical-key Escape pauses just like physical-key Escape")
	key(KEY_ESCAPE,false)
	check(host.state=="playing" and not paused,"logical-key Escape resumes")
	# Scripted overrides are a caller-owned source, not replaced by the filter.
	var source:Dictionary={"jump":true,"jump_pressed":false,"attack":false}
	host.input_override=source;await frames(1)
	check(host.input_override==source,"input filtering leaves caller-owned raw frame unchanged")
	var snapshot:Dictionary=host._hud_snapshot()
	check(snapshot.get("district_index")==1 and snapshot.get("district_count")==32 and snapshot.get("level_index")==1 and snapshot.get("lens")==host.lens and snapshot.has("guidance") and snapshot.has("required_done") and snapshot.has("required_total") and snapshot.has("gate_open"),"HUD exposes additive campaign guidance fields")
	await fresh()
	host.input_override=null
	device_key(KEY_TAB,true);device_key(KEY_TAB,false)
	device_key(KEY_J,true)
	device_key(KEY_TAB,true);device_key(KEY_TAB,false)
	await frames(3)
	check(host.state=="playing" and host.player.weapon_phase==&"idle","native InputMap J held across journal close does not strike")
	device_key(KEY_J,false);await frames(2)
	device_key(KEY_J,true);await frames(2)
	check(host.player.weapon_phase!=&"idle","native InputMap fresh J rearms after release")
	device_key(KEY_J,false)
	await fresh()
	host.input_override={"right":1.0,"attack":true}
	root.focus_exited.emit()
	var paused_time:float=host.elapsed
	await frames(4)
	check(host.state=="paused" and paused and host.elapsed==paused_time,"window focus loss pauses gameplay and active clock")
	root.focus_entered.emit();await frames(2)
	check(host.state=="paused" and paused,"refocus requires explicit resume")
	key(KEY_ESCAPE);await frames(2)
	check(host.state=="playing" and host.player._input.x==0 and not host.player._input.attack,"explicit resume rearms held focus-loss input")
	key(KEY_TAB);root.focus_exited.emit()
	check(host.state=="journal" and paused,"focus loss preserves journal state")
	key(KEY_TAB);host._pending_sector=1;root.focus_exited.emit();await frames(2)
	check(host.state=="paused" and host.sector==0,"focus pause suspends already-queued district transition")
	key(KEY_ESCAPE);await frames(2)
	check(host.state=="playing" and host.sector==1,"queued transition completes once after explicit focus resume")
	await fresh()
	key(KEY_R);root.focus_exited.emit()
	var actor_id:int=host.player.get_instance_id()
	await frames(3)
	check(host.state=="paused" and host.player.get_instance_id()==actor_id,"focus pause suspends already-queued retry")
	key(KEY_ESCAPE);await frames(2)
	check(host.state=="playing" and host.player.get_instance_id()!=actor_id,"explicit resume executes queued retry once")
	await fresh()
	host.state="upgrade";paused=true;key(KEY_L);root.focus_exited.emit();await frames(3)
	check(host.state=="paused" and host.sector==0 and host.upgrades.size()==1,"focus pause suspends upgrade transition without repeating choice")
	key(KEY_ESCAPE);await frames(2)
	check(host.state=="playing" and host.sector==1 and host.upgrades.size()==1,"upgrade transition resumes once with its chosen upgrade")
	await fresh()
	host.start_new(false);host.intro_time=3.68;root.focus_exited.emit();await frames(8)
	check(host.state=="paused" and is_equal_approx(host.elapsed,0.0) and is_equal_approx(host.intro_time,3.68),"focus loss freezes opening instead of auto-starting off-focus")
	key(KEY_ESCAPE);await frames(8)
	check(host.state=="playing" and not paused,"explicit resume lets the opening finish normally")
	await fresh()
	host.input_override=null
	device_key(KEY_SPACE,true);await frames(2)
	check(host.player.velocity.y < -host.player.profile.jump_release_rise_cap,"native paused-release fixture begins above jump-cut speed")
	device_key(KEY_ESCAPE,true);device_key(KEY_ESCAPE,false)
	device_key(KEY_SPACE,false);await frames(5)
	device_key(KEY_ESCAPE,true);device_key(KEY_ESCAPE,false);await frames(1)
	check(host.player.velocity.y>=-host.player.profile.jump_release_rise_cap-1.0 and host.player._input.jump_released,"native jump release during pause still cuts ascent on resume")
	print("NOV6_GAMEPLAY_INPUT_RESULT "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"hz":Engine.physics_ticks_per_second,"failures":failures,"scope":"Campaign modal boundaries plus actual shared actor physics; not full human playthrough."}))
	host.free();quit(0 if failures.is_empty() else 1)
