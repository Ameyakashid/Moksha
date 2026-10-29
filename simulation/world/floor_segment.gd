@tool
extends Node2D
## Placement/configuration root, NOT a physics body. Support owns the collider.
## Compose existing static support; dimensions, not scaled bodies, set physical size.
const Appearance = preload("res://demo/views/floor_appearance.gd")
@export var segment_size := Vector2(320,80):
	set(value):
		if not value.is_finite() or value.x <= 0.0 or value.y <= 0.0: return
		segment_size = value
		_sync()
@export var hatch_reference_x := 0.0:
	set(value):
		if not is_finite(value): return
		hatch_reference_x = value
		_sync()
@export var appearance: Appearance:
	set(value):
		appearance = value
		_sync()
@export var physics_material: PhysicsMaterial:
	set(value):
		physics_material = value
		_sync()
func _ready() -> void:
	_sync()
func _sync() -> void:
	if not is_node_ready(): return
	var support := get_node_or_null("Support")
	if support != null:
		support.platform_size = segment_size
		support.one_way_collision = false
		support.appearance = null
		support.physics_material_override = physics_material
	var view := get_node_or_null("View")
	if view != null:
		view.segment_size = segment_size
		view.hatch_reference_x = hatch_reference_x
		view.appearance = appearance
