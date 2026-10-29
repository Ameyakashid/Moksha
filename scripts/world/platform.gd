@tool
extends StaticBody2D
## Origin is the left end of the WALKABLE TOP. Width/depth drive both art and
## RectangleShape2D; the bright metal lip is exactly y=0, never a fake ledge.
const PAVEMENT: Texture2D = preload("res://assets/environment/pavement_segment.tres")
const LEDGE: Texture2D = preload("res://assets/environment/raised_ledge.tres")
@export_range(16.0, 2400.0, 1.0) var width: float = 160.0:
	set(value):
		width = value
		_sync()
@export_range(8.0, 500.0, 1.0) var depth: float = 20.0:
	set(value):
		depth = value
		_sync()
## Raised decks allow upward passage, then catch actors and props on descent.
## Floors, walls, stairs, and other solid architecture leave this disabled.
@export var one_way_collision: bool = false:
	set(value):
		one_way_collision = value
		_sync()
@export_enum("Pavement", "Steel", "Service") var art_style: int = 1:
	set(value):
		art_style = value
		queue_redraw()
@export var edge_color := Color("729da0"):
	set(value):
		edge_color = value
		queue_redraw()
@export var hazard_edge: bool = false:
	set(value):
		hazard_edge = value
		queue_redraw()

func _ready() -> void:
	add_to_group("terrain")
	_sync()

func _sync() -> void:
	if not is_inside_tree(): return
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider:
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(width, depth)
		collider.shape = rectangle
		collider.position = Vector2(width * 0.5, depth * 0.5)
		collider.one_way_collision = one_way_collision
	queue_redraw()

func _draw() -> void:
	var base := Color("15282f") if art_style != 0 else Color("243037")
	draw_rect(Rect2(0, 0, width, depth), base)
	if depth > 24:
		for x in range(0, int(width), 64):
			draw_rect(Rect2(x + 3, 19, minf(58, width - x - 3), depth - 22), Color("1c323a"))
			draw_line(Vector2(x + 3, 21), Vector2(minf(x + 61, width), depth - 2), Color("263e46"), 1.0)
	var tex := PAVEMENT if art_style == 0 else LEDGE
	var tile_width := 128.0 if art_style == 0 else 96.0
	var x := 0.0
	while x < width:
		var segment := minf(tile_width, width - x)
		# Crop the last tile rather than stretching a tiny fragment.
		draw_texture_rect_region(tex, Rect2(x, 1, segment, minf(depth - 1, 16)), Rect2(0, 0, tex.get_width() * segment / tile_width, tex.get_height()), Color(0.77, 0.87, 0.9))
		x += tile_width
	draw_line(Vector2.ZERO, Vector2(width, 0), edge_color, 2.0)
	draw_line(Vector2(0, depth - 1), Vector2(width, depth - 1), Color("0b141c"), 2.0)
	if hazard_edge:
		for stripe in range(8, int(width - 4), 24):
			draw_line(Vector2(stripe, 3), Vector2(stripe + 8, 3), Color("c99850"), 2.0)
	for bolt in [5.0, width - 5]:
		draw_rect(Rect2(bolt - 1, 6, 2, 2), Color("607a80"))
