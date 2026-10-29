@tool
extends StaticBody2D
## Center-origin static support. Configure size instead of scaling physics bodies.
## View is optional and owns paint only. No actor-role or mission-host dependency.
const Appearance = preload("res://demo/views/platform_appearance.gd")
@export var platform_size := Vector2(160,18):
	set(value):
		if not value.is_finite() or value.x <= 0.0 or value.y <= 0.0: return
		platform_size = value
		_sync()
@export var one_way_collision := false:
	set(value):
		one_way_collision = value
		_sync()
@export var one_way_collision_margin := 1.0:
	set(value):
		if not is_finite(value) or value < 0.0: return
		one_way_collision_margin = value
		_sync()
@export var appearance: Appearance:
	set(value):
		appearance = value
		_sync()
func _ready() -> void:
	# Never resize another instance's resource, including a packed-scene clone.
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider != null: collider.shape = RectangleShape2D.new()
	_sync()
func _sync() -> void:
	if not is_node_ready(): return
	var collider := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider != null:
		collider.shape.size = platform_size
		collider.one_way_collision = one_way_collision
		collider.one_way_collision_margin = one_way_collision_margin
	var view := get_node_or_null("View")
	if view != null:
		view.platform_size = platform_size
		view.appearance = appearance
