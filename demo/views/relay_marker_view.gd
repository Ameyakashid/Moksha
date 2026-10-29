@tool
extends Node2D
## No gameplay or collision authority. Explicit immutable authored raster origin.
const Appearance = preload("res://demo/views/relay_marker_appearance.gd")
var is_active := false:
	set(value):
		is_active = value
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
	if appearance == null: return
	var p := raster_reference
	var face: Font = appearance.font if appearance.font != null else ThemeDB.fallback_font
	draw_set_transform(-raster_reference)
	var ink: Color = appearance.active_ink if is_active else appearance.inactive_ink
	draw_rect(Rect2(p-Vector2(11,31),Vector2(22,31)),ink,false,1)
	draw_circle(p+Vector2(0,-19),4,ink)
	draw_string(face,p+Vector2(-18,-40),appearance.label,HORIZONTAL_ALIGNMENT_LEFT,-1,appearance.font_size,ink)
	draw_set_transform(Vector2.ZERO)
