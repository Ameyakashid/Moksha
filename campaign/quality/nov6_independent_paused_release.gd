extends SceneTree
## Real device release during a paused in-flight jump. No actor state writes.
var host: Node
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	run.call_deferred()
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func key(code: int, down: bool) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = down
	Input.parse_input_event(event); Input.flush_buffered_events()
func tap(code: int) -> void: key(code, true); key(code, false)
func run() -> void:
	host = load("res://campaign/campaign.tscn").instantiate(); host.save_enabled = false
	root.add_child(host); host.start_new(true)
	await frames(4)
	key(KEY_SPACE, true); await frames(2)
	var before: float = host.player.velocity.y
	tap(KEY_ESCAPE)
	key(KEY_SPACE, false)
	await frames(5)
	tap(KEY_ESCAPE)
	await frames(1)
	var after: float = host.player.velocity.y
	var cap: float = host.player.profile.jump_release_rise_cap
	var passed := after >= -cap - 1.0
	var failures: Array[String] = []
	if not passed: failures.append("jump released while paused must cut ascent on resume")
	print("NOV6_INDEPENDENT_PAUSED_RELEASE " + JSON.stringify({"passed": passed, "checks": 1, "hz": Engine.physics_ticks_per_second, "failures": failures, "before_velocity": before, "after_velocity": after, "release_cap": cap, "input": host.player._input}))
	host.free(); quit(0 if passed else 1)
