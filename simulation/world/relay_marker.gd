@tool
extends Node2D
## Bottom-center placeable indicator and always-enabled, nonblocking sonar contour.
## Presentation and contour only. Host owns activation, noise, shutters and mission consequences.
const Appearance = preload("res://demo/views/relay_marker_appearance.gd")
@export var is_active := false:
	set(value):
		is_active = value
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
	view.is_active = is_active
	view.raster_reference = raster_reference
	view.appearance = appearance
