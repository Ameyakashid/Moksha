@tool
extends Resource
## Paint only; geometry and collection rules are not appearance parameters.
@export var ink := Color("b1c9d1"):
	set(value):
		ink = value
		emit_changed()
