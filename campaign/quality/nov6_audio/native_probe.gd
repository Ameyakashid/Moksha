extends SceneTree
## Native rendering / actual audio-branch instrumentation.
## Dummy audio playback positions are not speaker output or listening verification.
var host
var checks: Array[Dictionary] = []
var data: Dictionary = {}
var observed: Array[Dictionary] = []
var movement: Array[Dictionary] = []
var capture: AudioEffectCapture
var fixed := not "--expect-baseline" in OS.get_cmdline_user_args()
var hz:=120
var output_path:=""
var argument_failures:Array[String]=[]
func configure()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):
			var value:=arg.trim_prefix("--hz=")
			if value in ["60","120"]:hz=int(value)
			else:argument_failures.append("--hz must be 60 or 120")
		elif arg.begins_with("--output="):
			output_path=arg.trim_prefix("--output=")
	Engine.physics_ticks_per_second=hz
func write_report(report:Dictionary,default_name:String)->void:
	var path:=output_path if not output_path.is_empty() else "user://nov6_audio/"+default_name
	# Reports may go to user data or an explicitly requested absolute path,
	# never res:// or anywhere inside this project's source directory.
	var absolute:=ProjectSettings.globalize_path(path).simplify_path()
	var project_root:=ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	if not (path.begins_with("user://") or path.is_absolute_path()) or path.begins_with("res://") or absolute==project_root or absolute.begins_with(project_root+"/"):
		report.failures.append("--output must be user:// or an absolute path outside the project")
		report.passed=false;return
	var error:=DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error!=OK:
		report.failures.append("Could not create report output directory: "+error_string(error))
		report.passed=false;return
	var file:=FileAccess.open(absolute,FileAccess.WRITE)
	if file==null:
		report.failures.append("Could not open report output: "+error_string(FileAccess.get_open_error()))
		report.passed=false;return
	report.output=absolute
	file.store_string(JSON.stringify(report,"\t"));file.flush()
	if file.get_error()!=OK:
		report.failures.append("Could not write report output: "+error_string(file.get_error()))
		report.passed=false
	file.close()
func result_rows(scope:String)->Dictionary:
	var failures:Array[String]=argument_failures.duplicate()
	for row in checks:
		if not row.passed:failures.append(row.label)
	return {"checks":checks.size(),"passed":not checks.is_empty() and failures.is_empty(),"failures":failures,"rows":checks,"physics_hz":hz,"engine":Engine.get_version_info().string,"scope":scope}
func _initialize():
	configure()
	call_deferred("run")
func note(label:String,value:Variant):
	data[label]=value.duplicate(true) if value is Array or value is Dictionary else value
	print(label,": ",value)
func check(ok:bool,label:String):
	checks.append({"label":label,"passed":ok});print("PASS " if ok else "FAIL ",label)
func wait(seconds:float): await create_timer(seconds,true).timeout
func voices()->Array: return host.audio.get_children().filter(func(c):return c!=host.audio.ambient)
func snap(voice)->Dictionary:
	if not is_instance_valid(voice):return {"freed":true}
	return {"playing":voice.playing,"stream_paused":voice.stream_paused,"can_process":voice.can_process(),"position":voice.get_playback_position(),"stream":voice.stream.resource_path,"process_mode":voice.process_mode,"type":voice.get_class()}
func clear_voices():
	for c in voices():c.stop();c.free()
func key(k:int):
	var ev:=InputEventKey.new();ev.physical_keycode=k;ev.pressed=true
	host._unhandled_key_input(ev)
func quiet():
	host.set_physics_process(false);host.set_process(false)
	for enemy in host.enemies:enemy.ai_enabled=false
	host.room.process_mode=Node.PROCESS_MODE_DISABLED
func on_noise(origin:Vector2,kind:StringName,loudness:float,source:Node):
	if is_instance_valid(host) and source==host.player:
		observed.append({"kind":kind,"key":host.audio.last_spatial_sound.get("key",""),"origin":origin})
func on_movement(kind:StringName,payload:Dictionary):movement.append({"kind":kind,"payload":payload})
func run():
	if DisplayServer.get_name()=="headless":
		check(false,"Native probe requires a non-headless display driver")
		finish_native_report()
		return
	AudioServer.set_bus_mute(0,false)
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host)
	host.bus.noise_emitted.connect(on_noise)
	host.start_new(true);quiet();host.hud.set_snapshot(host._hud_snapshot());host.audio.ambient.stop()
	note("engine",Engine.get_version_info().string)
	note("display_driver",DisplayServer.get_name());note("audio_driver",AudioServer.get_driver_name())
	check(DisplayServer.get_name()!="headless","original audio runtime native branch is active")
	capture=AudioEffectCapture.new();capture.buffer_length=4;AudioServer.add_bus_effect(0,capture)
	# An existing spatial sound pauses and resumes, including playback position.
	await wait(1.0)
	host.audio.play_at("win",host.camera.position,-10,1)
	var v=voices()[-1]
	await wait(0.09)
	note("existing_spatial_before_pause",snap(v))
	paused=true;host.state="paused"
	await wait(0.12);note("existing_spatial_paused",snap(v))
	check(is_instance_valid(v) and v.stream_paused,"existing spatial voice pauses")
	paused=false;host.state="playing"
	await wait(0.07);note("existing_spatial_resumed",snap(v))
	check(is_instance_valid(v) and not v.stream_paused,"existing spatial voice resumes")
	clear_voices()
	# Nonspatial cue created while paused is allowed to advance in Godot.
	host.complete_run();v=voices()[-1]
	await wait(0.25);note("actual_victory_after_250ms",snap(v))
	check(is_instance_valid(v) and v.get_playback_position()>0.1,"actual completion cue advances while campaign paused")
	clear_voices()
	# Actual archive interaction emits a spatial tap and pauses before next physics.
	host.start_new(true);quiet();host.player.reset_actor(host.sectors[0].cache,1)
	host.interact()
	v=voices()[-1]
	note("actual_archive_immediate",snap(v))
	await wait(0.25);note("actual_archive_after_250ms",snap(v))
	if fixed:
		# Native render scheduling can delay the first spatial physics callback.
		# Keep the modal open and require completion within a bounded window,
		# rather than equating 250 ms of scene time with audio-thread time.
		var deadline:=Time.get_ticks_msec()+1000
		while is_instance_valid(v) and Time.get_ticks_msec()<deadline:
			await wait(0.05)
		note("actual_archive_before_close",snap(v))
		check(not is_instance_valid(v) and host.state=="archive" and paused,"archive tap finishes during modal")
	else:
		check(is_instance_valid(v) and v.get_playback_position()==0.0,"baseline archive tap deferred until modal closes")
	key(KEY_ESCAPE);await wait(0.09);note("actual_archive_after_close",snap(v))
	clear_voices()
	# Modal mute key must use the real key handler, not direct audio calls.
	var mute_states={}
	for state in ["title","intro","playing","archive","choice","paused","journal","upgrade","final_choice","complete","dead"]:
		host.state=state;paused=state!="playing";host._pending_sector=-1;host._pending_retry=false
		host.audio.muted=false;AudioServer.set_bus_mute(0,false)
		key(KEY_M)
		mute_states[state]={"flag":host.audio.muted,"bus":AudioServer.is_bus_mute(0)}
	note("modal_mute",mute_states)
	check(mute_states.values().all(func(s):return s.flag and s.bus) if fixed else not mute_states.journal.flag and not mute_states.upgrade.flag and not mute_states.final_choice.flag,"mute across all modal states" if fixed else "baseline mute missing in three campaign modals")
	host.audio.muted=false;AudioServer.set_bus_mute(0,false)
	# Input-driven real ground and air jumps. Original actors and bus are unchanged.
	host.start_new(true);quiet();host.room.process_mode=Node.PROCESS_MODE_PAUSABLE
	host.set_physics_process(true);host.input_override={}
	host.player.movement_event.connect(on_movement)
	await wait(0.15);observed.clear();movement.clear()
	host.input_override={"jump":true};await physics_frame;await physics_frame
	host.input_override={};await wait(0.08)
	host.input_override={"jump":true};await physics_frame;await physics_frame
	host.input_override={};await wait(0.1)
	note("real_jump_movement",movement);note("real_jump_noise",observed)
	note("real_jump_audio_voices",voices().map(snap))
	quiet();clear_voices()
	# Actual admitted lethal damage via public actor receive_hit boundary.
	host.start_new(true);quiet();host.room.process_mode=Node.PROCESS_MODE_PAUSABLE
	await wait(0.1);clear_voices()
	host.player.receive_hit({"amount":1000.0,"impulse":Vector2.ZERO,"source_position":host.player.global_position+Vector2(30,0),"source_id":0})
	note("lethal_state",{"state":host.state,"paused":paused,"health":host.health.current_health})
	note("lethal_immediate",voices().map(snap))
	await wait(0.25);note("lethal_after_250ms",voices().map(snap))
	var hurt=voices().filter(func(c):return c.stream==host.audio.cache.hurt)
	check(hurt.size()==1 and hurt[0].get_playback_position()>0.1 if fixed else hurt.size()==1 and hurt[0].get_playback_position()==0.0,"lethal hurt advances during death" if fixed else "baseline lethal hurt deferred on death")
	host.start_new(true);quiet();await wait(0.1);note("lethal_after_retry",voices().map(snap))
	check(voices().all(func(c):return c.stream!=host.audio.cache.hurt) if fixed else voices().any(func(c):return c.stream==host.audio.cache.hurt),"no old hurt on retry" if fixed else "baseline old hurt begins on retry")
	clear_voices()
	# Capture is a numerical bus buffer, not a listening or soundcard assessment.
	note("capture_frames_total",capture.get_frames_available())
	AudioServer.remove_bus_effect(0,0)
	host.free();paused=false;AudioServer.set_bus_mute(0,false)
	await process_frame;await process_frame;await process_frame
	# The audio thread must retire playback references before engine shutdown.
	await create_timer(0.25,true).timeout
	finish_native_report()
func finish_native_report()->void:
	var report:=result_rows("Native original audio-director branch. Automated interaction/state fixtures; lethal hit uses the public damage-admission boundary. Dummy audio is not soundcard output or listening verification. No runtime/source writes.")
	report.expectation="fixed" if fixed else "baseline"
	report.observations=data
	write_report(report,"native_%s_%dhz.json"%[report.expectation,hz])
	print("NOV6_AUDIO_NATIVE_RESULT "+JSON.stringify(report))
	quit(0 if report.passed else 1)
