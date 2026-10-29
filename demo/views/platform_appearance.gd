@tool
extends Resource
## Paint only. Physical dimensions and one-way rules belong to the platform.
@export var fill := Color("10232c"):
	set(value):
		fill = value
		emit_changed()
@export var outline := Color("5b7f87"):
	set(value):
		outline = value
		emit_changed()
@export var highlight := Color("a7c1bd"):
	set(value):
		highlight = value
		emit_changed()
@export var brace := Color("182c35"):
	set(value):
		brace = value
		emit_changed()
