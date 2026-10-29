extends Node
## Optional lifecycle adapter. Existing Visual continues owning every pose/event.
const Operative = preload("res://campaign/presentation/operative_skin.gd")
const Security = preload("res://campaign/presentation/security_skin.gd")
var original: Node2D
var operative: Node2D
var security: Array[Node2D] = []
var debug_wireframe := false
var sight_enabled := true
var _original_visibility := true
func bind(player: Node2D, enemies: Array) -> void:
	clear()
	original = player.get_node_or_null("Visual")
	if is_instance_valid(original) and original.has_method("get_pose"):
		_original_visibility = original.visible
		operative = Node2D.new();operative.set_script(Operative)
		operative.name = "CampaignOperativeSkin";operative.source_visual = original
		player.add_child(operative)
		operative.set_pose(original.get_pose())
	for enemy in enemies:
		if not is_instance_valid(enemy):continue
		var skin := Node2D.new();skin.set_script(Security);skin.actor=enemy
		skin.name="CampaignSecuritySkin";skin.show_behind_parent=true
		enemy.add_child(skin);security.append(skin)
	_sync()
func set_debug_wireframe(enabled: bool) -> void:
	debug_wireframe=enabled;_sync()
func set_sight_enabled(enabled: bool) -> void:
	sight_enabled=enabled;_sync()
func _sync() -> void:
	if is_instance_valid(original):original.visible=_original_visibility and debug_wireframe
	if is_instance_valid(operative):operative.visible=sight_enabled and not debug_wireframe
	for skin in security:
		if is_instance_valid(skin):skin.visible=sight_enabled and not debug_wireframe
func clear() -> void:
	if is_instance_valid(original):original.visible=_original_visibility
	if is_instance_valid(operative):operative.queue_free()
	for skin in security:
		if is_instance_valid(skin):skin.queue_free()
	security.clear();original=null;operative=null
func _exit_tree() -> void:clear()
