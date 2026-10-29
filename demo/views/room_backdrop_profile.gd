class_name RoomBackdropProfile
extends Resource
## Decorative local bounds only. The bottom edge is the authored floor baseline;
## intentional drawing overscan is not clipped to these bounds.
@export var room_bounds := Rect2(0, -100, 700, 400):
	set(value):
		room_bounds = value
		emit_changed()
@export_enum("interior", "city") var theme := "interior":
	set(value):
		theme = value
		emit_changed()
@export var visual_seed := 0:
	set(value):
		visual_seed = value
		emit_changed()

func has_valid_bounds() -> bool:
	return room_bounds.position.is_finite() and room_bounds.size.is_finite() and room_bounds.end.is_finite() and room_bounds.size.x > 0.0 and room_bounds.size.y > 0.0
