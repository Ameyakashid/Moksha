extends SceneTree
var fails:Array[String]=[]
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	var isolated:=OS.get_environment("XDG_DATA_HOME").simplify_path()
	if not "--isolated-save-tests" in OS.get_cmdline_user_args() or OS.get_environment("MOKSHA_QUALITY_ISOLATED")!="1" or not isolated.is_absolute_path() or isolated=="/" or not OS.get_user_data_dir().simplify_path().begins_with(isolated+"/"):
		push_error("Requires isolated runner marker, owned XDG_DATA_HOME and --isolated-save-tests");quit(2);return
	call_deferred("run")
func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:fails.append(label)
func host()->Node:
	var m=load("res://campaign/campaign.tscn").instantiate();m.save_enabled=true;root.add_child(m);return m
func key(m:Node,k:int)->void:
	var e:=InputEventKey.new();e.physical_keycode=k;e.pressed=true;m._unhandled_key_input(e)
func run()->void:
	var m=host();m.save_enabled=true;m.lens="agility";m.start_new(true)
	for d in m.sectors:
		for h in d.get("hazards",[]):
			var spawn:Vector2=d.get("spawn",Vector2(75,300))
			check(absf(h.at.x-spawn.x)-h.size.x/2>70,d.id+" hazard safe spawn staging")
	var boundary:=0
	while boundary+1<m.sectors.size() and m.sectors[boundary+1].level==1:boundary+=1
	m.load_sector(boundary)
	for g in m.goals:g.completed=true
	m.relay_on=true;m.room.gate_open=true
	m.player.position=Vector2(float(m.sectors[boundary].width)-45,float(m.sectors[boundary].get("gate_y",300)))
	m.interact();key(m,KEY_K);m._physics_process(1.0/60)
	var next:int=m.sector;var saved=m._read_checkpoint()
	check(saved.get("ok",false) and saved.sector==next and saved.campaign.upgrades==["agility"],"upgrade and next district committed together after transition")
	var speed:float=m.player.profile.run_speed;m.free()
	m=host();check(m.continue_available,"fresh host offers Continue")
	if not m.continue_available:
		m.free();print("SAVE_FAILURES "+JSON.stringify(fails));quit(1);return
	m.continue_run()
	check(is_instance_valid(m.player),"fresh Continue creates player")
	if not is_instance_valid(m.player):
		m.free();print("SAVE_FAILURES "+JSON.stringify(fails));quit(1);return
	check(m.sector==next and m.lens=="agility" and m.upgrades==["agility"] and is_equal_approx(m.player.profile.run_speed,speed),"fresh Continue restores build and district")
	m.save_enabled=true
	var deaths:int=m.deaths
	m.player.receive_hit({"amount":1000.0,"impulse":Vector2.ZERO})
	check(m.state=="dead" and m.deaths==deaths+1 and m.player.get_node("DefeatResponse").active,"real fatal damage sets one death and defeat lease")
	key(m,KEY_R);m._physics_process(1.0/60)
	check(m.state=="playing" and is_equal_approx(m.health.current_health,m.health.capacity) and m.upgrades==["agility"],"retry restores health and retains build")
	saved=m._read_checkpoint();check(saved.get("ok",false) and saved.deaths==deaths+1,"retry commits death count")
	m.load_sector(m.sectors.size()-1)
	for g in m.goals:g.completed=true
	m.room.gate_open=true;m.player.position=Vector2(float(m.sectors.back().width)-45,float(m.sectors.back().get("gate_y",300)))
	m.interact();check(m.state=="final_choice","final district reaches explicit choice")
	key(m,KEY_J);check(m.state=="complete" and m.campaign_ending=="public_record","choice completes outcome")
	check(m._completion_error.is_empty(),"completion write succeeds")
	var record_path:String=m.history_path.path_join("completed/"+m.run_id+".json")
	var result:Variant=JSON.parse_string(FileAccess.get_file_as_string(record_path)) if FileAccess.file_exists(record_path) else null
	check(result is Dictionary and result.ending=="public_record","immutable keyed result saved separately")
	if not result is Dictionary:
		m.free();print("SAVE_FAILURES "+JSON.stringify(fails));quit(1);return
	var result_hash:=FileAccess.get_sha256(record_path)
	var run_identity:String=m.run_id
	saved=m._read_checkpoint();check(saved.get("ok",false) and saved.has("terminal_record") and saved.campaign.run_status=="completed","completion retains terminal checkpoint plus immutable record")
	m.free();m=host()
	check(not m.continue_available and not m.last_result.is_empty(),"fresh host offers result rather than replay")
	key(m,KEY_C)
	check(m.state=="complete" and m._reviewing_result and not is_instance_valid(m.room) and m.last_result.run_id==run_identity,"fresh C reviews completed result without room load")
	check(FileAccess.get_sha256(record_path)==result_hash,"read-only review preserves immutable result")
	m.start_new(true)
	check(m.rewards.is_empty() and m.upgrades.is_empty() and m.deaths==0,"new run clears run progression")
	check(m.run_id!=run_identity and FileAccess.get_sha256(record_path)==result_hash,"new run retains immutable prior result and uses new identity")
	m.free()
	print("SAVE_FAILURES "+JSON.stringify(fails));quit(0 if fails.is_empty() else 1)
