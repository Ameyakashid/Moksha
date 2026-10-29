@tool
extends Node2D
## Center-origin reusable view; no physics, room lookup, or gameplay state.
const Appearance = preload("res://demo/views/platform_appearance.gd")
@export var platform_size := Vector2(160, 18):
	set(value):
		if not value.is_finite() or value.x <= 0.0 or value.y <= 0.0: return
		platform_size = value
		queue_redraw()
@export var appearance: Appearance:
	set(value):
		if appearance != null and appearance.changed.is_connected(queue_redraw): appearance.changed.disconnect(queue_redraw)
		appearance = value
		if appearance != null and not appearance.changed.is_connected(queue_redraw): appearance.changed.connect(queue_redraw)
		queue_redraw()
func _draw() -> void:
	if appearance == null: return
	var r := Rect2(-platform_size * 0.5, platform_size)
	draw_rect(r,appearance.fill)
	draw_rect(r,appearance.outline,false,0.8)
	draw_line(r.position+Vector2(2,2),Vector2(r.end.x-2,r.position.y+2),appearance.highlight,0.8)
	if r.size.y > 20:
		draw_line(r.position+Vector2(8,8),r.end-Vector2(8,8),appearance.brace,1)
		draw_line(Vector2(r.end.x-8,r.position.y+8),Vector2(r.position.x+8,r.end.y-8),appearance.brace,1)
