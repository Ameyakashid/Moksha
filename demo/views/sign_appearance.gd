@tool
extends Resource
## Decorative text paint only. Null font uses the original engine fallback font.
@export var font: Font:
	set(value):
		if font != null and font.changed.is_connected(_font_changed): font.changed.disconnect(_font_changed)
		font = value
		if font != null and not font.changed.is_connected(_font_changed): font.changed.connect(_font_changed)
		emit_changed()
@export_range(1,256,1,"or_greater") var font_size := 9:
	set(value):
		if value < 1: return
		font_size = value
		emit_changed()
@export var font_color := Color("89b2b6"):
	set(value):
		font_color = value
		emit_changed()
@export var alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT:
	set(value):
		if value < HORIZONTAL_ALIGNMENT_LEFT or value > HORIZONTAL_ALIGNMENT_FILL: return
		alignment = value
		emit_changed()
@export var width := -1.0:
	set(value):
		if not is_finite(value) or (value < 0.0 and value != -1.0): return
		width = value
		emit_changed()
func _font_changed() -> void:
	emit_changed()
