extends SceneTree
## Physics-tick-owned ordinary-input traces. Output is explicitly external.
class Driver extends Node:
	var actor: Node
	var hz := 60
	var ticks := 0
	var limit := 0
	var kind := "chain"
	var trace: Array = []
	func _physics_process(dt: float) -> void:
		if ticks >= limit: return
		var frame: Dictionary = {}
		if kind in ["charge", "repeat"]:
			frame.attack = ticks >= 3 and ticks < limit - hz
		else: frame.attack = ticks >= 3 and (ticks - 3) % maxi(1, int(hz * 0.4)) == 0
		if ticks > hz * 2 and ticks < hz * 3: frame.right = 1.0
		actor.physics_tick(dt, frame)
		var t: Dictionary = actor.telemetry()
		var sample: Dictionary = {"position": [actor.position.x, actor.position.y], "velocity": [actor.velocity.x, actor.velocity.y]}
		for key in ["main_action", "weapon_phase", "attack_serial", "weapon_elapsed", "attack_step_elapsed", "chain_serial", "attack_step_index", "chain_pending_remaining", "charge_elapsed", "charge_role", "melee_reuse_lock_remaining", "repeat_restart_remaining", "grounded"]:
			sample[key] = t.get(key)
		trace.append(sample); ticks += 1
var hz := 60
var output := ""
var enabled := false
var admissions := 0
var result: Dictionary = {}
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg == "--admit": enabled = true
	if hz not in [60, 120] or not output.is_absolute_path() or output.begins_with(ProjectSettings.globalize_path("res://")) or FileAccess.file_exists(output): quit(2); return
	Engine.physics_ticks_per_second = hz
	run.call_deferred()
func run() -> void:
	for kind in ["legacy", "chain", "repeat", "charge"]:
		var world := Node2D.new(); root.add_child(world)
		var floor_ := StaticBody2D.new(); var shape := RectangleShape2D.new(); shape.size = Vector2(3000, 40)
		var collider := CollisionShape2D.new(); collider.shape = shape; floor_.add_child(collider); floor_.position = Vector2(0, 220); world.add_child(floor_)
		var actor = load("res://combat_pc/player.tscn").instantiate(); actor.automatic_physics = false; actor.position = Vector2(0, 200); world.add_child(actor)
		if kind != "legacy": actor.melee_chain = load("res://combat_pc/resources/light_chain.tres").duplicate(true)
		if kind in ["repeat", "charge"]: actor.melee_input_profile = load("res://combat_pc/resources/held_%s.tres" % kind).duplicate(true)
		var events: Array = []
		actor.movement_event.connect(func(event: StringName, packet: Dictionary):
			# No object/RID/world-instance identity enters the neutral comparison.
			var p: Dictionary = {}
			for key in ["serial", "phase", "reason", "step_index", "charge_role", "request_kind"]:
				if packet.has(key): p[key] = packet[key]
			events.append([str(event), p])
			if enabled and event == &"attack_started":
				var token: Dictionary = actor.late_windup_admission_snapshot()
				if not token.is_empty() and actor.request_late_windup(token, 0.18, 0.5): admissions += 1
		)
		var driver := Driver.new(); driver.actor = actor; driver.hz = hz; driver.limit = hz * 5; driver.kind = kind; world.add_child(driver)
		while driver.ticks < driver.limit: await physics_frame; await process_frame
		result[kind] = {"trace": driver.trace.duplicate(true), "events": events.duplicate(true)}
		world.free(); await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null: quit(2); return
	file.store_string(JSON.stringify({"hz": hz, "admitted": admissions, "cases": result})); file.close()
	print("LATE_WINDUP_INPUT_TRACE hz=%d admissions=%d" % [hz, admissions])
	quit(0)
