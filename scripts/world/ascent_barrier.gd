@tool
extends StaticBody2D
@export var open: bool = false:
	set(value):
		open = value
		_update_state()
@export var height: float = 135.0:
	set(value):
		height = value
		_update_state()
func _ready() -> void:
	add_to_group("terrain")
	_update_state()
func set_open(value: bool) -> void:
	open = value
func _update_state() -> void:
	if is_inside_tree():
		var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
		if collider:
			var rectangle := RectangleShape2D.new()
			rectangle.size = Vector2(12, height)
			collider.shape = rectangle
			collider.position = Vector2(0, -height * 0.5)
			collider.set_deferred("disabled", open)
	queue_redraw()
func _draw() -> void:
	if open:
		draw_rect(Rect2(-6, -3, 12, 3), Color("85c9c6"))
		return
	draw_rect(Rect2(-6, -height, 12, height), Color("3c4243"))
	draw_rect(Rect2(-3, -height + 4, 6, height - 8), Color("162932"))
	for y in range(-int(height) + 8, -4, 12):
		draw_line(Vector2(-4, y), Vector2(4, y + 6), Color("d29a59"), 2)
