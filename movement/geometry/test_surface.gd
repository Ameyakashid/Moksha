@tool
extends StaticBody2D
## Editor-placeable collision and outline stay linked. Local points form a convex
## polygon; use one piece per slope/platform. No hidden world-building code.
@export var points: PackedVector2Array = PackedVector2Array([Vector2(0,0),Vector2(200,0),Vector2(200,20),Vector2(0,20)]):
	set(value):
		points = value
		if is_node_ready(): _sync()
@export var one_way: bool = false:
	set(value):
		one_way = value
		if is_node_ready(): _sync()
@export var label: String = "":
	set(value):
		label = value
		queue_redraw()
func _ready() -> void: _sync()
func _sync() -> void:
	var collision := $Collision as CollisionPolygon2D
	collision.polygon = points
	collision.one_way_collision = one_way
	collision.one_way_collision_margin = 4.0
	queue_redraw()
func _draw() -> void:
	if points.size() < 3: return
	draw_colored_polygon(points, Color("14212a"))
	var outline := points.duplicate()
	outline.append(points[0])
	draw_polyline(outline,Color("75909e") if not one_way else Color("94c6bc"),1.0)
	if not label.is_empty(): draw_string(ThemeDB.fallback_font, points[0]+Vector2(3,16),label,HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("9daeb7"))
