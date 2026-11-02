extends SceneTree
## Run only with a temporary XDG_DATA_HOME; never against a player's real save.
const SAVE="user://moksha_five_levels_v1.json"
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	var isolated_root:=OS.get_environment("XDG_DATA_HOME").simplify_path()
	if not "--isolated-save-tests" in OS.get_cmdline_user_args() or OS.get_environment("MOKSHA_QUALITY_ISOLATED")!="1" or not isolated_root.is_absolute_path() or isolated_root=="/" or not OS.get_user_data_dir().simplify_path().begins_with(isolated_root+"/"):
		push_error("Requires runner isolation marker, --isolated-save-tests and isolated XDG_DATA_HOME owning user_data_dir");quit(2);return
	call_deferred("run")
func write_raw(value:Variant)->void:
	var file:=FileAccess.open(SAVE,FileAccess.WRITE);file.store_string(JSON.stringify(value));file.close()
func run()->void:
	var original:Variant=FileAccess.get_file_as_bytes(SAVE) if FileAccess.file_exists(SAVE) else null
	var pending_original:Variant=FileAccess.get_file_as_bytes(SAVE+".pending") if FileAccess.file_exists(SAVE+".pending") else null
	var m=load("res://campaign/campaign.tscn").instantiate();m.save_enabled=false;root.add_child(m)
	m.start_new(true);paused=true;m.save_enabled=true;m._save_checkpoint();m.save_enabled=false
	var valid=JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	check(m._read_checkpoint().get("ok",false),"baseline checkpoint decodes")
	var cases:Array=[]
	for value in [null,[],"not an object",false]:cases.append({"label":"root "+str(value),"value":value})
	for field in ["campaign_version","progress","lens","upgrades","rewards"]:
		var value:Dictionary=valid.duplicate(true);value.erase(field);cases.append({"label":"missing "+field,"value":value})
	var mutations={"campaign_version":[0,2,"1"],"lens":["",3,"wizard"],"upgrades":[{},null,["unknown"],["force","force","force","force","force"]],"rewards":[[],null,{"bad":"unknown"}],"level_seconds":[[],null,{"1":-1},{"1":"3"}],"level_receipts":[{},null,[null],[{"level":0,"active_seconds":0}],[{"level":6,"active_seconds":0}],[{"level":1,"active_seconds":-1}],[{"level":1,"active_seconds":"3"}]]}
	for field in mutations:
		for item in mutations[field]:
			var value:Dictionary=valid.duplicate(true);value[field]=item;cases.append({"label":field+"="+JSON.stringify(item),"value":value})
	var progress_mutations={"sector_id":["missing",null,0],"cache_ids":[{},["missing"],["rainline","rainline"]],"blind":["false",0],"kills":[-1,0.5,"1"],"deaths":[-1,0.5],"seconds":[-1,"1"],"metrics":[{},[{}],[{"area_id":"rainline","seconds":-1}]]}
	for field in progress_mutations:
		for item in progress_mutations[field]:
			var value:Dictionary=valid.duplicate(true);value.progress[field]=item;cases.append({"label":"progress."+field+"="+JSON.stringify(item),"value":value})
	var before={"sector":m.sector,"lens":m.lens,"upgrades":m.upgrades.duplicate(),"rewards":m.rewards.duplicate(),"health":m.health.current_health,"state":m.state}
	for case in cases:
		write_raw(case.value)
		check(not m._read_checkpoint().get("ok",false),"reject "+case.label)
		m.continue_run()
		check(before=={"sector":m.sector,"lens":m.lens,"upgrades":m.upgrades,"rewards":m.rewards,"health":m.health.current_health,"state":m.state},"rejected Continue is inert: "+case.label)
	for malformed in ["{", "", "{\"campaign_version\":1,", "[1,"]:
		var file:=FileAccess.open(SAVE,FileAccess.WRITE);file.store_string(malformed);file.close()
		check(not m._read_checkpoint().get("ok",false),"truncated JSON rejected")
	write_raw(valid)
	var pending:=FileAccess.open(SAVE+".pending",FileAccess.WRITE);pending.store_string("{interrupted write");pending.close()
	check(m._read_checkpoint().get("ok",false),"orphan partial pending file cannot shadow committed checkpoint")
	m.save_enabled=true;m._save_checkpoint();m.save_enabled=false
	check(m._read_checkpoint().get("ok",false) and not FileAccess.file_exists(SAVE+".pending"),"new atomic save replaces orphan pending and decodes")
	# Every authored district ID survives save/Continue; retry creates clean local goals.
	for i in m.sectors.size():
		m.load_sector(i);m.save_enabled=true;m._save_checkpoint();m.save_enabled=false
		check(m._read_checkpoint().get("sector",-1)==i,"stable district ID roundtrip "+m.sectors[i].id)
		# Dirty the live local state AFTER saving, then exercise real Continue.
		for goal in m.goals:goal.completed=true;m.completed_goals[goal.objective_id]=true
		m.continue_run()
		check(m.sector==i and m.state=="playing" and m.completed_goals.is_empty() and m.goals.all(func(goal):return not goal.completed),"Continue resets local objective state "+m.sectors[i].id)
	m.free()
	for pair in [[SAVE,original],[SAVE+".pending",pending_original]]:
		if pair[1]==null:DirAccess.remove_absolute(ProjectSettings.globalize_path(pair[0]))
		else:
			var restore:=FileAccess.open(pair[0],FileAccess.WRITE);restore.store_buffer(pair[1]);restore.close()
	print("STATE_SAVE_RESULT "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"malformed_cases":cases.size(),"district_roundtrips":32,"failures":failures,"scope":"Isolated save corruption and scene fixtures; not full gameplay traversal or filesystem power-loss simulation."}))
	quit(0 if failures.is_empty() else 1)
