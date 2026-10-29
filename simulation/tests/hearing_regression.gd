extends SceneTree
const Query = preload("res://simulation/components/hearing_query.gd")
const Profile = preload("res://simulation/resources/hearing_profile.gd")
const Sensor = preload("res://simulation/components/hearing_sensor.tscn")
const Bus = preload("res://scripts/sensory/noise_bus.gd")
const PC = preload("res://combat_pc/player.tscn")
const NPC = preload("res://demo/components/enemy.tscn")
const Prop = preload("res://combat_pc/fixtures/contact_noise_prop.tscn")
var world: Node2D
var checks := 0
var failures: Array[String] = []
var hz := 120
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func _surface(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)
	return body
func _run() -> void:
	world = Node2D.new()
	root.add_child(world)
	var bus := Bus.new()
	world.add_child(bus)
	var a := Node2D.new()
	a.position = Vector2(100, 200)
	world.add_child(a)
	var source := Node2D.new()
	world.add_child(source)
	var p := Profile.new()
	p.ear_offset = Vector2.ZERO
	p.range_at_unit_loudness = 100
	_check(not Query.sample(a, Vector2(200,200), 1, source, p).is_empty(), "exact threshold audible")
	_check(Query.sample(a, Vector2(200.01,200), 1, source, p).is_empty(), "outside threshold silent")
	_check(not Query.sample(a, Vector2(120,200), 0.01, source, p).is_empty(), "minimum loudness clamp")
	_check(Query.sample(a, Vector2(300.01,200), 99, source, p).is_empty(), "maximum loudness clamp")
	_check(Query.sample(a, a.position, 1, a, p).is_empty(), "self excluded by capability")
	_check(Query.sample(a, Vector2(NAN,0), 1, source, p).is_empty(), "invalid origin rejected")
	_check(Query.sample(a, a.position, NAN, source, p).is_empty(), "invalid loudness rejected")
	p.gain = NAN
	_check(Query.sample(a, a.position, 1, source, p).is_empty(), "invalid profile rejected")
	p.gain = 1
	p.hearing_enabled = false
	_check(Query.sample(a, a.position, 1, source, p).is_empty(), "deaf capability rejects evidence")
	p.hearing_enabled = true
	p.minimum_loudness_scale = -2
	p.maximum_loudness_scale = -1
	_check(Query.sample(a, a.position, 1, source, p).is_empty(), "invalid loudness range rejected")
	p.minimum_loudness_scale = 0.2
	p.maximum_loudness_scale = 2
	var detached = Sensor.instantiate()
	_check(not detached.bind(a,bus), "detached sensor bind fails safely")
	detached.free()
	var sensor = Sensor.instantiate()
	sensor.listener_path = NodePath("")
	sensor.event_bus_path = NodePath("")
	sensor.profile = p
	world.add_child(sensor)
	_check(sensor.bind(a, bus), "sensor binds explicit listener and bus")
	bus.emit_noise(Vector2(140,200), &"boundary_fixture", 1.0, source)
	_check(sensor.heard_count == 1 and sensor.last_receipt.origin == Vector2(140,200), "bus keeps actual event origin")
	var copy: Dictionary = sensor.last_receipt
	copy.origin = Vector2.ZERO
	_check(sensor.last_receipt.origin == Vector2(140,200), "diagnostic receipt cannot mutate sensor history")
	sensor.bind(a, bus)
	bus.emit_noise(Vector2(140,200), &"boundary_fixture", 1.0, source)
	_check(sensor.heard_count == 2, "rebind does not duplicate subscription")
	sensor.enabled = false
	bus.emit_noise(Vector2(140,200), &"boundary_fixture", 1.0, source)
	_check(sensor.heard_count == 2, "disabled sensor ignores events")
	sensor.enabled = true
	paused = true
	bus.emit_noise(Vector2(140,200), &"boundary_fixture", 1.0, source)
	_check(sensor.heard_count == 2, "paused sensor ignores events")
	paused = false
	var other_bus := Bus.new()
	world.add_child(other_bus)
	sensor.bind(a, other_bus)
	bus.emit_noise(Vector2(140,200), &"boundary_fixture", 1.0, source)
	_check(sensor.heard_count == 2, "old bus disconnected")
	other_bus.emit_noise(Vector2(140,200), &"boundary_fixture", 1.0, source)
	_check(sensor.heard_count == 3, "replacement bus active")
	sensor.unbind()
	other_bus.emit_noise(Vector2(140,200), &"boundary_fixture", 1.0, source)
	_check(sensor.heard_count == 3, "unbound sensor ignores events")
	# Lifetime and reparenting are validated at delivery, not only at bind.
	sensor.bind(a,bus)
	var count_before: int = sensor.heard_count
	world.remove_child(bus)
	bus.emit_noise(Vector2(140,200), &"boundary_fixture", 1.0, source)
	_check(sensor.heard_count == count_before, "detached bus cannot deliver")
	world.add_child(bus)
	a.process_mode = Node.PROCESS_MODE_DISABLED
	bus.emit_noise(Vector2(140,200), &"boundary_fixture", 1.0, source)
	_check(sensor.heard_count == count_before, "disabled bound listener cannot hear")
	a.process_mode = Node.PROCESS_MODE_INHERIT
	sensor.process_mode = Node.PROCESS_MODE_ALWAYS
	paused = true
	bus.emit_noise(Vector2(140,200), &"boundary_fixture", 1.0, source)
	_check(sensor.heard_count == count_before, "always-process sensor still respects global pause")
	paused = false
	sensor.process_mode = Node.PROCESS_MODE_INHERIT
	var viewport := SubViewport.new()
	viewport.world_2d = World2D.new()
	world.add_child(viewport)
	a.reparent(viewport)
	bus.emit_noise(Vector2(140,200), &"boundary_fixture", 1.0, source)
	_check(sensor.heard_count == count_before, "listener moved to another world cannot hear old bus")
	a.reparent(world)
	var foreign_source := Node.new()
	viewport.add_child(foreign_source)
	_check(Query.sample(a,a.position,1,foreign_source,p).is_empty(), "ordinary Node source in foreign world rejected")
	var frozen_receipts: Array[bool] = []
	sensor.heard.connect(func(receipt: Dictionary): frozen_receipts.append(receipt.is_read_only()))
	bus.emit_noise(Vector2(140,200), &"boundary_fixture", 1.0, source)
	_check(frozen_receipts == [true], "signal receipt is immutable across subscribers")
	sensor.unbind()
	# Actual solid obstruction, same-floor origin, and configured masking.
	var wall := _surface(Vector2(150,180), Vector2(10,80))
	var floor_body := _surface(Vector2(200,220), Vector2(400,40))
	await _frames(3)
	p.terrain_attenuation_enabled = true
	p.ear_offset = Vector2(0,-20)
	p.blocked_range_multiplier = 0.25
	_check(Query.sample(a, Vector2(180,180), 1, source, p).is_empty(), "wall attenuates beyond reduced range")
	p.terrain_mask = 8
	_check(not Query.sample(a, Vector2(180,180), 1, source, p).is_empty(), "off-mask wall ignored")
	p.terrain_mask = 1
	wall.queue_free()
	await _frames(3)
	var floor_receipt := Query.sample(a, Vector2(180,200), 1, source, p)
	_check(not floor_receipt.is_empty() and not floor_receipt.terrain_blocked, "real floor contact origin is not its own occluder")
	# Actual different hosts, identical relative ear geometry/profile.
	var pc = PC.instantiate()
	pc.automatic_physics = false
	pc.position = Vector2(100,200)
	world.add_child(pc)
	var npc = NPC.instantiate()
	npc.position = Vector2(300,200)
	npc.ai_enabled = false
	world.add_child(npc)
	await _frames(4)
	var pc_event := Query.sample(pc, pc.position+Vector2(40,-20), 1, source, p)
	var npc_event := Query.sample(npc, npc.position+Vector2(40,-20), 1, source, p)
	_check(not pc_event.is_empty() and not npc_event.is_empty() and is_equal_approx(pc_event.strength,npc_event.strength), "same configured hearing rule for production PC and NPC")
	# Real gravity/contact observer -> bus -> same detachable sensors.
	var pc_sensor = Sensor.instantiate()
	pc_sensor.profile = Profile.new()
	pc_sensor.profile.terrain_attenuation_enabled = true
	pc.add_child(pc_sensor)
	pc_sensor.bind(pc,bus)
	var npc_sensor = Sensor.instantiate()
	npc_sensor.profile = Profile.new()
	npc_sensor.profile.terrain_attenuation_enabled = true
	npc.add_child(npc_sensor)
	npc_sensor.bind(npc,bus)
	npc.configure(pc,bus)
	npc.detection_range = 0
	npc.ai_enabled = true
	var prop = Prop.instantiate()
	prop.position = Vector2(200,90)
	world.add_child(prop)
	prop.get_node("ImpactNoise").bind_body(prop,bus)
	await _frames(hz)
	_check(prop.get_node("ImpactNoise").emitted_count > 0, "falling crate generates real physical contact noise")
	_check(pc_sensor.heard_count > 0 and npc_sensor.heard_count > 0, "PC and NPC sensors hear actual crate impact")
	_check(npc._noise_memory > 0 and npc.ai_state == &"investigate" and npc.position.x < 295, "real contact sound leads through shared query to NPC investigation")
	_check(pc_sensor.last_receipt.source_id == prop.get_instance_id() and npc_sensor.last_receipt.source_id == prop.get_instance_id(), "physical sound source identity retained")
	# Host adapter obeys the same live-world and pause boundary as the sensor.
	var remembered: Vector2 = npc._noise_goal
	npc.process_mode = Node.PROCESS_MODE_ALWAYS
	paused = true
	bus.emit_noise(Vector2(290,200), &"lifecycle_fixture", 1.0, source)
	_check(npc._noise_goal == remembered, "paused always-process NPC cannot update hearing memory")
	paused = false
	npc.process_mode = Node.PROCESS_MODE_INHERIT
	world.remove_child(bus)
	bus.emit_noise(Vector2(290,200), &"lifecycle_fixture", 1.0, source)
	_check(npc._noise_goal == remembered, "detached bus cannot update NPC memory")
	world.add_child(bus)
	var foreign_bus := Bus.new()
	viewport.add_child(foreign_bus)
	npc.configure(pc,foreign_bus)
	foreign_bus.emit_noise(Vector2(290,200), &"lifecycle_fixture", 1.0, source)
	_check(npc._noise_goal == remembered, "foreign-world bus cannot update NPC memory")
	npc.configure(pc,bus)
	# Independent scene profiles prevent a capability edit leaking to another actor.
	var first = Sensor.instantiate()
	var second = Sensor.instantiate()
	first.profile.gain = 0
	_check(second.profile.gain == 1, "scene profiles are instance-local")
	first.free()
	second.free()
	floor_body.queue_free()
	world.queue_free()
	await _frames(2)
	print("SHARED HEARING %d Hz: %d checks, %d failures" % [hz,checks,failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
