extends Node
## Composition settings only. No movement, health, defense or AI outcome writes.
const Profile = preload("res://simulation/resources/actor_contact_profile.gd")
@export var profile: Profile
var _host: CharacterBody2D
var _managed_groups := PackedStringArray()
func _ready() -> void:
	_host = get_parent() as CharacterBody2D
	profile = profile.duplicate(true) if profile != null else Profile.new()
	if _host.is_node_ready(): _apply()
	else: _host.ready.connect(_apply, CONNECT_ONE_SHOT)
func configure(value: Profile) -> void:
	profile = value.duplicate(true) if value != null else Profile.new()
	if is_instance_valid(_host) and _host.is_node_ready(): _apply()
func _apply() -> void:
	if not is_instance_valid(_host) or _host.is_queued_for_deletion(): return
	for group in _managed_groups:
		if _host.is_in_group(group): _host.remove_from_group(group)
	for group in profile.remove_groups:
		if _host.is_in_group(group): _host.remove_from_group(group)
	_managed_groups = profile.groups.duplicate()
	for group in _managed_groups:
		if not group.is_empty(): _host.add_to_group(group)
	_host.collision_layer = profile.body_layer
	_host.collision_mask = profile.body_mask
	_host.terrain_mask = profile.terrain_mask
	_host.material_profile = profile.material_profile.duplicate(true) if profile.material_profile != null else null
	var contact := _host.get_node("ContactAdapter")
	contact._retire()
	contact.target_mask = profile.strike_target_mask
	contact.obstruction_mask = profile.obstruction_mask
	_host.get_node("ShieldContactAdapter").obstruction_mask = profile.obstruction_mask
	var receiver := _host.get_node_or_null("BodyShape/IncomingStrikeReceiver")
	if receiver != null:
		receiver.invalidate_generation()
		receiver.collision_layer = profile.hurtbox_layer
