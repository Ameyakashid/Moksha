extends SceneTree
## Run: godot --headless --path . --script tests/sonar_regression.gd

const View = preload("res://scripts/sensory/sonar_view.gd")
const Geometry = preload("res://scripts/sensory/sonar_geometry.gd")
var failures: Array[String] = []
var checks := 0
var metrics: Dictionary = {}
var bus: Node

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func fixture() -> Dictionary:
	var level := Node2D.new()
	root.add_child(level)
	var player := Node2D.new()
	level.add_child(player)
	var view := View.new()
	view.tuning = view.tuning.duplicate()
	root.add_child(view)
	view.set_process(false)
	view.bind_level(level, player)
	return {"level": level, "player": player, "view": view}

func rectangle(level: Node, pos: Vector2, size: Vector2, dynamic := false) -> CollisionShape2D:
	var body: PhysicsBody2D = RigidBody2D.new() if dynamic else StaticBody2D.new()
	if dynamic:
		body.freeze = true
	level.add_child(body)
	body.position = pos
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	return collider

func clean(f: Dictionary) -> void:
	f.view.free()
	f.level.free()
	bus.clear_history()

func emit(f: Dictionary, origin: Vector2, kind: StringName = &"weapon_tap") -> void:
	bus.emit_noise(origin, kind, 1.0, f.player)

func run() -> void:
	bus = root.get_node("NoiseBus")
	bus.clear_history()
	_test_bus()
	_test_independent_arrivals()
	_test_surface_travel()
	_test_transformed_geometry()
	_test_dynamic_geometry()
	_test_scope_and_reset()
	_test_pause_and_caps()
	await _test_camera()
	await _test_render_commands()
	_test_performance_metrics()
	_test_playability_defaults()
	var report := {"engine": Engine.get_version_info().string, "checks": checks, "passed": failures.is_empty(), "failures": failures, "metrics": metrics}
	var file := FileAccess.open("res://tests/sonar_report.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t") + "\n")
	print("SONAR_REGRESSION ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func _test_bus() -> void:
	bus.emit_noise(Vector2(NAN, 1), &"invalid", 1.0)
	bus.emit_noise(Vector2.ZERO, &"invalid", INF)
	bus.emit_noise(Vector2.ZERO, &"invalid", 0.0)
	check(bus.event_count == 0, "NoiseBus rejects invalid positions and non-positive/non-finite volume")
	var old_limit: int = bus.history_limit
	bus.history_limit = 3
	for i in range(6):
		bus.emit_noise(Vector2(i, i * 2), &"test", 1.0)
	check(bus.event_count == 6 and bus.event_history.size() == 3, "NoiseBus history is bounded without losing total event count")
	check(bus.event_history[2].origin == Vector2(5, 10), "NoiseBus preserves the exact supplied world origin")
	bus.history_limit = old_limit
	bus.clear_history()

func _test_independent_arrivals() -> void:
	var f := fixture()
	var view = f.view
	rectangle(f.level, Vector2(0, 100), Vector2(1200, 40))
	view.refresh_geometry()
	view.set_blind(true)
	var left := Vector2(-150, 0)
	var right := Vector2(150, 0)
	var target := Vector2(-150, 80)
	emit(f, left)
	var sample: Dictionary = view.debug_sample(target)
	check(sample.on_geometry and is_zero_approx(sample.alpha), "Distant surface remains invisible before first arrival")
	var first: float = sample.arrival_times[0].arrival
	view.advance_simulation(first + 0.025)
	emit(f, right, &"prop_break")
	sample = view.debug_sample(target)
	check(sample.sources.size() == 1 and sample.sources[0].origin == left, "Spaced noise B does not reset or prematurely reveal noise A's surface")
	var second: float = sample.arrival_times[1].arrival
	check(second > first + 0.3, "Distinct origins produce measurably distinct arrival times")
	view.advance_simulation(second + 0.025)
	sample = view.debug_sample(target)
	check(sample.sources.size() == 1 and sample.sources[0].origin == right, "Later wave arrives independently after the first wave fades")
	check(view.pulses[0].origin == left and view.pulses[1].origin == right, "All pulse origins remain immutable emission positions")
	check(not view.debug_sample(Vector2(-150, 10), 2.0).on_geometry, "Empty space never contains an outline or radial ring")
	metrics.independent_arrival_seconds = {"near": first, "far": second}
	view.advance_simulation(6.0)
	check(view.pulses.is_empty() and view.debug_snapshot().active_geometry_segments == 0, "Silence fully expires all pulses and terrain highlights")
	clean(f)

func _test_surface_travel() -> void:
	var f := fixture()
	var view = f.view
	rectangle(f.level, Vector2.ZERO, Vector2(240, 40))
	view.refresh_geometry()
	emit(f, Vector2(0, -100), &"prop_break")
	var points := [Vector2(0, -20), Vector2(120, 0), Vector2(0, 20)]
	var arrivals: Array[float] = []
	for point in points:
		var sample: Dictionary = view.debug_sample(point)
		check(sample.on_geometry and sample.arrival_times.size() == 1, "Floor/top, side and underside belong to actual collision contour")
		arrivals.append(sample.arrival_times[0].arrival)
	check(arrivals[0] < arrivals[1] and arrivals[1] < arrivals[2], "White front progresses from contact around sides to underside")
	view.advance_simulation(arrivals[0] + 0.015)
	check(view.debug_sample(points[0]).alpha > 0.5 and is_zero_approx(view.debug_sample(points[2]).alpha), "Nearest face lights before the underside; no instantaneous full silhouette")
	var early: Dictionary = view.debug_snapshot()
	check(early.active_geometry_segments > 0 and early.active_geometry_segments < early.geometry_segments / 2, "Initial contact reveals only travelling fragments")
	view.advance_simulation(arrivals[2] - arrivals[0])
	check(view.debug_sample(points[2]).alpha > 0.3, "Contour wraps into the underside on its scheduled arrival")
	metrics.surface_arrival_seconds = arrivals
	view.clear_pulses()
	emit(f, Vector2(0, -100))
	emit(f, Vector2(0, -100), &"prop_impact")
	view.advance_simulation(arrivals[0] + 0.02)
	var overlap: Dictionary = view.debug_sample(points[0])
	check(overlap.sources.size() == 2 and overlap.alpha <= 1.0 and overlap.alpha > overlap.sources[0].alpha, "Overlapping noises add independently and clamp to white")
	clean(f)

func _test_transformed_geometry() -> void:
	var f := fixture()
	var container := Node2D.new()
	f.level.add_child(container)
	container.position = Vector2(180, 130)
	container.rotation = 0.35
	container.scale = Vector2(1.4, 0.8)
	var box := rectangle(container, Vector2(20, -10), Vector2(80, 30))
	box.rotation = -0.2
	var cap_body := RigidBody2D.new()
	cap_body.freeze = true
	container.add_child(cap_body)
	cap_body.position = Vector2(100, -100)
	cap_body.rotation = 0.5
	var cap := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 12
	shape.height = 70
	cap.shape = shape
	cap_body.add_child(cap)
	var area := Area2D.new()
	f.level.add_child(area)
	var area_shape := CollisionShape2D.new()
	area_shape.shape = shape
	area.add_child(area_shape)
	var disabled := rectangle(f.level, Vector2(400, 100), Vector2(20, 20))
	disabled.disabled = true
	var ignored := rectangle(f.level, Vector2(500, 100), Vector2(20, 20))
	ignored.get_parent().add_to_group("sonar_ignore")
	rectangle(f.player, Vector2.ZERO, Vector2(10, 10))
	f.view.refresh_geometry()
	check(f.view.geometry.size() == 2, "Geometry excludes player, ignored nodes, disabled shapes and Area2D triggers")
	check(f.view.debug_sample(box.to_global(Vector2(0, -15)), 0.1).on_geometry, "Rotated/scaled rectangle follows the entire parent transform")
	check(f.view.debug_sample(cap.to_global(Vector2(12, 0)), 0.1).on_geometry, "Transformed capsule side follows collision geometry")
	check(f.view.debug_sample(cap.to_global(Vector2(0, -35)), 0.1).on_geometry, "Capsule curved cap has the correct transformed endpoint")
	var max_segment := 0.0
	for record in f.view.geometry:
		for i in range(record.a.size()):
			var segment := Geometry.segment_world(record, i)
			max_segment = maxf(max_segment, segment[0].distance_to(segment[1]))
	check(max_segment <= f.view.tuning.sample_spacing + 0.01, "Transformed collision contours respect world-space sampling density")
	metrics.maximum_sample_length = max_segment
	clean(f)

func _test_dynamic_geometry() -> void:
	var f := fixture()
	var box := rectangle(f.level, Vector2(80, 80), Vector2(50, 30), true)
	f.view.refresh_geometry()
	emit(f, Vector2(80, 0), &"prop_impact")
	var point := box.to_global(Vector2(0, -15))
	var initial: Dictionary = f.view.debug_sample(point)
	f.view.advance_simulation(initial.arrival_times[0].arrival + 0.02)
	box.get_parent().position += Vector2(130, -40)
	box.get_parent().rotation = 0.6
	f.view.refresh_geometry()
	var moved: Dictionary = f.view.debug_sample(box.to_global(Vector2(0, -15)), 0.1)
	check(moved.on_geometry and moved.alpha > 0.0, "Active prop highlight follows its moving/rotating collision body")
	check(is_equal_approx(moved.arrival_times[0].arrival, initial.arrival_times[0].arrival), "Rigid motion preserves emission-time arrival schedule")
	check(not f.view.debug_sample(point, 1.0).on_geometry, "Moving props leave no stale contour at their old location")
	box.shape.size = Vector2(100, 30)
	f.view.refresh_geometry()
	check(f.view.debug_sample(box.to_global(Vector2(50, 0)), 0.1).on_geometry, "Runtime collider shape edits refresh the actual contour")
	box.disabled = true
	check(not f.view.debug_sample(box.to_global(Vector2(50, 0)), 0.1).on_geometry, "Disabled/broken collider stops drawing immediately before refresh")
	box.get_parent().free()
	f.view.refresh_geometry()
	check(f.view.geometry.is_empty() and f.view.pulses[0].tracks.is_empty(), "Destroyed prop removes its geometry and all pulse tracks")
	clean(f)

func _test_scope_and_reset() -> void:
	var f := fixture()
	rectangle(f.level, Vector2(0, 20), Vector2(200, 20))
	f.view.refresh_geometry()
	var old_level := Node2D.new()
	root.add_child(old_level)
	var foreign := Node2D.new()
	old_level.add_child(foreign)
	bus.emit_noise(Vector2.ZERO, &"enemy_step", 1.0, foreign)
	bus.emit_noise(Vector2.ZERO, &"enemy_step", 1.0, null)
	check(f.view.accepted_event_count == 0, "Foreign-level and unscoped sources cannot reveal the bound world")
	emit(f, Vector2.ZERO)
	check(f.view.accepted_event_count == 1, "Live current-level event is accepted")
	f.view.set_blind(true)
	check(f.view.pulses.is_empty(), "Sight trade starts clean without resurrecting sighted-mode noise")
	emit(f, Vector2.ZERO)
	f.view.set_blind(true)
	check(f.view.pulses.size() == 1, "Idempotent set_blind preserves legitimate active pulse")
	for i in range(5):
		f.view.set_blind(false)
		f.view.set_blind(true)
		check(f.view.pulses.is_empty(), "Repeated blind toggle leaves no residual pulse")
	emit(f, Vector2.ZERO)
	f.view.bind_level(old_level, foreign)
	check(f.view.pulses.is_empty() and f.view.event_history.is_empty() and f.view.geometry.is_empty(), "Binding a new level clears old pulses, history and geometry")
	emit(f, Vector2.ZERO)
	check(f.view.accepted_event_count == 0, "Late event from previous live level is rejected after rebinding")
	old_level.free()
	f.view.refresh_geometry()
	check(f.view.geometry.is_empty(), "Freed bound level leaves no ghost geometry")
	clean(f)

func _test_pause_and_caps() -> void:
	var f := fixture()
	rectangle(f.level, Vector2(0, 30), Vector2(1200, 60))
	f.view.tuning.max_geometry_segments = 64
	f.view.tuning.max_active_pulses = 3
	f.view.tuning.history_limit = 4
	f.view.refresh_geometry()
	check(f.view.debug_snapshot().geometry_segments <= 64, "Geometry sampling enforces its hard segment budget")
	for i in range(10):
		emit(f, Vector2(i * 4, -20))
	check(f.view.pulses.size() == 3 and f.view.dropped_pulse_count == 7, "Pulse cap evicts oldest noise deterministically")
	check(f.view.event_history.size() == 4 and f.view.accepted_event_count == 10, "View event history cap preserves accepted total")
	f.view.advance_simulation(0.1)
	var age: float = f.view.pulses[0].age
	f.view.simulation_enabled = false
	f.view.advance_simulation(2.0)
	emit(f, Vector2.ZERO)
	check(is_equal_approx(f.view.pulses[0].age, age) and f.view.accepted_event_count == 10, "Game pause freezes age/fade and rejects new event intake")
	f.view.simulation_enabled = true
	paused = true
	f.view.advance_simulation(2.0)
	emit(f, Vector2.ZERO)
	check(is_equal_approx(f.view.pulses[0].age, age) and f.view.accepted_event_count == 10, "SceneTree pause also freezes sonar and rejects events")
	paused = false
	f.view.advance_simulation(NAN)
	check(is_finite(f.view.elapsed), "Non-finite time input cannot poison pulse simulation")
	f.view.advance_simulation(10.0)
	check(f.view.pulses.is_empty(), "Resume expires pulses normally")
	clean(f)

func _test_camera() -> void:
	var f := fixture()
	var camera := Camera2D.new()
	f.level.add_child(camera)
	camera.position_smoothing_enabled = false
	camera.position = Vector2(320, 180)
	camera.make_current()
	camera.force_update_scroll()
	await process_frame
	var before: Vector2 = f.view.debug_project_world(Vector2(400, 100))
	camera.position += Vector2(0, -200)
	camera.force_update_scroll()
	var after: Vector2 = f.view.debug_project_world(Vector2(400, 100))
	check(after.is_equal_approx(before + Vector2(0, 200)), "World contours track vertical Camera2D movement through canvas transform")
	camera.zoom = Vector2(1.5, 1.5)
	camera.force_update_scroll()
	var span: Vector2 = f.view.debug_project_world(Vector2(100, 100)) - f.view.debug_project_world(Vector2(0, 0))
	check(span.is_equal_approx(Vector2(150, 150)), "Projection honors Camera2D zoom on both axes")
	metrics.camera_vertical_screen_delta = after.y - before.y
	clean(f)

func _test_playability_defaults() -> void:
	var f := fixture()
	var tuning = f.view.tuning
	check(not f.view.preview_when_sighted and not f.view.blind, "Default unpowered vision has no sonar overlay")
	check(tuning.draw_proprioception, "Blind play retains a small body-position cue")
	check(tuning.propagation_speed > 400 and tuning.contour_speed > 500, "Default fronts are readable during boosted movement")
	check(tuning.profile(&"weapon_tap", 1.1).range > 400, "Weapon tap covers a useful nearby platforming distance")
	check(tuning.profile(&"prop_break", 1.6).range > tuning.profile(&"enemy_step", 0.8).range, "Prop break carries farther than enemy footsteps")
	check(tuning.bright_head_seconds + tuning.trail_seconds < 0.8, "Local highlight lifetime is short enough to return to silence")
	metrics.defaults = {"tap_range": tuning.profile(&"weapon_tap", 1.1).range, "enemy_step_range": tuning.profile(&"enemy_step", 0.8).range, "break_range": tuning.profile(&"prop_break", 1.6).range, "local_head_and_trail_seconds": tuning.bright_head_seconds + tuning.trail_seconds}
	clean(f)

func _test_render_commands() -> void:
	var f := fixture()
	root.canvas_transform = Transform2D.IDENTITY
	rectangle(f.level, Vector2(320, 180), Vector2(480, 40))
	f.player.position = Vector2(320, 150)
	f.view.refresh_geometry()
	f.view.set_blind(true)
	f.view.tuning.max_draw_segments = 10
	emit(f, Vector2(320, 80))
	f.view.advance_simulation(0.3)
	await process_frame
	RenderingServer.force_draw(false)
	var drawn: Dictionary = f.view.debug_snapshot()
	check(drawn.draw_blackout and drawn.draw_proprioception, "Blind renderer submits black world cover and body-position mark")
	check(drawn.draw_segments > 0 and drawn.draw_segments <= 10, "Renderer submits active white contour fragments within draw budget")
	check(drawn.draw_origins == 1, "Fresh physical noise submits its own origin marker")
	f.view.advance_simulation(5.0)
	await process_frame
	RenderingServer.force_draw(false)
	var quiet: Dictionary = f.view.debug_snapshot()
	check(quiet.draw_blackout and quiet.draw_proprioception and quiet.draw_segments == 0 and quiet.draw_origins == 0, "Quiet blind frame retains only black world and body cue")
	f.view.set_blind(false)
	emit(f, Vector2(320, 80))
	f.view.advance_simulation(0.3)
	await process_frame
	RenderingServer.force_draw(false)
	var sighted: Dictionary = f.view.debug_snapshot()
	check(not sighted.draw_blackout and not sighted.draw_proprioception and sighted.draw_segments == 0 and sighted.draw_origins == 0, "Unpowered sighted frame submits no sonar drawing commands")
	metrics.headless_draw_commands = {"blind_segments": drawn.draw_segments, "blind_origin_marks": drawn.draw_origins, "quiet_segments": quiet.draw_segments, "sighted_segments": sighted.draw_segments}
	clean(f)

func _test_performance_metrics() -> void:
	var f := fixture()
	for i in range(24):
		rectangle(f.level, Vector2((i % 6) * 70, (i / 6) * 55), Vector2(180, 30))
	var start := Time.get_ticks_usec()
	f.view.refresh_geometry()
	var geometry_usec := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	for i in range(18):
		emit(f, Vector2(160 + i * 2, 70))
	var events_usec := Time.get_ticks_usec() - start
	f.view.advance_simulation(0.28)
	start = Time.get_ticks_usec()
	var sample: Dictionary = {}
	for i in range(10):
		sample = f.view.debug_snapshot()
	var evaluate_usec := (Time.get_ticks_usec() - start) / 10.0
	check(sample.pulse_count == f.view.tuning.max_active_pulses and sample.active_geometry_segments > 0, "Stress fixture retains bounded independent active pulses")
	metrics.cpu_stress = {"geometry_segments": sample.geometry_segments, "active_segments": sample.active_geometry_segments, "pulses": sample.pulse_count, "geometry_collection_usec": geometry_usec, "mean_event_creation_usec": events_usec / 18.0, "mean_all_contour_alpha_evaluation_usec": evaluate_usec, "note": "Synthetic overlapping geometry; CPU instrumentation only, not GPU/frame-rate claim"}
	var max_alpha_error := 0.0
	for time in [0.0, 0.15, 0.4, 0.8, 1.3]:
		for pulse in f.view.pulses:
			pulse.age = time
		for record in f.view.geometry:
			var optimized: PackedFloat32Array = f.view._segment_alphas(record)
			for i in range(record.a.size()):
				var expected := 0.0
				for pulse in f.view.pulses:
					if pulse.tracks.has(record.key):
						expected = minf(1.0, expected + f.view._alpha_for(pulse, pulse.tracks[record.key], i))
				max_alpha_error = maxf(max_alpha_error, absf(expected - optimized[i]))
	check(max_alpha_error < 0.00001, "Optimized render composition matches independent per-pulse alpha sampling across arrival, overlap and fade")
	metrics.maximum_render_sample_alpha_error = max_alpha_error
	clean(f)
