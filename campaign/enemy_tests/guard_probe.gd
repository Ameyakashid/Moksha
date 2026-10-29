extends SceneTree
func _initialize()->void: run.call_deferred()
func frames(n:int)->void:
	for i in n: await physics_frame; await process_frame
func run()->void:
	var host=load("res://campaign/campaign.tscn").instantiate();root.add_child(host);host.save_enabled=false;host.start_new(true);host.input_override={}
	var ix=0
	for i in host.sectors.size():
		if host.sectors[i].id=="quarantine_intake":ix=i
	host.load_sector(ix)
	print("PROPOSED REBIND PROBE ",host.player.get_node("BodyShape/IncomingStrikeReceiver").bind(host.player))
	for e in host.enemies:e.ai_enabled=false
	await frames(5)
	var npc=host.enemies[-1]
	host.player.reset_actor(npc.position-Vector2(36,0),1);await frames(3);host.input_override={"shield":true};await frames(30);npc.ai_enabled=true
	npc.attack_resolved.connect(func(_e,r):print("RESULT ",r))
	host.player.get_node("BodyShape/IncomingStrikeReceiver").strike_resolved.connect(func(r):print("RAW ",r))
	for i in 240:
		await frames(1)
		if i%30==0:print("STATE ",npc.position," ",npc.ai_state," pc=",host.player.position," ",host.player.shield_phase," hp=",host.health.current_health," npc result=",npc.last_attack_result," state=",host.state)
	quit()
