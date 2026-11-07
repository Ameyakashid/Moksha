extends SceneTree
## Read-only modal-release feedback fixtures through the actual HUD owner.
const Gate = preload("res://campaign/logic/campaign_input_gate.gd")
var checks := 0
var failures: Array[String] = []
var hz := 60
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func run() -> void:
	var gate = Gate.new()
	gate.suppress_held({"right": 1.0, "attack": true})
	var before: Dictionary = gate._blocked.duplicate()
	check(gate.has_held_blocker({"right": 1.0}), "held blocked axis requests guidance")
	check(gate.has_held_blocker({"attack_pressed": true}), "explicit blocked press requests guidance")
	check(not gate.has_held_blocker({}), "release hides hint before next filter")
	check(not gate.has_held_blocker({"left": 1.0}), "unblocked new input does not request hint")
	check(gate._blocked == before, "all guidance queries leave gate untouched")
	check(gate.filter_frame({"right": 1.0}).right == 0.0, "query did not admit held motion")
	gate.filter_frame({})
	check(gate.filter_frame({"right": 1.0}).right == 1.0, "normal release permits fresh motion")
	var host = load("res://campaign/campaign.tscn").instantiate()
	host.save_enabled = false
	root.add_child(host)
	host.start_new(true)
	host.set_process(false)
	host.set_physics_process(false)
	paused = true
	host.input_override = {}
	var normal: String = host._hud_snapshot().guidance
	for device in ["keyboard", "controller"]:
		host.gamepad_navigation.input_device = device
		host.state = "playing"
		host.input_override = {"right": 1.0}
		host._capture_input_boundary()
		var snapshot: Dictionary = host._hud_snapshot()
		var expected := "Center the stick and release held buttons." if device == "controller" else "Release held keys, then press again."
		check(snapshot.guidance == expected, device + " blocked input is explained")
		check(host.hud.set_snapshot(snapshot), device + " actual HUD owner accepts hint")
		check(host.hud._snapshot.guidance == expected, device + " hint survives owner/View boundary")
		host._checkpoint_write_error = "Fixture write failure"
		host.notice = "CHECKPOINT NOT SAVED"
		host.notice_left = 8.0
		snapshot = host._hud_snapshot()
		check(snapshot.guidance == expected and snapshot.notice == host.notice and snapshot.notice_visible, device + " checkpoint warning remains visible beside hint")
		host.input_override = {}
		check(host._hud_snapshot().guidance == normal, device + " raw release immediately restores objective")
		check(not host._input_gate._blocked.is_empty(), device + " snapshot never prunes blocked state")
		host.input_override = {"left": 1.0}
		check(host._hud_snapshot().guidance == normal, device + " unblocked opposite direction keeps objective")
		host.input_override = {"right": 1.0}
		for state in ["title", "journal", "archive", "paused", "upgrade", "final_choice", "dead"]:
			host.state = state
			check(host._hud_snapshot().guidance != expected, device + " no release hint in " + state)
		host.state = "playing"
		host._input_tick_source = {"right": 1.0}
		host._input_tick_active = true
		host.input_override = {"right": 0.0}
		check(host._hud_snapshot().guidance == expected, device + " snapshot uses true raw input during filtered physics tick")
		host._input_tick_active = false
		host._input_tick_source = null
		host.input_override = {}
		host._input_gate.filter_frame({})
	host.queue_free()
	await process_frame
	await process_frame
	var result := {"hz": hz, "checks": checks, "failures": failures, "passed": failures.is_empty(), "scope": "Controlled read-only gate and host-to-HUD fixtures, not a physical controller or campaign traversal test."}
	print("NOV6_INPUT_GUIDANCE_RESULT " + JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
