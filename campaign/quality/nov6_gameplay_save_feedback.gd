extends SceneTree
## Isolated filesystem failure fixtures. Never run on a player's real saves.
const SAVE="user://moksha_five_levels_v1.json"
var failures:Array[String]=[]
var checks:=0
var host:Node
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	var isolated:=OS.get_environment("XDG_DATA_HOME").simplify_path()
	if not "--isolated-save-tests" in OS.get_cmdline_user_args() or OS.get_environment("MOKSHA_QUALITY_ISOLATED")!="1" or not isolated.is_absolute_path() or isolated=="/" or not OS.get_user_data_dir().simplify_path().begins_with(isolated+"/"):
		push_error("Requires isolated runner marker, owned XDG_DATA_HOME and --isolated-save-tests");quit(2);return
	run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:int)->void:
	for index in count:await physics_frame;await process_frame
func write_text(path:String,text:String)->void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(text);file.close()
func run()->void:
	var original:Variant=FileAccess.get_file_as_bytes(SAVE) if FileAccess.file_exists(SAVE) else null
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host)
	host.save_enabled=true;host.start_new(true);host.input_override={};await frames(2)
	check(host._read_checkpoint().get("ok",false),"baseline checkpoint saves")
	var before:=FileAccess.get_sha256(SAVE)
	var pending:=ProjectSettings.globalize_path(SAVE+".pending")
	check(DirAccess.make_dir_absolute(pending)==OK,"write failure fixture occupies temporary checkpoint path")
	host._save_checkpoint()
	check(not host._checkpoint_write_error.is_empty() and host.notice.begins_with("CHECKPOINT NOT SAVED"),"write failure produces actionable live notice")
	check(FileAccess.get_sha256(SAVE)==before and host.continue_available,"failed write retains previous checkpoint and Continue")
	host.state="title";paused=true;await frames(2)
	var snapshot:Dictionary=host.hud.get_snapshot()
	check(snapshot.panel_title=="CHECKPOINT NOT UPDATED" and "previous successfully saved" in snapshot.panel_body,"write-error title survives real HUD snapshot pipeline")
	check(host.hud.get_node("View").data.panel_title==snapshot.panel_title,"write-error title reaches actual View")
	check(DirAccess.remove_absolute(pending)==OK,"write failure fixture releases temporary path")
	host.state="playing";paused=false;host._save_checkpoint()
	check(host._checkpoint_write_error.is_empty() and host._checkpoint_error.is_empty() and host._read_checkpoint().get("ok",false),"successful retry clears stale checkpoint errors")
	var valid_hash:=FileAccess.get_sha256(SAVE)
	host.metrics.append({"sector":-1,"seconds":0})
	host._save_checkpoint()
	check("encoded" in host._checkpoint_write_error and FileAccess.get_sha256(SAVE)==valid_hash,"encode rejection is visible and preserves committed progress")
	host.metrics.pop_back();host._save_checkpoint()
	check(host._checkpoint_write_error.is_empty(),"valid save clears encoding rejection")
	write_text(SAVE,"{truncated campaign checkpoint "+str(Time.get_ticks_usec()))
	var corrupt_hash:=FileAccess.get_sha256(SAVE)
	host.state="title";paused=true;host.continue_available=host._valid_save();await frames(2)
	snapshot=host.hud.get_snapshot()
	check(not host.continue_available and snapshot.panel_title=="CHECKPOINT UNAVAILABLE" and "has not been changed" in snapshot.panel_body,"corrupt checkpoint quietly explains unavailable Continue")
	var old_sector:int=host.sector
	host.continue_run()
	check(host.state=="title" and host.sector==old_sector and FileAccess.get_sha256(SAVE)==corrupt_hash,"rejected Continue is inert and leaves corrupt file untouched")
	host.start_new(true)
	var backup:String=host.history_path.path_join("preserved/checkpoint-before-new-"+corrupt_hash+".json")
	check(FileAccess.file_exists(backup) and FileAccess.get_sha256(backup)==corrupt_hash,"explicit New preserves exact corrupt original before replacement")
	check(host._read_checkpoint().get("ok",false) and host._checkpoint_write_error.is_empty(),"new campaign checkpoint is valid after verified preservation")
	write_text(SAVE,"{another invalid checkpoint "+str(Time.get_ticks_usec()))
	var conflicted:=FileAccess.get_sha256(SAVE)
	write_text(SAVE+".preserved-"+conflicted+".json","not the original")
	host._save_checkpoint()
	check(FileAccess.get_sha256(SAVE)==conflicted and not host.continue_available and "verified" in host._checkpoint_write_error,"unverified backup fails closed without replacing original")
	host.state="title";paused=true
	var layout:Dictionary=host.hud.get_node("View").panel_layout(host._hud_snapshot().panel_title,host._hud_snapshot().panel_body,host._hud_snapshot().panel_footer)
	check(layout.body_top+layout.body_lines.size()*(layout.body_size+3)<=276,"checkpoint error prose fits title panel")
	print("NOV6_GAMEPLAY_SAVE_FEEDBACK_RESULT "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"hz":Engine.physics_ticks_per_second,"failures":failures,"scope":"Isolated write/backup failure fixtures and actual HUD data pipeline; not OS power-loss or disk-exhaustion simulation."}))
	host.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE+".preserved-"+conflicted+".json"))
	if original==null:DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	else:
		var restore:=FileAccess.open(SAVE,FileAccess.WRITE);restore.store_buffer(original);restore.close()
	quit(0 if failures.is_empty() else 1)
