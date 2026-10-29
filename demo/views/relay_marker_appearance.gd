@tool
extends Resource
## Paint only. The marker's authored contour remains fixed and nonblocking.
@export var inactive_ink := Color("e7b779"):
	set(value):
		inactive_ink = value
		emit_changed()
@export var active_ink := Color("9ce5bd"):
	set(value):
		active_ink = value
		emit_changed()
@export var label := "RELAY":
	set(value):
		label = value
		emit_changed()
@export var font: Font:
	set(value):
		if font != null and font.changed.is_connected(_font_changed): font.changed.disconnect(_font_changed)
		font = value
		if font != null and not font.changed.is_connected(_font_changed): font.changed.connect(_font_changed)
		emit_changed()
@export_range(1,256,1,"or_greater") var font_size := 8:
	set(value):
		if value < 1: return
		font_size = value
		emit_changed()
func _font_changed() -> void:
	emit_changed()
