@tool
extends "res://combat_pc/components/climbable.gd"
## Production climbable plus its passive nonblocking collision-derived contour.
## Base controller contract, sensor and artwork remain inherited unchanged.
func _update_sensor() -> void:
	super._update_sensor()
	if not is_inside_tree(): return
	var rails := get_node_or_null("SonarRails") as StaticBody2D
	if rails == null:
		rails = StaticBody2D.new()
		rails.name = "SonarRails"
		rails.collision_layer = 0
		rails.collision_mask = 0
		var shape := CollisionShape2D.new()
		shape.name = "Contour"
		shape.shape = RectangleShape2D.new()
		rails.add_child(shape)
		add_child(rails)
	rails.position = Vector2(0, -height * 0.5)
	rails.get_node("Contour").shape.size = Vector2(width, height)
