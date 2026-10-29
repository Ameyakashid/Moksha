@tool
extends Resource
## White preserves the original palette. Tinting changes only presentation.
@export var tint := Color.WHITE:
	set(value):
		tint = value
		emit_changed()
