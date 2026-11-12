extends SceneTree
## Explicitly seeded lifecycle/choice fixtures, NOT earned campaign traversal.
const Codec=preload("res://campaign/logic/checkpoint_codec.gd")
const Store=preload("res://campaign/save/checkpoint_store.gd")
const Sense=preload("res://campaign/state/sense_state.gd")
var host:Node
var base:=""
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func key(code:int)->void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=true;host._unhandled_key_input(e)
func make_host(name_:String,save:=true)->void:
	if is_instance_valid(host):host.free();await process_frame
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false
	host.campaign_save_path=base.path_join(name_+".json");host.history_path=base.path_join(name_+"-history");host.legacy_results_path=base.path_join(name_+"-old.json")
	root.add_child(host);host.save_enabled=save
	host.start_new(true);host.set_physics_process(false)
func seed_offer()->void:
	var last:=0
	for i in host.sectors.size():
		if int(host.sectors[i].level)==1:last=i
	host.load_sector(last);host.set_physics_process(false)
	host._level_transition_snapshot={"to":last+1,"metrics":host.metrics.size(),"receipts":host.level_receipts.size(),"upgrades":host.upgrades.size()}
	host.metrics.append({"sector":last,"seconds":1.0,"blind":host.blind,"health":host.health.current_health})
	host.level_receipts.append({"level":1,"active_seconds":1.0,"completed_district":host.sectors[last].id})
	host.state="upgrade";paused=true;key(KEY_J)
func run()->void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--root="):base=a.trim_prefix("--root=")
	if not base.is_absolute_path() or base.begins_with(ProjectSettings.globalize_path("res://")) or DirAccess.dir_exists_absolute(base) or FileAccess.file_exists(base):quit(2);return
	DirAccess.make_dir_recursive_absolute(base)
	await make_host("trade")
	check(host.hearing_retained and host.sense_capabilities().hearing,"New retains hearing")
	check(Store.read(host.campaign_save_path,host.sectors).campaign.campaign_version==3,"New checkpoint explicitly v3")
	seed_offer()
	check(host.state=="hearing_choice" and paused,"separate hearing dialog follows normal upgrade")
	var bytes:=FileAccess.get_sha256(host.campaign_save_path)
	var live_metrics=host.metrics.duplicate(true);var live_upgrades=host.upgrades.duplicate();var hp:float=host.health.current_health
	DirAccess.make_dir_absolute(host.campaign_save_path+".pending")
	key(KEY_J)
	check(host.hearing_retained and host.state=="hearing_choice" and paused,"failed disk commit leaves live choice unchanged")
	check(FileAccess.get_sha256(host.campaign_save_path)==bytes,"failed trade preserves old checkpoint bytes")
	check(host.metrics==live_metrics and host.upgrades==live_upgrades and host.health.current_health==hp,"failed trade changes no metrics upgrades or health")
	DirAccess.remove_absolute(host.campaign_save_path+".pending")
	# Seed old hearing traces: acceptance must retire them, not wait for fade.
	host.sonar.event_history.append({"fixture":true});host.sonar.pulses.append({"fixture":true})
	key(KEY_J)
	check(not host.hearing_retained and host.sense_capabilities().focus,"successful explicit choice activates FOCUS")
	check(host.health.current_health==hp,"choice has no healing bonus")
	check(host.metrics==live_metrics and host.upgrades==live_upgrades,"retrying save did not duplicate receipt or upgrade")
	check(host.sonar.pulses.is_empty() and host.sonar.event_history.is_empty() and not host.sonar.hearing_enabled,"choice clears prior sonar intake/history")
	var saved:=Store.read(host.campaign_save_path,host.sectors)
	check(saved.ok and saved.campaign.senses.hearing=="traded" and saved.sector==host.sector+1,"committed choice resumes at onward district")
	var target_sector:int=host.sector+1
	host._on_window_focus_exited();key(KEY_R)
	check(host._pending_sector==target_sector and not host._pending_retry and host.metrics==live_metrics and host.upgrades==live_upgrades,"focus-loss retry resumes committed destination without rollback")
	host._on_window_focus_exited();key(KEY_N)
	check(host.state=="title" and Store.read(host.campaign_save_path,host.sectors).sector==target_sector,"focus-loss Title preserves committed onward checkpoint")
	host.choose_sight(false);check(host.state=="title","out-of-state sight call cannot mutate title")
	host.continue_run();host.set_physics_process(false)
	check(host.sector==target_sector and host.metrics==live_metrics and host.upgrades==live_upgrades,"Continue after interrupted transition retains exact progress")
	check(not host.hearing_retained and not host.audio.hearing_enabled and not host.sonar.hearing_enabled,"Continue restores sensory cost")
	var sector:int=host.sector;host.load_sector(sector)
	check(not host.hearing_retained,"retry preserves hearing choice")
	host.state="choice";paused=true;host.choose_sight(true)
	check(not host.blind and not host.hearing_retained,"temporary second-loss UI restriction cannot restore hearing")
	host.start_new(true);host.set_physics_process(false)
	check(host.hearing_retained and host.audio.hearing_enabled and host.sonar.hearing_enabled,"New resets senses and listener gates")
	seed_offer();key(KEY_K)
	check(host.hearing_retained and host.state=="transition" and not paused,"decline keeps all senses and onward progression")
	check(host.gamepad_navigation._command_key("hearing_choice",JOY_BUTTON_X,"neutral")==KEY_J and host.gamepad_navigation._command_key("hearing_choice",JOY_BUTTON_B,"neutral")==KEY_K,"controller accept/decline mapping")
	# Migration uses genuine schema-shaped saved data, but this is not an earned run.
	for version in [1,2]:
		await make_host("migration%d"%version)
		var legacy:Dictionary=host._checkpoint_payload();legacy.campaign_version=version;legacy.erase("senses")
		if version==1:
			for field in ["run_id","run_status","run_origin"]:legacy.erase(field)
		var old_id:String=host.run_id
		check(Store.commit(host.campaign_save_path,legacy).ok,"legacy fixture written")
		var legacy_hash:=FileAccess.get_sha256(host.campaign_save_path)
		var generation:int=host.session_generation
		DirAccess.make_dir_absolute(host.campaign_save_path+".pending")
		host.continue_run();host.set_physics_process(false)
		check(FileAccess.get_sha256(host.campaign_save_path)==legacy_hash and host.session_generation==generation,"failed migration leaves bytes and live session unchanged")
		DirAccess.remove_absolute(host.campaign_save_path+".pending")
		host.continue_run();host.set_physics_process(false)
		var migrated:=Store.read(host.campaign_save_path,host.sectors)
		check(migrated.ok and migrated.campaign.campaign_version==3 and host.hearing_retained,"legacy Continue migrates to retained hearing")
		check(host.run_id==old_id if version==2 else host.run_id!=old_id,"v2 preserves identity; v1 allocates identity")
		var found:=false
		for file in DirAccess.get_files_at(host.history_path.path_join("preserved")):
			if FileAccess.get_sha256(host.history_path.path_join("preserved").path_join(file))==legacy_hash:found=true
		check(found,"exact legacy checkpoint bytes preserved before replacement")
	# Known dual-loss data is representable and applied honestly, despite UI scope.
	var dual:Dictionary=host._checkpoint_payload();dual.progress.blind=true;dual.senses=Sense.create(true,false)
	check(Codec.decode(dual,host.sectors).ok,"schema supports known dual-loss combination")
	Store.commit(host.campaign_save_path,dual);host.continue_run();host.set_physics_process(false)
	check(host.blind and not host.hearing_retained and not host.sense_capabilities().focus and not host.sonar.hearing_enabled,"loaded dual loss never silently restores hearing/sonar")
	await make_host("nosave",false);seed_offer();key(KEY_J)
	check(not host.hearing_retained and not FileAccess.file_exists(host.campaign_save_path) and not DirAccess.dir_exists_absolute(host.history_path),"no-save choice remains disk-free")
	# UI layout/semantic fixtures and versioned completion, not earned endings.
	paused=false
	host.state="hearing_choice"
	var panel:Dictionary=host._hud_snapshot()
	var layout:Dictionary=host.hud.get_node("View").panel_layout(panel.panel_title,panel.panel_body,panel.panel_footer)
	check(layout.body_top+layout.body_lines.size()*(layout.body_size+3)<=287,"hearing choice prose fits existing panel")
	host.state="playing";host.load_sector(host._committed_hearing_sector);host.load_sector(host.sectors.size()-1);host.campaign_ending="public_record";host.complete_run()
	check(host.completion_record.schema_version==2 and host.completion_record.result.senses.hearing=="traded","new completion captures versioned hearing facts")
	check(host._validated_terminal(host.completion_record),"new completion agrees with v3 snapshot")
	var legacy_record:Dictionary=host.completion_record.duplicate(true)
	legacy_record.schema_version=1;legacy_record.snapshot.campaign_version=2;legacy_record.snapshot.erase("senses");legacy_record.result.erase("senses")
	check(host._validated_terminal(legacy_record),"legacy schema1 terminal review remains valid without invented senses")
	host.last_result=legacy_record;host.view_last_result()
	check(not host._hud_snapshot().panel_body.contains("FOCUS specialization"),"legacy result does not invent focus history")
	host.free();host=null;paused=false;await process_frame
	print(JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"seeded host lifecycle fixtures"}))
	quit(0 if failures.is_empty() else 1)
