@tool
extends Node2D
## Optional paint. Found differs from hidden: only the root changes sonar membership.
const Appearance = preload("res://demo/views/field_cache_appearance.gd")
var is_found := false:
	set(value):
		is_found = value
		queue_redraw()
var raster_reference := Vector2.ZERO:
	set(value):
		raster_reference = value
		queue_redraw()
var appearance: Appearance:
	set(value):
		if appearance != null and appearance.changed.is_connected(queue_redraw): appearance.changed.disconnect(queue_redraw)
		appearance = value
		if appearance != null and not appearance.changed.is_connected(queue_redraw): appearance.changed.connect(queue_redraw)
		queue_redraw()
func _draw() -> void:
	if appearance == null or is_found: return
	var p := raster_reference
	draw_set_transform(-raster_reference)
	draw_rect(Rect2(p-Vector2(8,18),Vector2(16,18)),appearance.ink,false,1)
	draw_line(p+Vector2(-4,-9),p+Vector2(4,-9),appearance.ink,1)
	draw_set_transform(Vector2.ZERO)
