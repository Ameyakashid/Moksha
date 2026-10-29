extends RefCounted
## Test-only archive-backed oracle. Production never loads this helper.
const BASELINE := "res://simulation/evidence/relay_marker_baseline/mission_room.gd.txt"
const BASELINE_SHA := "dda519dc197051f08298392353071c69ac0a6b8b4ff03da763204169df507d89"
const Profile = preload("res://demo/views/room_backdrop_profile.gd")

static func legacy_room_script() -> GDScript:
	assert(FileAccess.get_sha256(BASELINE) == BASELINE_SHA)
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(BASELINE)
	assert(script.reload() == OK)
	return script

static func legacy_marker_script() -> GDScript:
	var source := FileAccess.get_file_as_string(BASELINE)
	assert(FileAccess.get_sha256(BASELINE) == BASELINE_SHA)
	var start := source.find('\tvar relay_points:',source.find("func _draw()"))
	var end := source.find('\tif data.has("cache"):',start)
	# The archived cache condition also checks its found state.
	if end < 0: end = source.find('\tif data.has("cache") and',start)
	assert(start >= 0 and end > start)
	var script := GDScript.new()
	script.source_code = "extends Node2D\nvar data: Dictionary\nvar relay_on := false\nvar activated_relays: Array[int] = []\nfunc _draw():\n" + source.substr(start,end-start)
	assert(script.reload() == OK)
	return script

static func style_marker_script() -> GDScript:
	var reference:=GDScript.new()
	var source:=legacy_marker_script().source_code.replace("var data: Dictionary","var data: Dictionary\nvar style: Resource")
	source=source.replace('var c := Color("9ce5bd")','var c: Color = style.active_ink').replace('Color("e7b779")','style.inactive_ink')
	source=source.replace('ThemeDB.fallback_font','style.font if style.font != null else ThemeDB.fallback_font').replace('"RELAY"','style.label').replace(',-1,8,',',-1,style.font_size,')
	reference.source_code=source;assert(reference.reload()==OK)
	return reference

static func topology(node: Node, result: Array = []) -> Array:
	if node is CollisionObject2D:
		var groups: Array = node.get_groups(); groups.sort()
		var body := {"body": node.get_class(), "transform": node.global_transform, "layer": node.collision_layer, "mask": node.collision_mask, "groups": groups}
		if node is StaticBody2D or node is RigidBody2D:
			var material: PhysicsMaterial = node.physics_material_override
			if material != null: body.material = [material.friction,material.bounce,material.rough,material.absorbent]
		result.append(body)
	if node is CollisionShape2D:
		var shape: Shape2D = node.shape
		var details := {"shape": shape.get_class() if shape != null else "null", "transform": node.global_transform, "disabled": node.disabled, "one_way": node.one_way_collision, "margin": node.one_way_collision_margin}
		if shape is RectangleShape2D: details.size = shape.size
		elif shape is CircleShape2D: details.radius = shape.radius
		elif shape is CapsuleShape2D: details.merge({"radius": shape.radius, "height": shape.height})
		elif shape is SegmentShape2D: details.merge({"a": shape.a, "b": shape.b})
		result.append(details)
	for child in node.get_children(): topology(child, result)
	return result

static func contours(node: Node2D) -> Array:
	var result: Array = []
	for record in preload("res://scripts/sensory/sonar_geometry.gd").collect(node, null, 12.0, 12000):
		result.append({"a": record.a, "b": record.b, "transform": record.anchor.get_ref().global_transform})
	return result

static func bytes_sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

static func clocks(node: Node, result: Dictionary = {}) -> Dictionary:
	for property in node.get_property_list():
		if property.name in ["time","animation_time","clock","hum_clock"]:
			result[str(node.get_instance_id())+":"+property.name] = node.get(property.name)
	for child in node.get_children(): clocks(child,result)
	return result
