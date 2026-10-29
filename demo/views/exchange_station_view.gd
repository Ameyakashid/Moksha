@tool
extends Node2D
## No gameplay or collision authority. Explicit immutable authored raster origin.
const Appearance = preload("res://demo/views/exchange_station_appearance.gd")
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
	draw_rect(Rect2(p-Vector2(16,42),Vector2(32,42)),appearance.outline,false,1)
	draw_circle(p+Vector2(0,-28),7,appearance.ink,false,1)
	draw_line(p+Vector2(-8,-28),p+Vector2(8,-28),appearance.ink,1)
	draw_string(face,p+Vector2(-39,-54),appearance.label,HORIZONTAL_ALIGNMENT_LEFT,-1,appearance.font_size,appearance.ink)
	draw_set_transform(Vector2.ZERO)
