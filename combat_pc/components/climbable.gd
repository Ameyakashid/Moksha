@tool
class_name MokshaClimbable
extends Area2D
## Original MOKSHA traversal sensor. Root is the bottom; +height extends up.
## This supplies contact geometry only. Terrain remains an ordinary collider.
@export_enum("ladder", "vine") var climb_type := "ladder":
	set(value):
		climb_type = value
		queue_redraw()
@export var enabled := true:
	set(value):
		enabled = value
		queue_redraw()
@export_range(8, 128, 1) var width := 20.0:
	set(value):
		width = maxf(8, value)
		_update_sensor()
@export_range(16, 1024, 1) var height := 140.0:
	set(value):
		height = maxf(16, value)
		_update_sensor()
@export var selection_priority := 0
@export_flags_2d_physics var sensor_layer := 16:
	set(value):
		sensor_layer = value
		collision_layer = sensor_layer
@export var draw_guide := true:
	set(value):
		draw_guide = value
		queue_redraw()

func _ready() -> void:
	collision_layer = sensor_layer
	collision_mask = 0
	monitoring = false
	monitorable = true
	add_to_group("combat_pc_climbable")
	_update_sensor()

func _update_sensor() -> void:
	if not is_inside_tree(): return
	var shape_node = get_node_or_null("SensorShape") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "SensorShape"
		add_child(shape_node)
	var rectangle = RectangleShape2D.new()
	rectangle.size = Vector2(width, height + 4)
	shape_node.shape = rectangle
	shape_node.position = Vector2(0, -height * 0.5)
	queue_redraw()

## Upright positive-scale translation is supported; skew/rotation is refused.
func climb_geometry() -> Dictionary:
	if not enabled or not is_inside_tree() or not monitorable or collision_layer == 0: return {}
	var basis = global_transform
	if absf(basis.x.y) > 0.00001 or absf(basis.y.x) > 0.00001 or basis.x.x <= 0 or basis.y.y <= 0: return {}
	var shape_node = get_node_or_null("SensorShape") as CollisionShape2D
	if shape_node == null or shape_node.disabled: return {}
	if not shape_node.shape is RectangleShape2D: return {}
	if not shape_node.shape.size.is_equal_approx(Vector2(width, height + 4)): return {}
	if not shape_node.transform.is_equal_approx(Transform2D(0, Vector2(0, -height * 0.5))): return {}
	return {"axis_x": global_position.x, "top_y": global_position.y - height * basis.y.y,
		"bottom_y": global_position.y, "width": width * basis.x.x,
		"type": climb_type, "priority": selection_priority, "rung_spacing": 12.0 * basis.y.y,
		"rung_origin_offset": (8.0 if climb_type == "vine" else 4.0) * basis.y.y}

func _draw() -> void:
	if not draw_guide: return
	var tint = Color(0.45, 0.7, 0.68, 0.75) if enabled else Color(0.45, 0.45, 0.45, 0.35)
	if climb_type == "vine":
		draw_line(Vector2(0, 0), Vector2(0, -height), tint, 1.0)
		for y in range(8, ceili(height), 12):
			draw_line(Vector2(-4, -y + 3), Vector2(4, -y - 3), tint, 1.0)
	else:
		for x in [-width * 0.3, width * 0.3]: draw_line(Vector2(x, 0), Vector2(x, -height), tint, 1.0)
		for y in range(4, ceili(height), 12): draw_line(Vector2(-width * 0.3, -y), Vector2(width * 0.3, -y), tint, 1.0)
