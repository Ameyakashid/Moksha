extends SceneTree
## Seeded storage/lifecycle fixtures, not earned campaign play. External fresh root only.
const Store=preload("res://campaign/save/checkpoint_store.gd")
const Codec=preload("res://campaign/logic/checkpoint_codec.gd")
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
func make_host(name_:String)->void:
	if is_instance_valid(host):host.free();await process_frame
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false
	host.campaign_save_path=base.path_join(name_+".json");host.history_path=base.path_join(name_+"-history");host.legacy_results_path=base.path_join(name_+"-old.json")
	root.add_child(host);host.save_enabled=true;host.start_new(true);host.set_physics_process(false)
func seed_offer()->void:
	var last:=0
	for i in host.sectors.size():
		if int(host.sectors[i].level)==3:last=i
	host.load_sector(last);host.set_physics_process(false)
	host._level_transition_snapshot={"to":last+1,"metrics":host.metrics.size(),"receipts":host.level_receipts.size(),"upgrades":host.upgrades.size()}
	host.metrics.append({"sector":last,"seconds":1.0,"blind":host.blind,"health":host.health.current_health})
	host.level_receipts.append({"level":3,"active_seconds":1.0,"completed_district":host.sectors[last].id})
	host.state="upgrade";paused=true;key(KEY_J)
static func root_location_allowed(candidate:String,resource_root:String)->bool:
	# Packed res:// may have no filesystem root. Empty is not a parent directory.
	return candidate.is_absolute_path() and (resource_root.is_empty() or not candidate.begins_with(resource_root))
func run()->void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--root="):base=a.trim_prefix("--root=")
	if not root_location_allowed(base,ProjectSettings.globalize_path("res://")) or DirAccess.dir_exists_absolute(base) or FileAccess.file_exists(base):quit(2);return
	DirAccess.make_dir_recursive_absolute(base)
	await make_host("trade")
	check(host.smell_retained and host.scent.enabled and host.player.irritant_snapshot().susceptible,"New retains scent and susceptibility")
	check(Store.read(host.campaign_save_path,host.sectors).campaign.campaign_version==4,"New explicit checkpoint4")
	seed_offer();check(host.state=="smell_choice" and paused,"Level3 upgrade opens separate optional smell offer")
	var before:=FileAccess.get_sha256(host.campaign_save_path)
	var metrics:Array=host.metrics.duplicate(true);var upgrades:Array=host.upgrades.duplicate();var hp:float=host.health.current_health;var id:String=host.run_id
	DirAccess.make_dir_absolute(host.campaign_save_path+".pending");key(KEY_J)
	check(host.smell_retained and host.state=="smell_choice" and paused,"failed pending write leaves offered state")
	check(FileAccess.get_sha256(host.campaign_save_path)==before,"failed write preserves previous bytes")
	check(host.metrics==metrics and host.upgrades==upgrades and host.health.current_health==hp,"failed choice does not duplicate upgrade or change HP")
	DirAccess.remove_absolute(host.campaign_save_path+".pending")
	host.scent.snapshot.append({"fixture":true})
	key(KEY_J)
	check(not host.smell_retained and not host.scent.enabled and host.scent.snapshot.is_empty() and host.scent.read_snapshot().is_empty(),"successful trade immediately retires scent")
	check(not host.player.irritant_snapshot().susceptible and host.health.current_health==hp,"reward only susceptibility, no healing")
	check(host.hearing_retained and not host.blind,"other senses unchanged")
	check(not host.scent.presentation_allowed() and not host.scent.view.allowed.call(),"draw-time callable rejects stale scent immediately after trade")
	check(host.hud.set_snapshot(host._hud_snapshot()),"real owner accepts campaign smell snapshot")
	check(host.hud._snapshot.get("smell_retained",true)==false,"typed owner preserves smell loss to painter boundary")
	var owner_before:Dictionary=host.hud._snapshot.duplicate(true)
	check(not host.hud.set_snapshot({"smell_retained":"traded"}) and host.hud._snapshot==owner_before,"invalid smell owner input is atomic")
	check(host.hud.set_snapshot({}) and host.hud._snapshot.get("smell_retained",false),"omitted smell owner input resets retained default")
	var saved:=Store.read(host.campaign_save_path,host.sectors);var onward:int=host.sector+1
	check(saved.ok and saved.campaign.senses.smell=="traded" and saved.sector==onward and saved.campaign.run_id==id,"detached committed onward choice has correct identity")
	check(not host.choose_smell(true),"repeated accept cannot apply twice")
	DirAccess.copy_absolute(host.campaign_save_path,base.path_join("fresh.json"))
	var fresh:=FileAccess.open(base.path_join("FRESH_EXPECTED.json"),FileAccess.WRITE);fresh.store_string(JSON.stringify({"run_id":id,"sector":onward,"metrics":metrics,"upgrades":upgrades,"checkpoint_sha256":FileAccess.get_sha256(base.path_join("fresh.json"))}));fresh.close()
	host._on_window_focus_exited();key(KEY_R)
	check(host._pending_sector==onward and not host._pending_retry,"focus retry respects already committed onward sector")
	host._on_window_focus_exited();key(KEY_N)
	check(Store.read(host.campaign_save_path,host.sectors).sector==onward,"Title cannot overwrite committed choice with previous sector")
	host.continue_run();host.set_physics_process(false)
	check(host.sector==onward and host.run_id==id and host.metrics==metrics and host.upgrades==upgrades,"Continue retains IDs/receipts and destination")
	check(not host.smell_retained and not host.scent.enabled and not host.player.irritant_snapshot().susceptible,"Continue reapplies loss/reward")
	host.load_sector(onward);check(not host.player.irritant_snapshot().susceptible,"retry new actor retains immunity")
	host.start_new(true);host.set_physics_process(false)
	check(host.smell_retained and host.scent.enabled and host.player.irritant_snapshot().susceptible,"New resets scent/reward")
	seed_offer();key(KEY_K)
	check(host.smell_retained and host.state=="transition" and not paused,"decline remains a normal onward path")
	var declined_upgrades:Array=host.upgrades.duplicate();var declined_receipts:Array=JSON.parse_string(JSON.stringify(host.level_receipts))
	var declined_id:String=host.run_id;var declined_next:int=host._pending_sector
	host.set_physics_process(true)
	await physics_frame;await process_frame;await physics_frame;await process_frame
	host.set_physics_process(false);host.show_title();host.continue_run();host.set_physics_process(false)
	check(host.sector==declined_next and host.run_id==declined_id and host.upgrades==declined_upgrades and host.level_receipts==declined_receipts,"decline load/Title/Continue preserves exactly one upgrade and receipt")
	check(host.smell_retained and host.scent.enabled and host.player.irritant_snapshot().susceptible,"decline resumed actor retains scent and susceptibility")
	check(host.gamepad_navigation._command_key("smell_choice",JOY_BUTTON_X,"neutral")==KEY_J and host.gamepad_navigation._command_key("smell_choice",JOY_BUTTON_B,"neutral")==KEY_K,"gamepad choice mapping")
	for mode in ["blind","deaf"]:
		await make_host("combination-"+mode)
		host.blind=mode=="blind";host.hearing_retained=mode!="deaf";host._apply_senses()
		seed_offer();key(KEY_J);host.load_sector(host._committed_sense_sector);host.show_title();host.continue_run();host.set_physics_process(false)
		var caps:Dictionary=host.sense_capabilities()
		check(not host.smell_retained and not host.scent.enabled and not host.player.irritant_snapshot().susceptible,"combined loss real host resume retains earned smell reward")
		check(host.blind==(mode=="blind") and host.hearing_retained==(mode!="deaf"),"combined host resume never restores other sense")
		check(caps.sonar==(mode!="deaf") and host.audio.hearing_enabled==(mode!="deaf") and caps.focus==(mode=="deaf"),"combined loss preserves sonar/audio policy")
	await make_host("rename-failure");seed_offer()
	var genuine_path:String=host.campaign_save_path
	var genuine_sha:=FileAccess.get_sha256(genuine_path)
	# Directory destination first exercises host pre-commit preservation rejection.
	# The real fixture checkpoint is untouched at its original separate path.
	host.campaign_save_path=base.path_join("occupied-destination")
	DirAccess.make_dir_absolute(host.campaign_save_path)
	key(KEY_J)
	check(host.state=="smell_choice" and host.smell_retained and host.player.irritant_snapshot().susceptible,"invalid destination preservation failure leaves live choice unchanged")
	# Exercise disk owner final-rename branch directly: no synchronous host hook exists.
	var rename_payload:Dictionary=host._checkpoint_payload()
	rename_payload.senses=Sense.create(host.blind,host.hearing_retained,false)
	var rename_result:=Store.commit(host.campaign_save_path,rename_payload)
	check(not rename_result.ok and str(rename_result.error).contains("committed"),"disk owner rejects final rename after successful staging")
	check(FileAccess.file_exists(host.campaign_save_path+".pending") and JSON.parse_string(FileAccess.get_file_as_string(host.campaign_save_path+".pending")).senses.smell=="traded","rename failure retains fully staged bytes")
	check(FileAccess.get_sha256(genuine_path)==genuine_sha,"rename failure leaves original fixture checkpoint byte-identical")
	host.campaign_save_path=genuine_path;key(KEY_J)
	check(not host.smell_retained and Store.read(genuine_path,host.sectors).campaign.senses.smell=="traded","explicit retry commits to restored valid destination")
	for version in [1,2,3]:
		await make_host("migration%d"%version)
		var legacy:Dictionary=host._checkpoint_payload();legacy.campaign_version=version
		if version<3:legacy.erase("senses")
		else:legacy.senses={"version":1,"sight":"retained","hearing":"traded"}
		if version==1:
			for field in ["run_id","run_status","run_origin"]:legacy.erase(field)
		var old_id:String=host.run_id;Store.commit(host.campaign_save_path,legacy)
		var old_hash:=FileAccess.get_sha256(host.campaign_save_path);var generation:int=host.session_generation
		DirAccess.make_dir_absolute(host.campaign_save_path+".pending");host.continue_run()
		check(FileAccess.get_sha256(host.campaign_save_path)==old_hash and host.session_generation==generation,"failed legacy migration leaves disk/live state")
		DirAccess.remove_absolute(host.campaign_save_path+".pending");host.continue_run();host.set_physics_process(false)
		var migrated:=Store.read(host.campaign_save_path,host.sectors)
		check(migrated.ok and migrated.campaign.campaign_version==4 and migrated.campaign.senses.version==2 and host.smell_retained,"legacy defaults smell retained")
		check(host.hearing_retained==(version<3),"legacy hearing fact preserved")
		check(host.run_id==old_id if version>=2 else host.run_id!=old_id,"legacy identity policy preserved")
		var found:=false
		for file in DirAccess.get_files_at(host.history_path.path_join("preserved")):
			if FileAccess.get_sha256(host.history_path.path_join("preserved").path_join(file))==old_hash:found=true
		check(found,"original legacy bytes backed up")
	await make_host("completion");seed_offer();key(KEY_J);host.load_sector(host._committed_sense_sector);host.load_sector(host.sectors.size()-1);host.campaign_ending="public_record";host.complete_run()
	check(host.completion_record.schema_version==3 and host.completion_record.result.senses.smell=="traded" and host._validated_terminal(host.completion_record),"completion3 records exact loss")
	var historic:Dictionary=host.completion_record.duplicate(true);historic.schema_version=2;historic.snapshot.campaign_version=3
	for values in [historic.snapshot.senses,historic.result.senses]:values.erase("smell");values.version=1
	check(host._validated_terminal(historic),"historic completion2 remains valid")
	historic.schema_version=1;historic.snapshot.campaign_version=2;historic.snapshot.erase("senses");historic.result.erase("senses")
	check(host._validated_terminal(historic),"historic completion1 remains valid")
	# Persist exact legacy documents, then exercise real history reconciliation/view.
	for legacy_version in [1,2]:
		var legacy_record:Dictionary=historic.duplicate(true)
		if legacy_version==2:
			legacy_record.schema_version=2;legacy_record.snapshot.campaign_version=3
			legacy_record.snapshot.senses={"version":1,"sight":"retained","hearing":"retained"}
			legacy_record.result.senses=legacy_record.snapshot.senses.duplicate(true)
		var directory:=base.path_join("historic%d/completed"%legacy_version)
		DirAccess.make_dir_recursive_absolute(directory)
		var path:=directory.path_join(str(legacy_record.run_id)+".json")
		var f:=FileAccess.open(path,FileAccess.WRITE);f.store_string(JSON.stringify(legacy_record,"  "));f.close()
		var digest:=FileAccess.get_sha256(path)
		host.completion_record.clear();host.last_result.clear();host.history_path=directory.get_base_dir()
		host._refresh_run_history();host.view_last_result()
		check(host.state=="complete" and host._reviewing_result and host.last_result==JSON.parse_string(FileAccess.get_file_as_string(path)),"actual legacy history file loads into read-only last result")
		check(FileAccess.get_sha256(path)==digest,"viewing legacy history preserves original bytes")
	print(JSON.stringify({"checks":checks,"failures":failures,"scope":"Seeded external-store lifecycle, not earned play"}))
	host.queue_free();paused=false;await process_frame;await process_frame;quit(1 if failures.size() else 0)
