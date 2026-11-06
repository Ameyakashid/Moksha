extends Node
## Detachable prop/ladder paint. No collider, transform, charge or audio writes.
const LadderSkin=preload("res://campaign/presentation/ladder_skin.gd")
const StationSkin=preload("res://campaign/presentation/station_skin.gd")
var room: Node2D
var records: Array[Dictionary]=[]
var sight_enabled:=true
var debug_wireframe:=false
func bind(value: Node2D) -> void:
	clear()
	room=value
	_scan(room)
	if not get_tree().node_added.is_connected(_node_added):get_tree().node_added.connect(_node_added)
	_sync()
func _node_added(node: Node) -> void:
	# Defer until original _ready has configured its actual Sprite/sensor.
	_consider.call_deferred(weakref(node))
func _scan(node: Node) -> void:
	_consider(weakref(node))
	for child in node.get_children():_scan(child)
func _consider(reference: WeakRef) -> void:
	var node: Node=reference.get_ref()
	if not is_instance_valid(node) or not is_instance_valid(room) or not room.is_ancestor_of(node):return
	for record in records:
		if record.node.get_ref()==node:return
	if node is RigidBody2D and node.has_method("invalidate_pending_contacts") and node.get_node_or_null("Sprite") is Sprite2D:
		var sprite: Sprite2D=node.get_node("Sprite")
		records.append({"kind":"cargo","node":weakref(node),"sprite":weakref(sprite),"self_modulate":node.self_modulate,"sprite_visible":sprite.visible})
	elif node.has_method("climb_geometry") and str(node.get("climb_type"))=="ladder":
		var skin:=Node2D.new();skin.set_script(LadderSkin);skin.name="CampaignLadderSkin";skin.ladder=node
		node.add_child(skin)
		records.append({"kind":"ladder","node":weakref(node),"skin":weakref(skin),"guide":node.draw_guide})
	elif node.has_node("StationContour") and node.get_node_or_null("View") is Node2D:
		var skin:=Node2D.new();skin.set_script(StationSkin);skin.name="CampaignStationSkin";skin.station=node
		node.add_child(skin)
		records.append({"kind":"station","node":weakref(node),"skin":weakref(skin),"view":weakref(node.get_node("View")),"visible":node.get_node("View").visible})
	else:return
	_sync()
func set_sight_enabled(value: bool) -> void:sight_enabled=value;_sync()
func set_debug_wireframe(value: bool) -> void:debug_wireframe=value;_sync()
func _sync() -> void:
	# Cargo replacement retires a body inside the same room. Forget its weak
	# paint record instead of scanning every historical replacement each tick.
	for index in range(records.size()-1,-1,-1):
		var record: Dictionary=records[index]
		var node: Node=record.node.get_ref()
		if not is_instance_valid(node):
			records.remove_at(index)
			continue
		if record.kind=="cargo":
			# self_modulate changes root debug paint only, NOT child Sprite modulation.
			node.self_modulate=record.self_modulate if debug_wireframe and sight_enabled else Color(1,1,1,0)
			var sprite: Sprite2D=record.sprite.get_ref()
			if is_instance_valid(sprite):sprite.visible=sight_enabled and (record.sprite_visible if debug_wireframe else true)
		elif record.kind=="station":
			var view: Node2D=record.view.get_ref()
			if is_instance_valid(view):view.visible=record.visible and debug_wireframe and sight_enabled
			var skin: Node2D=record.skin.get_ref()
			if is_instance_valid(skin):skin.visible=sight_enabled and not debug_wireframe
		else:
			node.draw_guide=record.guide and debug_wireframe and sight_enabled
			var skin: Node2D=record.skin.get_ref()
			if is_instance_valid(skin):skin.visible=sight_enabled and not debug_wireframe
func clear() -> void:
	if is_inside_tree() and get_tree().node_added.is_connected(_node_added):get_tree().node_added.disconnect(_node_added)
	for record in records:
		var node: Node=record.node.get_ref()
		if not is_instance_valid(node):continue
		if record.kind=="cargo":
			node.self_modulate=record.self_modulate
			var sprite: Sprite2D=record.sprite.get_ref()
			if is_instance_valid(sprite):sprite.visible=record.sprite_visible
		elif record.kind=="station":
			var view: Node2D=record.view.get_ref()
			if is_instance_valid(view):view.visible=record.visible
			var skin: Node2D=record.skin.get_ref()
			if is_instance_valid(skin):skin.queue_free()
		else:
			node.draw_guide=record.guide
			var skin: Node2D=record.skin.get_ref()
			if is_instance_valid(skin):skin.queue_free()
	records.clear();room=null
func _exit_tree() -> void:clear()
