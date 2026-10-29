extends Node
## Converts desired axes/held actions to the identical ordinary raw frame.
## The policy observes the world; neither component may drive the actor's body.
## This source is a direct child of its actor; its policy must belong to that actor.
const BUTTONS := ["jump", "roll", "attack", "shield"]
@export_node_path("Node") var policy_path := NodePath("../PatrolPolicy")
var _policy: Node
var _available := false
var _epoch := 0
var _rearm := {}
func _owned_policy(actor: Variant, policy: Variant) -> bool:
	return is_instance_valid(actor) and actor is Node and is_instance_valid(policy) and policy is Node and policy.is_inside_tree() and not policy.is_queued_for_deletion() and actor.is_ancestor_of(policy) and policy.has_method("sample_intent")
func _clear_policy(actor: Node, policy: Variant) -> void:
	if _owned_policy(actor, policy) and policy.has_method("reset_intent"): policy.reset_intent()
func _arm() -> void:
	_epoch += 1
	_rearm.clear()
	for button in BUTTONS: _rearm[button] = true
func sample_raw(actor: Node, dt: float) -> Dictionary:
	if actor != get_parent(): return {}
	var candidate := get_node_or_null(policy_path)
	var available := _owned_policy(actor, candidate) and candidate.can_process()
	if not is_instance_valid(_policy) or candidate != _policy or available != _available:
		_clear_policy(actor, _policy)
		_policy = candidate
		_available = available
		_clear_policy(actor, _policy)
		_arm()
	if not available: return {}
	var epoch := _epoch
	var intent: Variant = _policy.sample_intent(actor, dt)
	if epoch != _epoch or not _owned_policy(actor, _policy) or not _policy.can_process() or get_node_or_null(policy_path) != _policy:
		_available = false
		_arm()
		return {}
	var raw := to_raw(intent) if intent is Dictionary else {}
	for button in BUTTONS:
		var held: bool = raw.get(button) == true
		var blocked := _rearm.has(button)
		if not held: _rearm.erase(button)
		if blocked: raw[button] = false
	return raw
static func to_raw(intent: Dictionary) -> Dictionary:
	var axis: Variant = intent.get("move", Vector2.ZERO)
	if not axis is Vector2 or not Vector2(axis).is_finite(): return {}
	axis = Vector2(clampf(axis.x, -1, 1), clampf(axis.y, -1, 1))
	var raw := {"left": maxf(0, -axis.x), "right": maxf(0, axis.x), "up": maxf(0, -axis.y), "down": maxf(0, axis.y)}
	for button in BUTTONS: raw[button] = intent.get(button) == true
	return raw
func reset_intent() -> void:
	var actor := get_parent()
	_clear_policy(actor, _policy)
	var candidate := get_node_or_null(policy_path)
	if candidate != _policy: _clear_policy(actor, candidate)
	_policy = candidate
	_available = _owned_policy(actor, _policy) and _policy.can_process()
	_arm()
