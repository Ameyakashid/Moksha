extends SceneTree
# Synthetic nested outsider noise, not an authored gameplay reproduction.
# Real actor receive_hit -> NoiseBus -> host admission -> real Health/death.
# Only sound creation is fixture-backed because the original director suppresses
# new spatial voices on headless. No production source is modified.
class HeadlessVoices extends "res://scripts/systems/audio_director.gd":
	func play_at(key: String, origin: Vector2, db := -10.0, pitch := 1.0) -> void:
		super.play_at(key, origin, db, pitch)
		if muted or not cache.has(key): return
		var voice := AudioStreamPlayer2D.new()
		voice.stream = cache[key]; voice.position = origin; add_child(voice)
var rows: Array = []
var observations: Array = []
var hz := 120
var output_path := ""
var argument_failures: Array[String] = []
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):
			var value := arg.trim_prefix("--hz=")
			if value in ["60", "120"]: hz = int(value)
			else: argument_failures.append("--hz must be 60 or 120")
		elif arg.begins_with("--output="): output_path = arg.trim_prefix("--output=")
	Engine.physics_ticks_per_second = hz
	run.call_deferred()
func write_report(report: Dictionary) -> void:
	var path := output_path if not output_path.is_empty() else "user://nov6_audio/rejected_noise_%dhz.json" % hz
	var absolute := ProjectSettings.globalize_path(path).simplify_path()
	var source_root := ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	if not (path.begins_with("user://") or path.is_absolute_path()) or path.begins_with("res://") or absolute == source_root or absolute.begins_with(source_root + "/"):
		report.failures.append("--output must be user:// or an absolute path outside the project")
		report.passed = false; return
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK:
		report.failures.append("Could not create report output directory: " + error_string(error))
		report.passed = false; return
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		report.failures.append("Could not open report output: " + error_string(FileAccess.get_open_error()))
		report.passed = false; return
	report.output = absolute
	file.store_string(JSON.stringify(report, "\t")); file.flush()
	if file.get_error() != OK:
		report.failures.append("Could not write report output: " + error_string(file.get_error()))
		report.passed = false
	file.close()
func check(value: bool, label: String) -> void:
	rows.append({"label": label, "passed": value})
func pending(host) -> Variant:
	return host._audio_feedback._pending_hurt.get_ref() if host._audio_feedback._pending_hurt != null else null
func make_host():
	var host = load("res://campaign/campaign.tscn").instantiate()
	host.save_enabled = false; root.add_child(host); host.start_new(true)
	host.set_process(false); host.set_physics_process(false)
	host.audio.free(); host.audio = HeadlessVoices.new(); host.add_child(host.audio)
	return host
func emit_hurt(host): host.bus.emit_noise(host.player.global_position, &"player_damage", 1, host.player)
func run() -> void:
	var host = make_host()
	var outsider := Node.new(); root.add_child(outsider)
	var injected: Array = []
	var inject := func(_origin, kind, _loudness, source):
		if kind == &"player_damage" and source == host.player:
			var first = pending(host)
			injected.append({"pending_before": is_instance_valid(first), "state_before": host.state, "physics_frame": Engine.get_physics_frames()})
			var request: Dictionary = host.audio.last_spatial_sound
			host.bus.emit_noise(Vector2.ZERO, &"player_damage", 1, outsider)
			injected[-1].pending_after = pending(host) == first and first != null
			injected[-1].request_unchanged = is_same(request, host.audio.last_spatial_sound)
	host.bus.noise_emitted.connect(inject)
	var frame := Engine.get_physics_frames()
	var accepted: bool = host.player.receive_hit({"amount":1000.0,"impulse":Vector2.ZERO,"source_position":host.player.global_position+Vector2(30,0),"source_id":0})
	check(accepted and host.health.current_health == 0 and host.state == "dead" and paused, "genuine lethal actor hit reaches real Health and death")
	check(injected.size() == 1 and injected[0].pending_before and injected[0].state_before == "playing", "accepted real hurt precedes injected outsider before death")
	check(injected.size() == 1 and injected[0].request_unchanged, "superclass rejects outsider without a new sound request")
	check(Engine.get_physics_frames() == frame, "entire lethal chain occurs in one physics frame")
	var voices: Array = host.audio.get_children().filter(func(c): return c is AudioStreamPlayer2D and c.stream == host.audio.cache.hurt)
	check(voices.size() == 1, "only genuine accepted hurt creates a voice")
	check(voices.size() == 1 and voices[0].process_mode == Node.PROCESS_MODE_ALWAYS, "rejected outsider cannot suppress same-frame lethal promotion")
	observations.append({"injection": injected, "mode": voices[0].process_mode if voices.size() == 1 else -1})
	host.bus.noise_emitted.disconnect(inject)
	host.free(); paused = false
	await process_frame
	# Additional no-new-voice semantics and same-valued accepted request checks.
	host = make_host()
	emit_hurt(host)
	var prior = pending(host)
	var request: Dictionary = host.audio.last_spatial_sound
	check(is_instance_valid(prior), "accepted headless voice establishes pending identity")
	emit_hurt(host)
	check(not is_same(request, host.audio.last_spatial_sound) and request == host.audio.last_spatial_sound, "identical accepted values still replace request identity")
	check(is_instance_valid(pending(host)) and pending(host) != prior, "repeated accepted request replaces pending voice")
	host.audio.muted = true; emit_hurt(host)
	check(pending(host) == null, "accepted muted request still clears prior pending voice")
	host.audio.muted = false; emit_hurt(host)
	check(is_instance_valid(pending(host)), "unmuted accepted request restores fresh pending")
	var cached = host.audio.cache.hurt; host.audio.cache.erase("hurt"); emit_hurt(host)
	check(pending(host) == null, "accepted missing-cache request still clears prior pending voice")
	host.audio.cache.hurt = cached; emit_hurt(host)
	prior = pending(host); host.bus.emit_noise(Vector2.ZERO, &"player_damage", 1, null)
	check(pending(host) == prior and prior != null, "null-source rejection cannot clear pending voice")
	host.free(); outsider.free(); paused = false
	await process_frame; await create_timer(0.3, true).timeout
	var failures: Array[String] = argument_failures.duplicate()
	for row in rows:
		if not row.passed: failures.append(row.label)
	var report := {"passed": not rows.is_empty() and failures.is_empty(), "checks": rows.size(), "failures": failures, "rows": rows, "physics_hz": hz, "engine": Engine.get_version_info().string, "observations": observations, "scope": "Synthetic nested outsider-noise hardening, not an authored gameplay bug. Actual public actor hit, NoiseBus admission, Health and defeat routing; explicit headless-only voice provider, not audible or physical-device evidence."}
	write_report(report)
	print("NOV6_AUDIO_REJECTED_NOISE_RESULT " + JSON.stringify(report))
	quit(0 if report.passed else 1)
