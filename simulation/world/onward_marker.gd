@tool
extends Node2D
## Bottom-center placeable indicator and always-enabled, nonblocking sonar contour.
## is_open is paint input only. Host decides interactions and completion.
const Appearance = preload("res://demo/views/onward_marker_appearance.gd")
@export var is_open := false:
	set(value):
		is_open = value
		_sync_view()
@export var ending := false:
	set(value):
		ending = value
		_sync_view()
@export var raster_reference := Vector2.ZERO:
	set(value):
		if not value.is_finite(): return
		raster_reference = value
		_sync_view()
@export var appearance: Appearance:
	set(value):
		appearance = value
		_sync_view()
func _ready() -> void:
	_sync_view()
func _sync_view() -> void:
	var view := get_node_or_null("View")
	if view == null: return
	view.is_open = is_open
	view.ending = ending
	view.raster_reference = raster_reference
	view.appearance = appearance
