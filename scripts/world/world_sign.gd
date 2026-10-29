@tool
extends Node2D
## World-space wayfinding, separate from the HUD. Arrow origin is the sign center.
const FONT: Font = preload("res://fonts/DejaVuSansMono.ttf")
@export var caption: String = "SERVICE":
	set(value):
		caption = value
		queue_redraw()
@export var detail: String = "":
	set(value):
		detail = value
		queue_redraw()
@export var arrow: Vector2 = Vector2.RIGHT:
	set(value):
		arrow = value
		queue_redraw()
@export var sign_width: float = 112:
	set(value):
		sign_width = value
		queue_redraw()
@export var active: bool = true:
	set(value):
		active = value
		queue_redraw()

func set_active(value: bool) -> void:
	active = value

func _draw() -> void:
	var ink := Color("8ebfc0") if active else Color("a1774e")
	draw_rect(Rect2(-sign_width / 2, -22, sign_width, 38), Color("10232b"))
	draw_rect(Rect2(-sign_width / 2, -22, sign_width, 38), Color("42565b"), false, 1)
	draw_rect(Rect2(-sign_width / 2 + 3, -19, 2, 32), ink)
	draw_string(FONT, Vector2(-sign_width / 2 + 10, -8), caption, HORIZONTAL_ALIGNMENT_LEFT, sign_width - 20, 9, ink)
	if not detail.is_empty(): draw_string(FONT, Vector2(-sign_width / 2 + 10, 5), detail, HORIZONTAL_ALIGNMENT_LEFT, sign_width - 25, 7, Color("9baaab"))
	var origin := Vector2(sign_width / 2 - 17, 5)
	var direction := arrow.normalized()
	if direction.length() > 0:
		draw_line(origin - direction * 7, origin + direction * 7, ink, 2)
		draw_line(origin + direction * 7, origin + direction * 2 + direction.orthogonal() * 4, ink, 2)
		draw_line(origin + direction * 7, origin + direction * 2 - direction.orthogonal() * 4, ink, 2)
