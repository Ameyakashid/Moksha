@tool
extends Resource
## Paint only; dimensions/material/support live on the floor asset.
@export var fill := Color("101f27"):
	set(value):
		fill = value
		emit_changed()
@export var outline := Color("5b7f87"):
	set(value):
		outline = value
		emit_changed()
@export var hatch := Color("182c35"):
	set(value):
		hatch = value
		emit_changed()
