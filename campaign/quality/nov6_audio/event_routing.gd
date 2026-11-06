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
static func report_output_allowed(path:String,project_root:String)->bool:
	# Exported PCKs have no physical res:// root. An empty root must not
	# accidentally classify every absolute path as inside the source tree.
	if path.begins_with("res://") or not (path.begins_with("user://") or path.is_absolute_path()):return false
	var absolute:=ProjectSettings.globalize_path(path).simplify_path()
	if project_root.is_empty():return true
	var normalized_root:=project_root.simplify_path()
	if normalized_root=="/":return false
	normalized_root=normalized_root.trim_suffix("/")
	return absolute!=normalized_root and not absolute.begins_with(normalized_root+"/")
func write_report(report:Dictionary,default_name:String)->void:
	var path:=output_path if not output_path.is_empty() else "user://nov6_audio/"+default_name
	# Reports may go to user data or an explicitly requested absolute path,
	# never res:// or anywhere inside this project's source directory.
	var absolute:=ProjectSettings.globalize_path(path).simplify_path()
	var project_root:=ProjectSettings.globalize_path("res://")
	if not report_output_allowed(path,project_root):
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
func check(ok:bool,label:String):checks.append({"label":label,"passed":ok});print("PASS " if ok else "FAIL ",label)
func key(k:int):
	var event:=InputEventKey.new();event.physical_keycode=k;event.pressed=true;host._unhandled_key_input(event)
func run():
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true)
	host.set_physics_process(false);host.set_process(false)
	var routes={"weapon_tap":"tap","enemy_windup":"guard_draw","enemy_damage":"hit","enemy_death":"hit","parry":"hit","guard":"hit","player_damage":"hurt","attack":"swing","swing":"swing","enemy_attack":"swing","prop_impact":"prop","prop_break":"prop","prop_launch":"prop","landing":"prop","jump":"jump","air_jump":"jump","roll":"dash","footstep":"step","enemy_step":"step","lift_motor":"step"}
	for kind in routes:
		var origin:Vector2=host.player.global_position+Vector2(17,-23)
		host.bus.emit_noise(origin,StringName(kind),1,host.player)
		check(host.audio.last_spatial_sound.key==routes[kind] and host.audio.last_spatial_sound.origin==origin,"schema "+kind+" -> "+routes[kind]+" at committed origin")
	var before:Dictionary=host.audio.last_spatial_sound.duplicate(true)
	var external=Node.new();root.add_child(external)
	host.bus.emit_noise(Vector2.ZERO,&"weapon_tap",1,external)
	check(host.audio.last_spatial_sound==before,"unrelated-room source rejected")
	host.bus.emit_noise(Vector2.ZERO,&"weapon_tap",1,null)
	check(host.audio.last_spatial_sound==before,"missing source rejected")
	var old_room=host.room
	host.remove_child(old_room);root.add_child(old_room);host.room=null
	host.load_sector(1);host.set_physics_process(false)
	before=host.audio.last_spatial_sound.duplicate(true)
	host.bus.emit_noise(Vector2.ZERO,&"weapon_tap",1,old_room)
	check(host.audio.last_spatial_sound==before,"retained old room rejected after replacement")
	old_room.free();external.free()
	var kinds={}
	for index in range(host.sectors.size()):
		host.load_sector(index);host.set_physics_process(false);host.set_process(false)
		var entry={"enemies":host.enemies.size(),"props":host.sectors[index].props.size(),"hazards":host.sectors[index].get("hazards",[]).size()}
		kinds[str(host.sectors[index].id)]=entry
	host.free();paused=false
	await process_frame
	await create_timer(0.25,true).timeout
	var report:=result_rows("Headless exact event-to-cue/origin schema and stale-source rejection. Explicit injected NoiseBus requests, not physical gameplay or audible-output evidence. No runtime/source writes.")
	report.authored_counts=kinds
	write_report(report,"routing_%dhz.json"%hz)
	print("NOV6_AUDIO_ROUTING_RESULT "+JSON.stringify(report))
	quit(0 if report.passed else 1)
