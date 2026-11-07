extends SceneTree
var fails:Array[String]=[]
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	call_deferred("run")
func check(ok:bool,label:String)->void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok:fails.append(label)
func host()->Node:
	var m=load("res://campaign/campaign.tscn").instantiate();m.save_enabled=false;root.add_child(m);return m
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
	m=host();check(m.continue_available,"fresh host offers Continue");m.continue_run()
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
	var result=JSON.parse_string(FileAccess.get_file_as_string("user://moksha_five_levels_results.json"))
	check(result is Dictionary and result.ending=="public_record","result outcome saved separately")
	saved=m._read_checkpoint();check(saved.get("ok",false) and saved.sector==m.sectors.size()-1,"completion retains replayable final-district checkpoint")
	m.free();m=host();m.continue_run()
	check(m.state=="playing" and m.sector==m.sectors.size()-1,"fresh Continue replays final district (not ending resume)")
	m.save_enabled=false;m.start_new(true)
	check(m.rewards.is_empty() and m.upgrades.is_empty() and m.deaths==0,"new run clears run progression")
	check(FileAccess.file_exists("user://moksha_five_levels_results.json"),"new run retains previous result file")
	print("SAVE_FAILURES "+JSON.stringify(fails));quit(0 if fails.is_empty() else 1)
