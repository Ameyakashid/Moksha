@tool
extends Node2D
const FONT: Font = preload("res://fonts/DejaVuSansMono.ttf")
@export var unlocked: bool = true:
	set(value):
		unlocked = value
		queue_redraw()
@export var caption: String = "ARCOLOGY":
	set(value):
		caption = value
		queue_redraw()

func set_unlocked(value: bool) -> void:
	unlocked = value

func _draw() -> void:
	var light := Color("7cd2ce") if unlocked else Color("c98f53")
	draw_rect(Rect2(-43, -123, 86, 123), Color("0c1921"))
	draw_rect(Rect2(-39, -119, 78, 119), Color("253d46"))
	draw_rect(Rect2(-30, -101, 60, 101), Color("060f18"))
	for x in [-27, 3]:
		draw_rect(Rect2(x, -98, 24, 97), Color("142832"))
		for y in range(-94, 0, 12):
			draw_line(Vector2(x + 2, y), Vector2(x + 21, y), Color("253a43"), 1)
	draw_rect(Rect2(-38, -101, 3, 88), light)
	draw_rect(Rect2(35, -101, 3, 88), light)
	draw_rect(Rect2(-30, -113, 60, 7), Color("090f17"))
	draw_string(FONT, Vector2(-29, -106), caption, HORIZONTAL_ALIGNMENT_CENTER, 58, 7, light)
	draw_rect(Rect2(-44, -3, 88, 3), Color("6b9196"))
	for x in range(-40, 42, 12):
		draw_line(Vector2(x, -2), Vector2(x + 5, -2), Color("d19a56"), 1)
	# Reader on the right jamb, rather than a fantasy portal effect.
	draw_rect(Rect2(43, -47, 11, 22), Color("233c46"))
	draw_rect(Rect2(45, -44, 7, 8), light)
