extends "res://combat_pc/player.gd"
## Observation-only wrapper around the production solver, for baseline evidence.
var transport_samples: Array[Dictionary] = []
var _observed_support: WeakRef
var _observed_transform := Transform2D.IDENTITY
var _observed_local := Vector2.ZERO
func _observe_floor_contact(hit: KinematicCollision2D) -> void:
	super._observe_floor_contact(hit)
	if is_instance_valid(_support):
		_observed_support = weakref(_support)
		_observed_transform = _physics_transform(_support)
		_observed_local = _floor_contact_local
func _transport_support(dt: float) -> void:
	if not grounded or not is_instance_valid(_support) or _observed_support == null or _observed_support.get_ref() != _support:
		super._transport_support(dt)
		return
	var before := global_position
	var body := _support
	var committed := _physics_transform(body)
	var expected := committed * _observed_local - _observed_transform * _observed_local
	var translation := committed.origin - _support_position
	super._transport_support(dt)
	transport_samples.append({"frame":Engine.get_physics_frames(),"support_id":body.get_instance_id(),
		"expected_anchor_x":expected.x,"expected_anchor_y":expected.y,"requested_translation_x":translation.x,
		"actual_x":global_position.x-before.x,"actual_y":global_position.y-before.y,
		"recorded_x":_support_displacement.x,"recorded_y":_support_displacement.y,
		"rotation_delta":committed.get_rotation()-_observed_transform.get_rotation(),
		"continuous_support":_support == body and grounded})
