extends "res://campaign/quality/nov6_transition_stress/transition_stress.gd"
## Actual title selection and four legal upgrade commits, with each completed
## exit initialized as a fixture. This is persistence evidence, not traversal.
var earned: Array[String] = []
var selected_lens := "neutral"
var expected_blind := false
func check_build(label: String) -> void:
	var speed := 1.0
	var force := 1.0
	var capacity := 60.0
	if selected_lens == "strength": speed = 0.94; force = 1.4; capacity = 75.0
	if selected_lens == "agility": speed = 1.12; capacity = 50.0
	for value in earned:
		if value == "force": force += 0.25
		if value == "agility": speed += 0.1
		if value == "vitality": capacity += 15.0
	var base_speed: float = load("res://combat_pc/resources/air_response_agile.tres").run_speed
	var base_damage: float = load("res://combat_pc/resources/responsive_chain.tres").steps[0].damage
	check(host.upgrades == earned, label + " exact earned upgrade sequence")
	check(host.lens == selected_lens and host.blind == expected_blind, label + " actual selected lens/sight retained")
	check(is_equal_approx(host.player.profile.run_speed, base_speed * (1.25 if expected_blind else 1.0) * speed), label + " additive speed from immutable base")
	check(is_equal_approx(host.player.melee_chain.steps[0].damage, base_damage * force), label + " additive damage from immutable base")
	check(is_equal_approx(host.health.capacity, capacity), label + " additive capacity from immutable base")
	check(host.metrics.size() == earned.size() and host.level_receipts.size() == earned.size(), label + " exactly one receipt per completed level fixture")
	var saved: Dictionary = host._decode_campaign_checkpoint()
	check(saved.get("ok",false) and saved.campaign.upgrades == earned and saved.campaign.level_receipts.size() == earned.size(), label + " exact earned upgrade checkpoint")
func modal_at_exit(index: int) -> void:
	host.load_sector(index)
	for enemy in host.enemies: enemy.queue_free()
	for goal in host.goals: goal.completed = true
	host.relay_on = true
	await tick(3)
	host._update_gate()
	var district: Dictionary = host.sectors[index]
	host.player.position = Vector2(float(district.width)-45,float(district.get("gate_y",300)))
	host.player.velocity = Vector2.ZERO
	key(KEY_E)
	check(host.state == "upgrade" and paused, "authored completed exit opens real upgrade")
func run() -> void:
	var root_path := OS.get_environment("XDG_DATA_HOME").simplify_path()
	if OS.get_environment("MOKSHA_QUALITY_ISOLATED") != "1" or root_path.is_empty() or not OS.get_user_data_dir().simplify_path().begins_with(root_path + "/"):
		printerr("REFUSED: isolated XDG save directory required"); quit(2); return
	host = load("res://campaign/campaign.tscn").instantiate(); root.add_child(host)
	host.set_process(false); host.set_physics_process(false)
	var combinations := [
		["force","force","force","force"],
		["agility","agility","agility","agility"],
		["vitality","vitality","vitality","vitality"],
		["force","agility","vitality","force"],
		["agility","vitality","force","agility"],
		["vitality","force","agility","vitality"]]
	for lens in ["neutral","strength","agility"]:
		for trade in [false,true]:
			for order in combinations:
				case_name = "cumulative_%s_%s_%s" % [lens,str(trade),"_".join(order)]
				trace.clear(); model.clear(); scenario_count += 1
				clear_devices(); host.show_title()
				key({"neutral":KEY_1,"strength":KEY_2,"agility":KEY_3}[lens]); key(KEY_ENTER); key(KEY_ENTER)
				selected_lens = lens; expected_blind = false; earned.clear()
				check_build("new title-selected campaign")
				for stage in 4:
					await modal_at_exit([5,11,17,24][stage])
					trace.append("choose " + order[stage])
					key({"force":KEY_J,"agility":KEY_K,"vitality":KEY_L}[order[stage]])
					# Duplicate choices and focus events occur before the queued
					# next-room load; only explicit resume may commit that load.
					key(KEY_J); key(KEY_K); key(KEY_L); root.focus_exited.emit()
					var old_sector: int = host.sector
					await tick(3)
					check(host.sector == old_sector and host.state == "paused", "queued cumulative upgrade stays suspended on focus loss")
					key(KEY_ESCAPE); await tick(3); earned.append(order[stage])
					check_build("committed level %d" % (stage+1))
					if stage == 0 and trade:
						host.player.position = host.sectors[host.sector].station
						host.player.velocity = Vector2.ZERO
						key(KEY_E); check(host.state == "choice", "real level-two exchange station opens sight choice")
						key(KEY_J); expected_blind = true
						check_build("real sight trade after level one")
					key(KEY_R); await tick(3); check_build("retry committed level")
					key(KEY_R); root.focus_exited.emit(); await tick(2); key(KEY_ESCAPE); await tick(3); check_build("focus-interrupted retry")
					key(KEY_ESCAPE); key(KEY_N); key(KEY_C); await tick(3); check_build("title Continue committed level")
					event_count += 18
					if not failures.is_empty(): break
				if not failures.is_empty(): break
				check(earned.size() == 4, "four and only four earned upgrades")
				# Fresh scene instance discovers the file rather than inheriting
				# in-memory build arrays from the previous campaign object.
				host.free(); paused = false
				host = load("res://campaign/campaign.tscn").instantiate(); root.add_child(host)
				host.set_process(false); host.set_physics_process(false)
				check(host.state == "title" and host.continue_available, "new host discovers committed checkpoint")
				key(KEY_C); await tick(3); check_build("fresh host Continue")
				key(KEY_ESCAPE); key(KEY_N); key(KEY_ENTER); key(KEY_ENTER)
				earned.clear(); expected_blind = false; check_build("explicit New clears prior upgrades and sight")
				if not failures.is_empty(): break
			if not failures.is_empty(): break
		if not failures.is_empty(): break
	var result := {"passed":failures.is_empty(),"checks":checks,"scenarios":scenario_count,"events":event_count,"failures":failures,"hz":hz,"scope":"36 title-selected lens/sight/upgrade-order cases. Four actual authored-exit upgrade commits per case; completed objectives/enemies and approach positions are declared fixtures, not traversals. Genuine sight choice starts in level-two Exchange. Repeated Retry, focus interruption, title Continue, fresh-host Continue and explicit New test exact accumulated build persistence."}
	if not output.is_empty():
		var file := FileAccess.open(output,FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(result,"\t")); file.close()
	print("CUMULATIVE_UPGRADE_RESULT " + JSON.stringify(result))
	clear_devices(); host.free(); quit(0 if failures.is_empty() else 1)
