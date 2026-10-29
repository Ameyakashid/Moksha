extends StaticBody2D
## Detachable, two-way relay barrier. Its rectangle is the actual collision and
## sonar source; opening never moves the body or leaves a decorative collider.
## Set shutter_size / relay_index before adding, or use configure().

signal open_changed(open: bool)

@export var shutter_size := Vector2(24, 120)
@export var relay_index := 0
@export var transition_loudness := 0.8

var is_open: bool:
	get: return _is_open
var collision_shape: CollisionShape2D:
	get: return _collision_shape

var _is_open := false
var _requested_open := false
var _commit_queued := false
var _collision_shape: CollisionShape2D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	_collision_shape = CollisionShape2D.new()
	_collision_shape.name = "ShutterCollision"
	var rectangle := RectangleShape2D.new()
	rectangle.size = _valid_size(shutter_size)
	shutter_size = rectangle.size
	_collision_shape.shape = rectangle
	_collision_shape.disabled = _requested_open
	if _requested_open: _collision_shape.add_to_group("sonar_ignore")
	add_child(_collision_shape)
	_is_open = _requested_open
	queue_redraw()

func configure(rectangle_size: Vector2, index: int) -> void:
	shutter_size = _valid_size(rectangle_size)
	relay_index = index
	if not is_instance_valid(_collision_shape): return
	if Engine.is_in_physics_frame(): _apply_size.call_deferred()
	else: _apply_size()

func _valid_size(value: Vector2) -> Vector2:
	if not value.is_finite(): return Vector2(24, 120)
	return Vector2(maxf(1.0, value.x), maxf(1.0, value.y))

func _apply_size() -> void:
	if not is_instance_valid(_collision_shape) or is_queued_for_deletion(): return
	_collision_shape.shape.size = shutter_size
	queue_redraw()

func set_open(value: bool) -> void:
	if _requested_open == value: return
	_requested_open = value
	# Pre-tree configuration is silent. Readiness installs the final requested
	# state before this collider can enter the physics space.
	if not is_instance_valid(_collision_shape): return
	if Engine.is_in_physics_frame():
		if not _commit_queued:
			_commit_queued = true
			_commit_requested.call_deferred()
	else:
		_commit_requested()

func reset() -> void:
	set_open(false)

func _commit_requested() -> void:
	_commit_queued = false
	if not is_instance_valid(_collision_shape) or is_queued_for_deletion(): return
	if _is_open == _requested_open: return
	# Commit collision, liveness and visible state together, outside a physics
	# query flush. Rapid requests in one flush use the final requested state.
	_collision_shape.disabled = _requested_open
	if _requested_open:
		_collision_shape.add_to_group("sonar_ignore")
	elif _collision_shape.is_in_group("sonar_ignore"):
		_collision_shape.remove_from_group("sonar_ignore")
	_is_open = _requested_open
	queue_redraw()
	# The actual shutter remains a child of its room, so the ordinary sonar
	# provenance filter accepts this origin and rejects old-room emissions.
	if is_inside_tree():
		var bus := get_node_or_null("/root/NoiseBus")
		if bus != null and bus.has_method("emit_noise"):
			bus.emit_noise(global_position, &"prop_impact", transition_loudness, self)
	open_changed.emit(_is_open)

func _draw() -> void:
	var bounds := Rect2(-shutter_size * 0.5, shutter_size)
	var ink := Color("8dc9ab") if _is_open else Color("d0a36e")
	draw_rect(bounds, ink, false, 0.9)
	if _is_open: return
	# Cross-braced door panels deliberately differ from climbable ladder rungs.
	draw_rect(bounds, Color(0.28,0.17,0.08,0.45), true)
	var y := bounds.position.y + 3.0
	while y < bounds.end.y - 3.0:
		var end_y := minf(y + 42.0, bounds.end.y - 3.0)
		draw_line(Vector2(bounds.position.x+3,y),Vector2(bounds.end.x-3,end_y),ink,1.2)
		draw_line(Vector2(bounds.end.x-3,y),Vector2(bounds.position.x+3,end_y),ink,1.2)
		y += 46.0
	draw_string(ThemeDB.fallback_font,Vector2(-58,bounds.end.y-65),"SEALED",HORIZONTAL_ALIGNMENT_LEFT,-1,8,ink)
