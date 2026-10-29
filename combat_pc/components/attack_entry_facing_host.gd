@tool
class_name MokshaAttackEntryFacingHost
extends Node2D
## Optional host for ONE explicitly registered passive combat candidate.
## The motor owns admission and facing; this provider only returns a current offer.
@export_node_path("Node2D") var actor_path := NodePath("..")
@export_node_path("Node2D") var candidate_path := NodePath("")
@export var assist_enabled := false:
	set(value):
		assist_enabled = value
		_apply_enabled_if_owned()
@export_enum("unknown", "opponent", "prop") var candidate_classification := "unknown":
	set(value):
		candidate_classification = value if value in ["opponent", "prop"] else "unknown"
@export var candidate_eligible := false
@export var candidate_perceived := false
@export var candidate_visible := false
@export var candidate_local_anchor := Vector2(0, -15)
var query_count := 0
var offered_count := 0
var rejected_count := 0
var last_reason: StringName = &"not_queried"
var _actor_ref: WeakRef
var _candidate_ref: WeakRef

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	if not candidate_path.is_empty():
		var configured := get_node_or_null(candidate_path) as Node2D
		if is_instance_valid(configured): _candidate_ref = weakref(configured)
	if not actor_path.is_empty(): bind_actor(get_node_or_null(actor_path) as Node2D)

func _exit_tree() -> void:
	if not Engine.is_editor_hint(): unbind_actor()

func _live(value: Variant) -> bool:
	return is_instance_valid(value) and value is Node2D and value.is_inside_tree() and not value.is_queued_for_deletion()

func _bound_actor() -> Variant:
	return _actor_ref.get_ref() if _actor_ref != null else null

func _candidate() -> Variant:
	return _candidate_ref.get_ref() if _candidate_ref != null else null

func provider_callable() -> Callable:
	return Callable(self, "provide_attack_entry_offer")

func bind_actor(value: Node2D) -> bool:
	if Engine.is_editor_hint(): return false
	unbind_actor()
	if not _live(value) or not value.has_method("set_attack_entry_provider") or not value.has_method("clear_attack_entry_provider") or not value.has_method("attack_entry_provider_matches"):
		last_reason = &"actor_unavailable"
		return false
	_actor_ref = weakref(value)
	value.set_attack_entry_provider(provider_callable())
	_apply_enabled_if_owned()
	var bound: bool = value.attack_entry_provider_matches(provider_callable())
	if bound: last_reason = &"ready"
	return bound

func unbind_actor() -> void:
	var actor: Variant = _bound_actor()
	_actor_ref = null
	if _live(actor) and actor.has_method("clear_attack_entry_provider"):
		# An old host cannot clear a replacement's provider. Do not alter the
		# actor's enable setting here: removing this provider is sufficient.
		actor.clear_attack_entry_provider(provider_callable())

func _apply_enabled_if_owned() -> void:
	if Engine.is_editor_hint(): return
	var actor: Variant = _bound_actor()
	if _live(actor) and actor.has_method("attack_entry_provider_matches") and actor.attack_entry_provider_matches(provider_callable()):
		actor.enable_attack_entry_assist = assist_enabled

func set_assist_enabled(enabled: bool) -> void:
	assist_enabled = enabled

func register_candidate(target: Node2D, attestation: Dictionary = {}) -> bool:
	# Missing information revokes old attestations instead of carrying them
	# over to a newly registered identity. Damage reception is independent.
	_candidate_ref = weakref(target) if _live(target) else null
	var classification: Variant = attestation.get("classification", "unknown")
	candidate_classification = String(classification) if classification is String or classification is StringName else "unknown"
	candidate_eligible = attestation.get("eligible") is bool and bool(attestation.get("eligible"))
	candidate_perceived = attestation.get("perceived") is bool and bool(attestation.get("perceived"))
	candidate_visible = attestation.get("visible") is bool and bool(attestation.get("visible"))
	candidate_local_anchor = attestation.get("local_anchor", Vector2(0, -15)) if attestation.get("local_anchor", Vector2(0, -15)) is Vector2 else Vector2.INF
	return _candidate_ref != null

func clear_candidate() -> void:
	_candidate_ref = null
	candidate_classification = "unknown"
	candidate_eligible = false
	candidate_perceived = false
	candidate_visible = false

func set_candidate_awareness(perceived: bool, visible_to_actor: bool) -> void:
	candidate_perceived = perceived
	candidate_visible = visible_to_actor

func set_candidate_eligible(eligible: bool) -> void:
	candidate_eligible = eligible

func set_candidate_classification(classification: StringName) -> void:
	candidate_classification = String(classification)

func _reject(reason: StringName) -> Dictionary:
	rejected_count += 1
	last_reason = reason
	return {}

func _valid_rect(value: Variant) -> bool:
	return value is Rect2 and value.position.is_finite() and value.size.is_finite() and value.size.x > 0 and value.size.y > 0

func _contains_anchor(rect: Rect2, point: Vector2) -> bool:
	# Match the motor's inclusive left/right preview boundary convention.
	return point.x >= rect.position.x and point.x <= rect.end.x and point.y >= rect.position.y and point.y <= rect.end.y

func provide_attack_entry_offer(actor: Node2D, request: Dictionary) -> Dictionary:
	if Engine.is_editor_hint(): return {}
	query_count += 1
	if not assist_enabled: return _reject(&"disabled")
	if not _live(actor) or actor != _bound_actor() or not actor.attack_entry_provider_matches(provider_callable()): return _reject(&"provider_not_current")
	for key in ["token", "sample_tick", "engine_tick", "actor_id", "attack_serial"]:
		if not request.get(key) is int: return _reject(&"invalid_request")
	if int(request.token) <= 0 or int(request.sample_tick) < 0 or int(request.attack_serial) <= 0 or int(request.actor_id) != actor.get_instance_id() or int(request.engine_tick) != Engine.get_physics_frames(): return _reject(&"stale_request")
	if not _valid_rect(request.get("preview_left")) or not _valid_rect(request.get("preview_right")): return _reject(&"invalid_preview")
	for key in ["origin_left", "origin_right"]:
		if not request.get(key) is Vector2 or not Vector2(request[key]).is_finite(): return _reject(&"invalid_origin")
	if not request.get("terrain_mask") is int or int(request.terrain_mask) <= 0: return _reject(&"invalid_terrain_mask")
	# No target position is even read until the explicit semantic/awareness
	# attestations pass. Diagnostics never store target coordinates or IDs.
	if candidate_classification != "opponent": return _reject(&"not_opposing_combat_target")
	if not candidate_eligible: return _reject(&"ineligible")
	if not candidate_perceived: return _reject(&"unperceived")
	if not candidate_visible: return _reject(&"visibility_not_attested")
	var target: Variant = _candidate()
	if not _live(target) or target == actor: return _reject(&"candidate_unavailable")
	if target.is_in_group("props"): return _reject(&"prop_excluded")
	if not target.is_visible_in_tree(): return _reject(&"hidden")
	if not candidate_local_anchor.is_finite(): return _reject(&"invalid_anchor")
	var anchor: Vector2 = target.to_global(candidate_local_anchor)
	if not anchor.is_finite(): return _reject(&"invalid_anchor")
	var left: Rect2 = request.preview_left
	var right: Rect2 = request.preview_right
	if not _contains_anchor(left, anchor) and not _contains_anchor(right, anchor): return _reject(&"outside_preview")
	var origin: Vector2 = request.origin_left if anchor.x < actor.global_position.x else request.origin_right
	var excluded: Array[RID] = []
	if actor is CollisionObject2D: excluded.append(actor.get_rid())
	var ray := PhysicsRayQueryParameters2D.create(origin, anchor, int(request.terrain_mask), excluded)
	ray.hit_from_inside = true
	if not actor.get_world_2d().direct_space_state.intersect_ray(ray).is_empty(): return _reject(&"occluded")
	# Every offer is a fresh value. The motor independently checks the current
	# identity/transform/preview and its own authority after this return.
	offered_count += 1
	last_reason = &"offered"
	return {"token": int(request.token), "sample_tick": int(request.sample_tick), "actor_id": int(request.actor_id), "attack_serial": int(request.attack_serial),
		"candidate": target, "candidate_id": target.get_instance_id(), "local_anchor": candidate_local_anchor, "anchor_world": anchor,
		"classification": &"opponent", "eligible": true, "perceived": true, "visible": true}

func diagnostics() -> Dictionary:
	return {"enabled": assist_enabled, "query_count": query_count, "offered_count": offered_count, "rejected_count": rejected_count,
		"reason": last_reason, "classification": candidate_classification, "eligible": candidate_eligible,
		"perceived": candidate_perceived, "visible": candidate_visible}

func reset_diagnostics() -> void:
	query_count = 0
	offered_count = 0
	rejected_count = 0
	last_reason = &"not_queried"

func _draw() -> void:
	if not Engine.is_editor_hint(): return
	var color := Color("88b5aa")
	draw_line(Vector2(-4, 0), Vector2(4, 0), color)
	draw_line(Vector2(0, -4), Vector2(0, 4), color)
	draw_string(ThemeDB.fallback_font, Vector2(7, 3), "ENTRY AIM HOST / ONE CANDIDATE", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, color)
