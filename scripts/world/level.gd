@tool
extends Node2D
## A placed level is a reusable collection of real world geometry and actors.
## Interaction and level transition policy are owned by the run controller.
@export var level_title: String = ""
@export var subtitle: String = ""
@export var camera_bounds: Rect2 = Rect2(0, 0, 2200, 480)
@export_file("*.tscn") var next_level_path: String = ""
@export var sensory_required: bool = false
@export_category("Sensory onboarding")
@export var first_ascent_landing_y: float = 904.0

func set_sacrifice_complete(complete: bool = true) -> void:
	var barrier := get_node_or_null("GateBarrier")
	if barrier and barrier.has_method("set_open"):
		barrier.set_open(complete)
	var station := get_node_or_null("SacrificeVisual")
	if station and station.has_method("set_spent"):
		station.set_spent(complete)
	var route := get_node_or_null("Decor/AscentSign")
	if route and route.has_method("set_active"):
		route.set_active(complete)
