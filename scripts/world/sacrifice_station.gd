@tool
extends Node2D
const FONT: Font = preload("res://fonts/DejaVuSansMono.ttf")
@export var spent: bool = false:
	set(value):
		spent = value
		queue_redraw()
func set_spent(value: bool) -> void:
	spent = value
func _draw() -> void:
	var screen := Color("75d0ca") if not spent else Color("4d686e")
	draw_rect(Rect2(-30, -8, 60, 8), Color("2c424a"))
	draw_rect(Rect2(-24, -62, 40, 54), Color("182c35"))
	draw_rect(Rect2(-22, -61, 36, 50), Color("3a5157"), false, 2)
	draw_rect(Rect2(-18, -55, 28, 22), Color("081820"))
	var eye := PackedVector2Array([Vector2(-14, -44), Vector2(-6, -50), Vector2(4, -44), Vector2(-6, -38), Vector2(-14, -44)])
	draw_polyline(eye, screen, 1.5)
	draw_circle(Vector2(-6, -44), 3, screen)
	if spent: draw_line(Vector2(-16, -52), Vector2(6, -35), Color("cda279"), 2)
	draw_rect(Rect2(-17, -28, 25, 4), Color("718382"))
	draw_string(FONT, Vector2(-17, -16), "S-01", HORIZONTAL_ALIGNMENT_LEFT, 30, 7, Color("a1b5b5"))
	# Instrument arm and injection port make the sense trade a medical machine.
	draw_line(Vector2(13, -52), Vector2(30, -72), Color("6f8585"), 4)
	draw_line(Vector2(30, -72), Vector2(40, -65), Color("6f8585"), 3)
	draw_rect(Rect2(36, -65, 8, 14), Color("b3c4bb"))
	draw_rect(Rect2(38, -64, 4, 8), screen)
	draw_line(Vector2(40, -51), Vector2(40, -45), Color("d1d4ca"), 1)
	draw_line(Vector2(18, -30), Vector2(28, -15), Color("152029"), 4)
	draw_line(Vector2(28, -15), Vector2(34, -5), Color("263c45"), 4)
