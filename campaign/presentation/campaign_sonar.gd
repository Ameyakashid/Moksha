extends "res://demo/components/mission_sonar.gd"
## Campaign-only cache retirement. Sampling, propagation and drawing are inherited.
## The preserved demo adapter keeps its original source and scene behavior.

func bind_level(level: Node2D, player: Node2D) -> void:
	for shape_id in _watched_shapes.keys(): _retire_shape_watch(shape_id)
	super.bind_level(level, player)

func _retire_shape_watch(shape_id: int) -> void:
	# Instance IDs are non-owning. A retired resource must not be kept alive just
	# so its changed signal can be disconnected when the next room loads.
	if is_instance_id_valid(shape_id):
		var shape = instance_from_id(shape_id)
		if shape is Shape2D and shape.changed.is_connected(_invalidate_shape_cache):
			shape.changed.disconnect(_invalidate_shape_cache)
	_watched_shapes.erase(shape_id)

func _collect_cached_geometry() -> Array[Dictionary]:
	var result := super._collect_cached_geometry()
	var live_nodes := {}
	var live_shapes := {}
	var live_bounds := {}
	for record in result:
		var anchor = record.anchor.get_ref()
		if anchor is CollisionShape2D and is_instance_valid(anchor.shape):
			live_nodes[anchor.get_instance_id()] = true
			live_shapes[anchor.shape.get_instance_id()] = true
		live_bounds[str(record.key) + ":" + str(record.fingerprint)] = true
	# Freight recovery can retire shapes without a district transition. Prune
	# only missing entries; retained records and live pulse timing stay intact.
	for key in _shape_cache.keys():
		if not live_nodes.has(key): _shape_cache.erase(key)
	for shape_id in _watched_shapes.keys():
		if not live_shapes.has(shape_id): _retire_shape_watch(shape_id)
	for key in _bounds_cache.keys():
		if not live_bounds.has(key): _bounds_cache.erase(key)
	return result
