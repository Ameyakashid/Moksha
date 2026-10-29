@tool
extends Node2D
## Bottom-center placeable indicator and always-enabled, nonblocking sonar contour.
## Presentation and contour only. Host owns sight-trade choice and consequences.
const Appearance = preload("res://demo/views/exchange_station_appearance.gd")
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
	view.raster_reference = raster_reference
	view.appearance = appearance
