@tool
extends Node2D
## No gameplay or collision authority. Explicit immutable authored raster origin.
const Appearance = preload("res://demo/views/onward_marker_appearance.gd")
var is_open := false:
	set(value):
		is_open = value
		queue_redraw()
var ending := false:
	set(value):
		ending = value
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
	var gate := raster_reference
	var ink: Color = appearance.open_ink if is_open else appearance.closed_ink
	var face: Font = appearance.font if appearance.font != null else ThemeDB.fallback_font
	draw_set_transform(-raster_reference)
	draw_rect(Rect2(gate-Vector2(20,76),Vector2(40,76)),appearance.fill)
	draw_rect(Rect2(gate-Vector2(20,76),Vector2(40,76)),ink,false,1)
	for i in range(3): draw_line(gate+Vector2(-14,-65+i*8),gate+Vector2(14,-65+i*8),ink,0.8)
	draw_string(face,gate+Vector2(-32,-86),appearance.ending_label if ending else appearance.onward_label,HORIZONTAL_ALIGNMENT_LEFT,-1,appearance.font_size,ink)
	draw_set_transform(Vector2.ZERO)
