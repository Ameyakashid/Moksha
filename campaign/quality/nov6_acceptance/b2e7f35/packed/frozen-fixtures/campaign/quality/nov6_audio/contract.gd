extends SceneTree
var host
var checks:Array[Dictionary]=[]
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
func check(ok:bool,label:String):
	checks.append({"label":label,"passed":ok});print("PASS " if ok else "FAIL ",label)
func key(physical:int,logical:=0,echo:=false,pressed:=true):
	var event:=InputEventKey.new();event.physical_keycode=physical;event.keycode=logical;event.echo=echo;event.pressed=pressed
	host._unhandled_key_input(event)
func dummy(key_:String)->AudioStreamPlayer2D:
	var v:=AudioStreamPlayer2D.new();v.stream=host.audio.cache[key_];host.audio.add_child(v);return v
func run():
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true)
	host.set_physics_process(false);host.set_process(false)
	for state in ["title","intro","playing","archive","choice","paused","journal","upgrade","final_choice","complete","dead"]:
		host.state=state;paused=state!="playing";host.audio.muted=false;AudioServer.set_bus_mute(0,false)
		key(KEY_M);check(host.audio.muted and AudioServer.is_bus_mute(0),"physical M toggles on once: "+state)
		key(KEY_M,0,true);check(host.audio.muted and AudioServer.is_bus_mute(0),"M echo ignored: "+state)
		key(KEY_M,0,false,false);check(host.audio.muted and AudioServer.is_bus_mute(0),"M release ignored: "+state)
		key(0,KEY_M);check(not host.audio.muted and not AudioServer.is_bus_mute(0),"logical M toggles off once: "+state)
		check(host.state==state and paused==(state!="playing"),"M preserves modal state: "+state)
	host.state="paused";paused=true;host._focus_pause_active=true;host._pending_retry=true;host._pending_sector=2
	key(KEY_M);check(host.audio.muted and host._pending_retry and host._pending_sector==2 and host._focus_pause_active,"M preserves pending/focus boundary")
	key(KEY_M);host._focus_pause_active=false;host._pending_retry=false;host._pending_sector=-1
	var existing:=dummy("hurt")
	var first:int=host.audio.get_child_count()
	var modal:=dummy("hurt");var unrelated:=dummy("prop")
	host._audio_feedback.finish_modal_since(host.audio,first,"hurt")
	check(modal.process_mode==Node.PROCESS_MODE_ALWAYS and not modal.stream_paused,"new matching modal cue gets live physics while paused")
	check(existing.process_mode==Node.PROCESS_MODE_INHERIT and unrelated.process_mode==Node.PROCESS_MODE_INHERIT,"existing and unrelated cues keep inherited pause mode")
	var outside:=Node.new();root.add_child(outside)
	host._on_noise(Vector2.ZERO,&"player_damage",1.0,outside)
	check(existing.process_mode==Node.PROCESS_MODE_INHERIT,"rejected external damage cannot promote old hurt")
	outside.free()
	paused=false;host.state="playing"
	first=host.audio.get_child_count()
	var damage:=dummy("hurt")
	host._audio_feedback.observe_damage(host.audio,first)
	check(damage.process_mode==Node.PROCESS_MODE_INHERIT,"nonlethal hurt retains pausable mode")
	host._on_defeat()
	check(host.state=="dead" and damage.process_mode==Node.PROCESS_MODE_ALWAYS,"defeat promotes only freshly observed hurt")
	check(existing.process_mode==Node.PROCESS_MODE_INHERIT,"defeat leaves earlier world hurt alone")
	paused=false;host.state="playing"
	first=host.audio.get_child_count()
	var stale:=dummy("hurt")
	host._audio_feedback.observe_damage(host.audio,first)
	paused=true;host.state="paused"
	await physics_frame;await physics_frame
	check(stale.get_playback_position()==0.0,"stale paused hurt remains at zero playback position")
	host.state="playing";host._on_defeat()
	check(stale.process_mode==Node.PROCESS_MODE_INHERIT,"later defeat cannot promote prior-frame zero-position hurt")
	var ambient_id:int=host.audio.ambient.get_instance_id()
	var snapshot:Array=host.bus.event_history.duplicate(true)
	host._audio_feedback.retire_room(host.audio)
	check(existing.is_queued_for_deletion() and modal.is_queued_for_deletion() and unrelated.is_queued_for_deletion(),"room retirement clears all old spatial one-shots")
	check(host.audio.ambient.get_instance_id()==ambient_id and not host.audio.ambient.is_queued_for_deletion(),"room retirement preserves ambience player")
	check(host.bus.event_history==snapshot,"modal lifecycle does not fabricate noise events")
	await process_frame
	host.free();paused=false;AudioServer.set_bus_mute(0,false)
	await process_frame
	await create_timer(0.25,true).timeout
	var report:=result_rows("Headless key routing and lifecycle contract. Dummy players verify selective promotion, same-frame freshness and retirement. Native probe separately verifies playback. No runtime/source writes.")
	write_report(report,"contract_%dhz.json"%hz)
	print("NOV6_AUDIO_CONTRACT_RESULT "+JSON.stringify(report))
	quit(0 if report.passed else 1)
