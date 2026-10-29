@tool
extends Node2D
## Bottom-center cache paint and enabled nonblocking contour. Host owns collection.
## Cached geometry consumers must refresh on this signal and after tree edits.
signal geometry_invalidated
const Appearance = preload("res://demo/views/field_cache_appearance.gd")
@export var is_found := false:
	set(value):
		var changed := is_found != value
		is_found = value
		_sync_state()
		if changed: geometry_invalidated.emit()
@export var raster_reference := Vector2.ZERO:
	set(value):
		if not value.is_finite(): return
		raster_reference = value
		_sync_state()
@export var appearance: Appearance:
	set(value):
		appearance = value
		_sync_state()
func _ready() -> void:
	_sync_state()
func _sync_state() -> void:
	var contour := get_node_or_null("CacheContour")
	if contour != null:
		if is_found: contour.add_to_group("sonar_ignore")
		elif contour.is_in_group("sonar_ignore"): contour.remove_from_group("sonar_ignore")
	var view := get_node_or_null("View")
	if view == null: return
	view.is_found = is_found
	view.raster_reference = raster_reference
	view.appearance = appearance
