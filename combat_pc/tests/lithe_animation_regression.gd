extends SceneTree
const LithePose = preload("res://combat_pc/visuals/lithe_pose.gd")
const LitheView = preload("res://combat_pc/visuals/lithe_wireframe.gd")
const BasePose = preload("res://combat_pc/visuals/wireframe_pose.gd")
const Player = preload("res://combat_pc/player.tscn")
var failures: Array[String] = []
var checks := 0
var poses := 0
var max_leg_error := 0.0
var max_arm_error := 0.0
var max_plant_drift := 0.0
var physics_error := 0.0
var max_support_drift := 0.0
var max_slope_plane_error := 0.0
var hz := 60

class Driver extends Node:
	var actors: Array = []
	var frames := 0
	var max_error := 0.0
	var offset := Vector2.ZERO
	var modes := {}
	func _physics_process(dt: float) -> void:
		var t := frames*dt
		var frame := {"right": 1.0 if t < 0.9 else 0.0, "left": 1.0 if t >= 0.9 and t < 1.5 else 0.0, "jump_pressed": frames == int(0.4/dt), "jump": t > 0.4 and t < 0.6, "jump_released": frames == int(0.6/dt), "roll_pressed": frames == int(2.0/dt), "attack_pressed": frames == int(2.7/dt), "shield_pressed": frames == int(3.4/dt), "shield": frames >= int(3.4/dt) and frames < int(3.9/dt)}
		for actor in actors:
			actor.physics_tick(dt, frame)
		modes[str(actors[1].get_node("Visual").pose_name)] = true
		max_error = maxf(max_error, (actors[1].position-actors[0].position-offset).length())
		max_error = maxf(max_error, actors[1].velocity.distance_to(actors[0].velocity))
		frames += 1

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):
			hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _run() -> void:
	_pose_geometry()
	await _plant_and_pause()
	_support_surfaces()
	await _motor_equivalence()
	var report := {"suite": "lithe animation", "physics_hz": hz, "checks": checks, "sampled_poses": poses, "failures": failures, "maximum_leg_length_error_px": max_leg_error, "maximum_arm_length_error_px": max_arm_error, "maximum_planted_foot_drift_px": max_plant_drift, "maximum_moving_support_drift_px": max_support_drift, "maximum_slope_plane_error_px": max_slope_plane_error, "maximum_controller_difference": physics_error, "engine": Engine.get_version_info().string, "limits": ["Original MOKSHA animation tuning; no numerical Dead Cells parity", "Special traversal, shield and melee preserve existing authored geometry and authority", "Geometry/physics automation is distinct from native visual review"]}
	FileAccess.open("res://combat_pc/tests/lithe_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(report, "  ")+"\n")
	print("LITHE_ANIMATION %dHz: %d checks, %d poses, %d failures" % [hz, checks, poses, failures.size()])
	for failure in failures:
		printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _pose_geometry() -> void:
	for facing in [-1, 1]:
		for mode in LithePose.MODES:
			for step in 101:
				var p := float(step)/100.0
				var t := {"velocity": Vector2(260*facing, -100), "facing": facing, "grounded": mode not in ["jump", "air_jump", "jump_rise", "jump_apex", "fall"], "gait_phase": p, "roll_direction": facing}
				var result: Dictionary = LithePose.evaluate(mode, p, t)
				var bones: Dictionary = result.bones
				poses += 1
				for name in BasePose.BONE_NAMES:
					if not bones.has(name) or not Vector2(bones[name]).is_finite():
						failures.append("Nonfinite or missing bone: "+mode+"/"+name)
				for side in ["near", "far"]:
					max_leg_error = maxf(max_leg_error, absf(bones["hip_"+side].distance_to(bones["knee_"+side])-8.0))
					max_leg_error = maxf(max_leg_error, absf(bones["knee_"+side].distance_to(bones["ankle_"+side])-8.0))
					max_arm_error = maxf(max_arm_error, absf(bones["shoulder_"+side].distance_to(bones["elbow_"+side])-6.0))
					max_arm_error = maxf(max_arm_error, absf(bones["elbow_"+side].distance_to(bones["palm_"+side])-5.8))
	check(max_leg_error < 0.001, "Fixed leg lengths across all lithe modes and both facings")
	check(max_arm_error < 0.001, "Fixed arm lengths across all lithe modes and both facings")
	for mode in ["attack_slash_active", "attack_backhand_active", "attack_finisher_active", "shield_hold", "climb_idle", "wall_slide", "defeated"]:
		var inputs := {"facing": 1, "grounded": true}
		check(LithePose.evaluate(mode, 0.5, inputs) == BasePose.evaluate(mode, 0.5, inputs), "Preserved specialized authority and geometry: "+mode)
	var before: Dictionary = LithePose.evaluate("run", 0.99999, {"velocity": Vector2(260,0), "grounded": true})
	var after: Dictionary = LithePose.evaluate("run", 0.00001, {"velocity": Vector2(260,0), "grounded": true})
	var seam := 0.0
	for name in BasePose.BONE_NAMES:
		seam = maxf(seam, Vector2(before.bones[name]).distance_to(after.bones[name]))
	check(seam < 0.02, "Continuous run-cycle seam")

func _plant_and_pause() -> void:
	for facing in [-1, 1]:
		var view := LitheView.new()
		root.add_child(view)
		var anchors := {}
		var planted_samples := 0
		for tick in hz*2:
			var telemetry := {"tick_id": tick, "position": Vector2(260.0*facing*tick/hz,0), "velocity": Vector2(260*facing,0), "grounded": true, "facing": facing, "move_x": facing, "pose": "run", "support_id": 1}
			view.present(1.0/hz, telemetry)
			var pose: Dictionary = view.get_pose()
			for i in 2:
				var side := "near" if i == 0 else "far"
				if pose.planted_feet[i]:
					var point: Vector2 = telemetry.position+Vector2(pose.bones["sole_"+side])
					if anchors.has(side):
						max_plant_drift = maxf(max_plant_drift, point.distance_to(anchors[side]))
					anchors[side] = point
					planted_samples += 1
				else:
					anchors.erase(side)
			var snapshot: Dictionary = view.get_pose()
			view.present(1.0/hz, telemetry)
			check(view.get_pose() == snapshot, "Duplicate tick is idempotent")
		check(planted_samples > hz/3, "Running retains real stance intervals")
		var pose_before: Dictionary = view.get_pose()
		var paused: Dictionary = view._telemetry.duplicate(true)
		paused.tick_id += 1
		paused.paused = true
		view.present(1.0/hz, paused)
		check(view.get_pose() == pose_before, "Pause freezes complete current pose")
		view.reset_presentation()
		check(view._foot_anchors.is_empty() and view._lithe_entry.is_empty(), "Reset clears contacts and blend history")
		view.queue_free()
	check(max_plant_drift < 0.001, "Planted feet do not slide in world space")

func _support_surfaces() -> void:
	for slope in [false, true]:
		var view := LitheView.new()
		root.add_child(view)
		var anchors := {}
		var planted := 0
		var normal := Vector2(-0.2, -1).normalized() if slope else Vector2.UP
		for tick in hz:
			var time := float(tick)/hz
			var carrier := Vector2(45*time, 0)
			var at := Vector2(260*time, -52*time if slope else 0.0)+carrier
			var telemetry := {"tick_id": tick, "position": at, "velocity": Vector2(260, -52 if slope else 0), "floor_relative_velocity": Vector2(260, -52 if slope else 0), "grounded": true, "facing": 1, "move_x": 1, "pose": "run", "support_id": 2, "support_displacement": Vector2(45.0/hz,0) if tick > 0 else Vector2.ZERO, "floor_normal": normal, "floor_contact_point": carrier}
			view.present(1.0/hz, telemetry)
			var pose: Dictionary = view.get_pose()
			for i in 2:
				var side := "near" if i == 0 else "far"
				if pose.planted_feet[i]:
					var point: Vector2 = at+Vector2(pose.bones["sole_"+side])-carrier
					if anchors.has(side):
						max_support_drift = maxf(max_support_drift, point.distance_to(anchors[side]))
					anchors[side] = point
					max_slope_plane_error = maxf(max_slope_plane_error, absf(point.dot(normal)))
					planted += 1
				else:
					anchors.erase(side)
		check(planted > hz/4, "Stance remains supported on "+("moving slope" if slope else "moving floor"))
		view.queue_free()
	check(max_support_drift < 0.001, "Planted feet follow support displacement without skating")
	check(max_slope_plane_error < 0.001, "Slope foot plants lie on the supplied floor plane")

func _motor_equivalence() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var floor := StaticBody2D.new()
	floor.position = Vector2(0, 10)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10000,20)
	shape.shape = rect
	floor.add_child(shape)
	world.add_child(floor)
	var actors: Array = []
	for i in 2:
		var actor = Player.instantiate()
		actor.automatic_physics = false
		actor.position = Vector2(i*1500, 0)
		if i == 1:
			actor.get_node("Visual").set_script(LitheView)
		world.add_child(actor)
		actors.append(actor)
	var driver := Driver.new()
	driver.actors = actors
	driver.offset = actors[1].position-actors[0].position
	world.add_child(driver)
	while driver.frames < hz*4:
		await physics_frame
	physics_error = driver.max_error
	check(physics_error < 0.01, "Real motor run/reverse/jump/roll/melee/shield is view-independent")
	for expected in ["run", "jump_rise", "fall", "roll_travel", "attack_active", "shield_hold"]:
		check(driver.modes.has(expected), "Real motor actually entered "+expected)
	world.queue_free()
