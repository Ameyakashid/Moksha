extends SceneTree
## Real-engine fixture: the unchanged PC runs in physics callbacks and records
## actual collision contacts/crossings. Frame limits only bound failed conditions.
const SHUTTER = preload("res://demo/components/relay_shutter.gd")
const PLAYER = preload("res://combat_pc/player.tscn")
const BASE_SONAR = preload("res://scripts/sensory/sonar_view.gd")
const DEMO_SONAR = preload("res://demo/components/mission_sonar.gd")
const GEOMETRY = preload("res://scripts/sensory/sonar_geometry.gd")

class Driver extends Node:
	var player: CharacterBody2D
	var frame: Dictionary = {}
	var contacts: Array[int] = []
	var contact_receipts: Array[Dictionary] = []
	var steps := 0
	func _physics_process(dt: float) -> void:
		if not is_instance_valid(player): return
		player.physics_tick(dt, frame)
		steps += 1
		# This PC owns continuous move_and_collide sweeps, not move_and_slide.
		# Observe its real wall response, then identify the touching collider
		# with an independent non-moving shape sweep of this same player body.
		var direction := signf(float(frame.get("right", 0)))
		if direction == 0: return
		var hit := KinematicCollision2D.new()
		if player.test_move(player.global_transform, Vector2(direction, 0), hit, player.profile.collision_margin):
			if absf(hit.get_normal().x) <= 0.65: return
			var collider := hit.get_collider()
			if is_instance_valid(collider) and absf(player._wall_normal.x) > 0.65:
				contacts.append(collider.get_instance_id())
				contact_receipts.append({"collider_id": collider.get_instance_id(), "point": hit.get_position(),
					"query_normal": hit.get_normal(), "motor_normal": player._wall_normal, "actor_position": player.position,
					"actor_velocity": player.velocity, "physics_step": steps})

var hz := 120
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var raw_events: Array[Dictionary] = []
var crossings: Array[Dictionary] = []
var changes: Array[bool] = []
var hashes: Dictionary = {}
var world: Node2D
var room: Node2D
var shutter
var player
var driver: Driver
var baseline
var candidate
var bus: Node

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()

func _check(ok: bool, label: String, detail: String = "") -> void:
	checks.append({"label": label, "passed": ok, "detail": detail})
	if not ok: failures.append(label + (": " + detail if not detail.is_empty() else ""))

func _frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func _until(predicate: Callable, max_frames: int) -> bool:
	for _i in max_frames:
		await _frames(1)
		if predicate.call(): return true
	return false

func _record_noise(origin: Vector2, kind: StringName, loudness: float, source: Node) -> void:
	if source != shutter: return
	raw_events.append({"origin": origin, "kind": String(kind), "loudness": loudness,
		"source_id": source.get_instance_id(), "source_in_room": room.is_ancestor_of(source),
		"committed_open": shutter.is_open, "disabled": shutter.collision_shape.disabled,
		"sonar_ignore": shutter.collision_shape.is_in_group("sonar_ignore")})

func _run() -> void:
	for path in ["res://combat_pc/player.gd", "res://scripts/sensory/noise_bus.gd", "res://scripts/sensory/sonar_geometry.gd", "res://scripts/sensory/sonar_view.gd", "res://demo/components/mission_sonar.gd"]:
		hashes[path] = FileAccess.get_sha256(path)
	world = Node2D.new()
	root.add_child(world)
	room = Node2D.new()
	room.name = "RelayFixtureRoom"
	world.add_child(room)
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(400, 220)
	var floor_shape := CollisionShape2D.new()
	var floor_box := RectangleShape2D.new()
	floor_box.size = Vector2(800, 40)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	room.add_child(floor_body)
	shutter = SHUTTER.new()
	shutter.name = "RelayShutter"
	shutter.configure(Vector2(24, 120), 2)
	shutter.position = Vector2(300, 140)
	room.add_child(shutter)
	shutter.open_changed.connect(func(value: bool): changes.append(value))
	player = PLAYER.instantiate()
	player.automatic_physics = false
	player.position = Vector2(120, 200)
	room.add_child(player)
	driver = Driver.new()
	driver.player = player
	world.add_child(driver)
	bus = root.get_node("NoiseBus")
	bus.noise_emitted.connect(_record_noise)
	baseline = BASE_SONAR.new()
	candidate = DEMO_SONAR.new()
	world.add_child(baseline)
	world.add_child(candidate)
	for sonar in [baseline, candidate]:
		sonar.set_process(false)
		sonar.bind_level(room, player)
	await _frames(3)
	_check(shutter.relay_index == 2 and shutter.shutter_size == Vector2(24, 120), "configured dimensions and relay binding")
	_check(shutter.collision_shape.shape is RectangleShape2D and shutter.collision_shape.shape.size == shutter.shutter_size, "real rectangle matches configured dimensions")
	_check(shutter.collision_layer == 1 and not shutter.collision_shape.one_way_collision, "ordinary solid terrain blocks both directions")
	_check(not shutter.is_open and not shutter.collision_shape.disabled, "starts closed and collidable")
	_check(raw_events.is_empty(), "building closed shutter does not emit a fake transition")
	var original_transform: Transform2D = shutter.transform
	var original_shape_transform: Transform2D = shutter.collision_shape.transform
	var shape_id: int = shutter.collision_shape.get_instance_id()
	await _closed_contact(120, 1, "left")
	await _closed_contact(480, -1, "right")
	await _open_crossing(120, 1, "left to right")
	await _open_crossing(480, -1, "right to left")
	await _state_and_geometry()
	await _overlap_callback()
	await _queued_requests()
	await _transformed_origin()
	_check(shutter.transform == original_transform, "open/close preserves exact authored local transform")
	_check(shutter.collision_shape.transform == original_shape_transform, "open/close preserves exact collider local transform")
	_check(shutter.collision_shape.get_instance_id() == shape_id, "same physical collider survives every transition")
	await _pre_tree_and_detach()
	for path in hashes: _check(hashes[path] == FileAccess.get_sha256(path), "preserved source unchanged: " + path)
	var report := {"suite": "detachable relay shutter", "hz": hz, "checks": checks, "failures": failures,
		"real_physics_steps": driver.steps, "crossings": crossings, "physical_wall_contacts": driver.contact_receipts, "transition_events": raw_events,
		"state_change_signals": changes, "preserved_hashes": hashes,
		"execution": "Actual Godot physics callbacks, unchanged production PC input/motor wall responses plus independent live test_move collider receipts; real Area2D body_entered flush; both preserved and demo sonar listeners. No elapsed timer is used as evidence of blocking or passage."}
	var output := "res://demo/evidence/relay_shutter_%dhz.json" % hz
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(report, "  ") + "\n")
	print("RELAY SHUTTER %d Hz: %d checks, %d failures" % [hz, checks.size(), failures.size()])
	for failure in failures: printerr(failure)
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _closed_contact(start_x: float, direction: int, side: String) -> void:
	shutter.reset()
	await _frames(2)
	player.reset_actor(Vector2(start_x, 200), direction)
	driver.contacts.clear()
	driver.frame = {"right": direction}
	var touched := await _until(func(): return driver.contacts.has(shutter.get_instance_id()), hz * 2)
	_check(touched, "closed " + side + " approach produces real motor wall response and touching-shutter identity")
	var correct_side: bool = player.position.x <= 280.1 if direction > 0 else player.position.x >= 319.9
	_check(correct_side and player.grounded, "closed " + side + " contact blocks grounded PC on entry side", str(player.position))
	driver.frame = {}

func _open_crossing(start_x: float, direction: int, label: String) -> void:
	shutter.set_open(true)
	await _frames(2)
	player.reset_actor(Vector2(start_x, 200), direction)
	driver.contacts.clear()
	driver.frame = {"right": direction}
	var crossed := await _until(func(): return player.position.x > 350 if direction > 0 else player.position.x < 250, hz * 2)
	_check(crossed, "open passage traversed by actual PC " + label)
	_check(not driver.contacts.has(shutter.get_instance_id()), "open traversal has no shutter collision " + label)
	crossings.append({"direction": label, "start": start_x, "end": player.position.x, "grounded": player.grounded,
		"actual_shutter_contact": driver.contacts.has(shutter.get_instance_id()), "crossed": crossed})
	driver.frame = {}

func _shutter_records(sonar: Node) -> Array:
	return sonar.geometry.filter(func(record): return record.body_id == shutter.get_instance_id())

func _state_and_geometry() -> void:
	var before := raw_events.size()
	for _i in 20: shutter.set_open(true)
	await _frames(2)
	_check(raw_events.size() == before, "repeated open requests emit no duplicate noise")
	shutter.reset()
	await _frames(2)
	_check(raw_events.size() == before + 1 and not shutter.is_open, "reset recloses once and emits one transition")
	for _i in 20: shutter.reset()
	_check(raw_events.size() == before + 1, "repeated closed reset is silent")
	for sonar in [baseline, candidate]: sonar.refresh_geometry()
	var old_records: Array = _shutter_records(baseline)
	_check(old_records.size() == 1 and _shutter_records(candidate).size() == 1, "closed physical contour appears in both sonar implementations")
	bus.emit_noise(shutter.global_position, &"prop_impact", 0.8, room)
	shutter.set_open(true)
	await _frames(1)
	_check(shutter.is_open and shutter.collision_shape.disabled and shutter.collision_shape.is_in_group("sonar_ignore"), "open visual state and disabled ignored collider commit together")
	_check(old_records.all(func(record): return not GEOMETRY.is_live(record)), "old active-wave contour cannot render once shutter opens, even before refresh")
	for sonar in [baseline, candidate]:
		sonar.refresh_geometry()
		_check(_shutter_records(sonar).is_empty(), "open shutter has no collected geometry in " + str(sonar.get_script().resource_path))
		var tracks_clear := true
		for pulse in sonar.pulses:
			for key in pulse.tracks:
				if pulse.tracks[key].geometry.body_id == shutter.get_instance_id(): tracks_clear = false
		_check(tracks_clear, "open shutter leaves no active-wave track in " + str(sonar.get_script().resource_path))
	shutter.reset()
	await _frames(2)
	for sonar in [baseline, candidate]:
		sonar.refresh_geometry()
		_check(_shutter_records(sonar).size() == 1, "reclosed real contour returns in " + str(sonar.get_script().resource_path))
	_check(not shutter.collision_shape.is_in_group("sonar_ignore") and not shutter.collision_shape.disabled, "reset removes ignore and restores actual solidity")
	await _closed_contact(120, 1, "reset left")
	await _closed_contact(480, -1, "reset right")

func _overlap_callback() -> void:
	driver.frame = {}
	player.reset_actor(Vector2(300, 157), 1)
	# This explicit fixture placement begins embedded in the actual rectangle.
	# The PC motor is held only until the real Area2D overlap callback opens it.
	driver.set_physics_process(false)
	var trigger := Area2D.new()
	trigger.position = shutter.position
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	var trigger_shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(70, 100)
	trigger_shape.shape = box
	trigger.add_child(trigger_shape)
	var observations := {"entered": false, "physics_callback": false, "deferred": false, "overlapping": false}
	trigger.body_entered.connect(func(body):
		if body != player: return
		observations.entered = true
		observations.physics_callback = Engine.is_in_physics_frame()
		observations.overlapping = absf(player.position.x - shutter.position.x) < shutter.shutter_size.x * 0.5
		shutter.set_open(true)
		observations.deferred = not shutter.is_open and not shutter.collision_shape.disabled
	)
	room.add_child(trigger)
	_check(await _until(func(): return observations.entered and shutter.is_open, 12), "real overlapping body_entered callback opens shutter")
	_check(observations.physics_callback and observations.deferred, "collision mutation defers during actual physics-query flush")
	_check(observations.overlapping and shutter.collision_shape.disabled, "opening safely removes collision while actual PC overlaps")
	_check(player.position == Vector2(300, 157), "opening does not teleport or push overlapping PC")
	driver.set_physics_process(true)
	driver.contacts.clear()
	driver.frame = {"right": 1}
	_check(await _until(func(): return player.position.x > 355 and player.grounded, hz * 2), "embedded PC exits open shutter through normal motor and lands")
	_check(not driver.contacts.has(shutter.get_instance_id()), "overlap-safe opening leaves no stale collision")
	driver.frame = {}
	trigger.queue_free()
	await _frames(2)

func _queued_requests() -> void:
	shutter.reset()
	await _frames(2)
	var before := raw_events.size()
	await physics_frame
	shutter.set_open(true)
	shutter.set_open(false)
	await process_frame
	await _frames(1)
	_check(not shutter.is_open and not shutter.collision_shape.disabled, "queued open-close pair uses final requested closed state")
	_check(raw_events.size() == before, "uncommitted toggles emit no fictitious transitions")
	await physics_frame
	shutter.set_open(true)
	shutter.set_open(false)
	shutter.set_open(true)
	await process_frame
	await _frames(1)
	_check(shutter.is_open and shutter.collision_shape.disabled, "queued open-close-open commits final open state")
	_check(raw_events.size() == before + 1, "coalesced physics requests produce one real transition noise")
	_check(changes.size() == raw_events.size(), "one state-change signal per real audible transition")

func _transformed_origin() -> void:
	driver.set_physics_process(false)
	var room_transform := room.transform
	room.transform = Transform2D(0.23, Vector2(1.1, 0.8), 0.17, Vector2(47, -22))
	var exact_global: Transform2D = shutter.global_transform
	var exact_shape_global: Transform2D = shutter.collision_shape.global_transform
	var before := raw_events.size()
	shutter.reset()
	shutter.set_open(true)
	_check(raw_events.size() == before + 2, "transformed shutter produces only its two transitions")
	for event in raw_events.slice(before):
		_check(event.origin == exact_global.origin and event.source_id == shutter.get_instance_id() and event.source_in_room, "transition noise has exact real world origin and room-descendant provenance")
		_check(event.kind == "prop_impact" and is_equal_approx(event.loudness, 0.8), "transition uses supported ordinary prop_impact profile")
		_check(event.committed_open == event.disabled and event.disabled == event.sonar_ignore, "noise observers see coherent committed collider state")
	_check(shutter.global_transform == exact_global and shutter.collision_shape.global_transform == exact_shape_global, "nonuniform rotated skewed hierarchy transform preserved exactly")
	for sonar in [baseline, candidate]:
		_check(sonar.event_history.back().origin == exact_global.origin and sonar.event_history.back().source_id == shutter.get_instance_id(), "actual sonar consumer accepts room-scoped transition origin")
	room.transform = room_transform

func _pre_tree_and_detach() -> void:
	var detached = SHUTTER.new()
	detached.set_open(true)
	detached.configure(Vector2(18, 88), 4)
	var before: int = bus.event_count
	room.add_child(detached)
	_check(detached.is_open and detached.collision_shape.disabled and detached.collision_shape.is_in_group("sonar_ignore"), "pre-tree open state installs without a blocking spawn frame")
	_check(bus.event_count == before, "pre-tree configuration remains silent")
	detached.reset()
	_check(not detached.is_open and not detached.collision_shape.disabled, "pre-opened instance can reclose")
	detached.configure(Vector2(30, 100), 5)
	_check(detached.collision_shape.shape.size == Vector2(30, 100) and detached.relay_index == 5, "runtime configure updates actual rectangle and relay index")
	detached.queue_free()
	for sonar in [baseline, candidate]: sonar.refresh_geometry()
	var records: Array = _shutter_records(baseline)
	shutter.reset()
	for sonar in [baseline, candidate]: sonar.refresh_geometry()
	records = _shutter_records(baseline)
	room.remove_child(shutter)
	_check(records.all(func(record): return not GEOMETRY.is_live(record)), "detaching component immediately invalidates prior live contour")
	before = bus.event_count
	shutter.set_open(true)
	_check(bus.event_count == before, "detached state changes emit no unscoped sound")
	room.add_child(shutter)
	_check(shutter.is_open and shutter.collision_shape.disabled and shutter.get_child_count() == 1, "reattach keeps state and single collider")
	for sonar in [baseline, candidate]:
		sonar.refresh_geometry()
		_check(_shutter_records(sonar).is_empty(), "reattached open shutter contributes no ghost geometry")
