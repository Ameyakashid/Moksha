extends Node2D
## Detachable physical receiver. Origin is the interior floor's centre/top.
## Only the currently bound, intact production prop can latch it. Real contact
## with this basin's floor is required; an Area2D overlap alone proves nothing.
signal latched(prop: RigidBody2D)
signal status_changed(status: String)

const PROP = preload("res://prop.gd")
@export var interior_width := 160.0
@export var entry_lip_height := 8.0
@export var backstop_height := 68.0
@export var backstop_width := 40.0
@export var wall_thickness := 10.0
@export var floor_thickness := 12.0
@export var settle_seconds := 0.22
@export var maximum_speed := 34.0
@export var maximum_spin := 2.0
@export var simulation_enabled := true

var is_latched := false
var status := "missing"
var cargo: RigidBody2D
var detector: Area2D
var basin_floor: StaticBody2D
var _settled_for := 0.0
var _pieces: Array[Rect2] = []

func _ready() -> void:
	interior_width = maxf(80.0, interior_width)
	wall_thickness = maxf(4.0, wall_thickness)
	floor_thickness = maxf(4.0, floor_thickness)
	entry_lip_height = maxf(2.0, entry_lip_height)
	backstop_height = maxf(40.0, backstop_height)
	backstop_width = maxf(wall_thickness, backstop_width)
	var half := interior_width * 0.5
	basin_floor = _solid("BasinFloor", Rect2(-half, 0, interior_width, floor_thickness))
	_solid("EntryLip", Rect2(-half - wall_thickness, -entry_lip_height, wall_thickness, entry_lip_height + floor_thickness))
	_solid("Backstop", Rect2(half, -backstop_height, backstop_width, backstop_height + floor_thickness))
	detector = Area2D.new()
	detector.name = "CargoDetector"
	detector.collision_layer = 0
	detector.collision_mask = 8
	detector.monitorable = false
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(interior_width, backstop_height)
	shape.shape = box
	shape.position = Vector2(0, -backstop_height * 0.5)
	detector.add_child(shape)
	add_child(detector)
	queue_redraw()

func _solid(label: String, rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = label
	body.position = rect.get_center()
	body.collision_layer = 1
	body.collision_mask = 0
	# A real rubber-lined basin absorbs bounce without touching the prop's
	# tuning, velocity, rotation, charge, damage or solver state.
	var material := PhysicsMaterial.new()
	material.friction = 1.0
	material.rough = true
	material.bounce = 0.4
	material.absorbent = true
	body.physics_material_override = material
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	add_child(body)
	_pieces.append(rect)
	return body

func bind_cargo(value: RigidBody2D) -> void:
	if is_latched: return
	cargo = value
	_settled_for = 0.0
	_set_status("ready" if _valid_cargo() else "missing")

func _valid_cargo() -> bool:
	return is_instance_valid(cargo) and not cargo.is_queued_for_deletion() and cargo is PROP \
		and cargo.alive and cargo.is_inside_tree() and bool(cargo.get_meta("freight_valid", true))

func _physics_process(dt: float) -> void:
	if is_latched or not simulation_enabled: return
	if not _valid_cargo():
		_settled_for = 0.0
		_set_status("missing")
		return
	if not cargo.simulation_enabled: return
	if not is_supported_and_slow(cargo):
		_settled_for = 0.0
		_set_status("in_transit" if cargo.hit_count > 0 else "ready")
		return
	_set_status("seating")
	_settled_for += dt
	if _settled_for >= maxf(0.08, settle_seconds):
		is_latched = true
		_set_status("delivered")
		# Physical receiver origin, never the player/listener or an E marker.
		var bus := get_node_or_null("/root/NoiseBus")
		if is_instance_valid(bus) and bus.has_method("emit_noise"):
			bus.emit_noise(global_position, &"prop_impact", 1.15, self)
		latched.emit(cargo)
		queue_redraw()

func is_supported_and_slow(body: RigidBody2D) -> bool:
	if body != cargo or not _valid_cargo() or not is_instance_valid(detector): return false
	if body.freeze or not detector.overlaps_body(body): return false
	if body.linear_velocity.length() > maximum_speed or absf(body.angular_velocity) > maximum_spin: return false
	var local := to_local(body.global_position)
	if absf(local.x) > interior_width * 0.5 - 12.0 or local.y > -6.0 or local.y < -25.0: return false
	# Contact identity and upward normal rule out fly-throughs, wall scrapes,
	# unsupported frozen crates and props resting on a player/another prop.
	var direct := PhysicsServer2D.body_get_direct_state(body.get_rid())
	if direct == null: return false
	for index in direct.get_contact_count():
		if direct.get_contact_collider_object(index) != basin_floor: continue
		var normal := direct.get_contact_local_normal(index)
		if normal.dot(global_transform.y.normalized()) < -0.55: return true
	return false

func _set_status(value: String) -> void:
	if status == value: return
	status = value
	status_changed.emit(status)
	queue_redraw()

func _draw() -> void:
	var ink := Color("a5e6cc") if is_latched else Color("d0b280")
	for rect in _pieces:
		draw_rect(rect, Color("142a2c"))
		draw_rect(rect, ink, false, 1.0)
	var label := "FREIGHT SEATED" if is_latched else "CARGO RECEIVER"
	draw_string(ThemeDB.fallback_font, Vector2(-interior_width * 0.5, -backstop_height - 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, ink)
