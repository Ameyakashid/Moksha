extends SceneTree
## Warning provenance, expiry and real audio routing; audibility needs a device.
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)
func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame
func run() -> void:
	var game = load("res://arcology_run.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	for actor in get_nodes_in_group("actors"):
		if game.current_level.is_ancestor_of(actor): actor.simulation_enabled = false
	var guard = game.current_level.get_node("Actors/Enemies").get_child(0)
	var sonar = game.sonar
	sonar.set_process(false)
	sonar.set_blind(true)
	sonar.clear_pulses()
	var origin: Vector2 = guard.global_position + Vector2(-11,-28)
	guard.facing = -1
	root.get_node("NoiseBus").emit_noise(origin, &"enemy_windup", 0.85, guard)
	check(sonar.pulses.size() == 1, "one real guard draw creates one scoped pulse")
	var pulse: Dictionary = sonar.pulses[0]
	var mark: Dictionary = sonar.threat_mark(pulse)
	check(mark.origin == origin and mark.direction == -1 and mark.winding, "windup mark records actual emission origin and direction")
	check(sonar._label(&"enemy_windup") != sonar._label(&"enemy_attack"), "draw and strike labels are distinct")
	check(game.audio.last_spatial_sound.key == "guard_draw" and game.audio.last_spatial_sound.origin == origin, "guard draw routes dedicated sound at its own position")
	guard.facing = 1
	guard.global_position.x += 100
	check(sonar.threat_mark(pulse).origin == origin and sonar.threat_mark(pulse).direction == -1, "warning does not track a moving or turning guard after emission")
	sonar.advance_simulation(sonar.tuning.threat_warning_seconds + 0.01)
	check(sonar.threat_mark(pulse).is_empty(), "windup direction expires rather than permanently revealing a guard")
	var strike_origin: Vector2 = guard.global_position + Vector2(40,-25)
	root.get_node("NoiseBus").emit_noise(strike_origin, &"enemy_attack", 1.25, guard)
	var strike: Dictionary = sonar.pulses.back()
	check(not sonar.threat_mark(strike).winding and sonar.threat_mark(strike).direction == 1, "strike has a separate brief forward marker")
	check(game.audio.last_spatial_sound.key == "swing" and game.audio.last_spatial_sound.origin == strike_origin, "strike sound stays at the weapon contact origin")
	sonar.advance_simulation(sonar.tuning.threat_strike_seconds + 0.01)
	check(sonar.threat_mark(strike).is_empty(), "strike marker expires promptly")
	root.get_node("NoiseBus").emit_noise(guard.global_position, &"enemy_step", 0.8, guard)
	check(sonar.threat_mark(sonar.pulses.back()).is_empty(), "ordinary steps do not create an attack warning")
	check(game.audio.last_spatial_sound.key == "step" and game.audio.last_spatial_sound.origin == guard.global_position, "footsteps also use the real spatial origin")
	var outsider := Node2D.new()
	root.add_child(outsider)
	var previous_count: int = sonar.accepted_event_count
	var previous_sound: Dictionary = game.audio.last_spatial_sound.duplicate()
	root.get_node("NoiseBus").emit_noise(Vector2.ZERO, &"enemy_windup", 1.0, outsider)
	check(sonar.accepted_event_count == previous_count and game.audio.last_spatial_sound == previous_sound, "unrelated room sources cannot reveal or sound a warning")
	game.state = "paused"
	root.get_node("NoiseBus").emit_noise(Vector2.ONE, &"enemy_windup", 1.0, guard)
	check(game.audio.last_spatial_sound == previous_sound, "paused scene rejects new warning audio")
	game.state = "playing"
	sonar.advance_simulation(8.0)
	check(sonar.pulses.is_empty(), "silence clears all remaining threat and contour pulses")
	check(game.audio.cache.guard_draw is AudioStreamWAV, "original guard cue is a valid imported audio asset")
	outsider.free()
	game.free()
	print("POLISH SENSORY: %d/%d checks passed" % [checks-failures.size(),checks])
	quit(0 if failures.is_empty() else 1)
