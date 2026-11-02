extends SceneTree
## A bounded real-physics input replay. Only initial New/skip-intro is a fixture.
## No state, health, enemy or position writes occur during the measured trace.
var input_path := ""
var output_path := ""
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="): input_path = arg.trim_prefix("--input=")
		if arg.begins_with("--output="): output_path = arg.trim_prefix("--output=")
	run.call_deferred()
func vector(v: Vector2) -> Array:
	return [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001)]
func run() -> void:
	if not FileAccess.file_exists(input_path) or output_path.is_empty():
		push_error("Replay requires --input=<JSON> and --output=<JSON>"); quit(2); return
	var spec = JSON.parse_string(FileAccess.get_file_as_string(input_path))
	if not spec is Dictionary or not spec.get("frames") is Array:
		push_error("Invalid replay input"); quit(2); return
	Engine.physics_ticks_per_second = int(spec.hz)
	seed(int(spec.seed))
	var host = load("res://campaign/campaign.tscn").instantiate()
	root.add_child(host)
	host.save_enabled = false
	host.start_new(true)
	var trace: Array = []
	for tick in spec.frames.size():
		host.input_override = spec.frames[tick].duplicate()
		await physics_frame
		await process_frame
		var foes: Array = []
		for foe in host.enemies:
			if is_instance_valid(foe):
				foes.append({"position":vector(foe.position), "health":foe.health, "dead":foe.dead, "state":str(foe.ai_state)})
		trace.append({"tick":tick, "position":vector(host.player.position), "velocity":vector(host.player.velocity), "grounded":host.player.grounded, "action":str(host.player.main_action), "phase":str(host.player.action_phase), "weapon":str(host.player.weapon_phase), "shield":str(host.player.shield_phase), "health":host.health.current_health, "state":host.state, "sector":host.sector, "gate":host.room.gate_open, "kills":host.kills, "enemies":foes, "goals":host.completed_goals.duplicate()})
		# Death is a valid replay outcome; a paused tree must not hang awaiting physics.
		if host.state == "dead": break
	var report = {"engine":Engine.get_version_info().string, "seed":spec.seed, "hz":spec.hz, "requested_ticks":spec.frames.size(), "trace":trace, "input_sha256":FileAccess.get_sha256(input_path), "method":"Opening district New/skip-intro fixture; then recorded raw production input, live physics/enemies/damage. Quantized positions/velocities to 0.0001 units. Not a full route, balance acceptance, rendered FPS, or cross-platform determinism proof."}
	var file = FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write replay report"); quit(2); return
	file.store_string(JSON.stringify(report))
	file.close()
	print("REPLAY_RESULT ticks=",trace.size()," seed=",spec.seed)
	quit(0)
