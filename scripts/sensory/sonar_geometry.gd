extends RefCounted
## Extracts contours from real enabled 2D collision shapes.
## Every trace stays attached to its CollisionShape2D / CollisionPolygon2D transform.
## Area2D triggers, the player, and nodes in sonar_ignore are intentionally excluded.

static func collect(root: Node, player: Node, spacing: float, budget: int) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	_collect_node(root, player, maxf(2.0, spacing), records, maxi(0, budget))
	return records

static func _collect_node(node: Node, player: Node, spacing: float, records: Array[Dictionary], budget: int) -> int:
	if node == player or node.is_in_group("sonar_ignore") or budget <= 0:
		return budget
	if node is CollisionShape2D and not node.disabled and node.shape != null and node.get_parent() is PhysicsBody2D:
		var polygons := _shape_contours(node.shape)
		for polygon in polygons:
			var record := _make_record(node, polygon.points, polygon.closed, spacing, budget, records.size())
			if not record.is_empty():
				records.append(record)
				budget -= record.a.size()
	elif node is CollisionPolygon2D and not node.disabled and node.get_parent() is PhysicsBody2D:
		var record := _make_record(node, node.polygon, true, spacing, budget, records.size())
		if not record.is_empty():
			records.append(record)
			budget -= record.a.size()
	for child in node.get_children():
		budget = _collect_node(child, player, spacing, records, budget)
	return budget

static func _shape_contours(shape: Shape2D) -> Array[Dictionary]:
	var points := PackedVector2Array()
	if shape is RectangleShape2D:
		var h: Vector2 = shape.size * 0.5
		points = PackedVector2Array([Vector2(-h.x, -h.y), Vector2(h.x, -h.y), h, Vector2(-h.x, h.y)])
	elif shape is CircleShape2D:
		for i in range(24):
			points.append(Vector2.from_angle(TAU * float(i) / 24.0) * shape.radius)
	elif shape is CapsuleShape2D:
		var straight: float = maxf(0.0, shape.height * 0.5 - shape.radius)
		for i in range(13):
			points.append(Vector2.from_angle(PI + PI * float(i) / 12.0) * shape.radius + Vector2(0, -straight))
		for i in range(13):
			points.append(Vector2.from_angle(PI * float(i) / 12.0) * shape.radius + Vector2(0, straight))
	elif shape is ConvexPolygonShape2D:
		points = shape.points
	elif shape is SegmentShape2D:
		return [{"points": PackedVector2Array([shape.a, shape.b]), "closed": false}]
	elif shape is ConcavePolygonShape2D:
		var result: Array[Dictionary] = []
		for i in range(0, shape.segments.size() - 1, 2):
			result.append({"points": PackedVector2Array([shape.segments[i], shape.segments[i + 1]]), "closed": false})
		return result
	if points.size() < 2:
		return []
	return [{"points": points, "closed": true}]

static func _make_record(anchor: Node2D, points: PackedVector2Array, closed: bool, spacing: float, budget: int, index: int) -> Dictionary:
	if points.size() < 2 or budget < 1:
		return {}
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	var arc := PackedFloat32Array()
	var total := 0.0
	var edge_count := points.size() if closed else points.size() - 1
	for i in range(edge_count):
		var p := points[i]
		var q := points[(i + 1) % points.size()]
		var world_length := anchor.to_global(p).distance_to(anchor.to_global(q))
		var count := maxi(1, ceili(world_length / spacing))
		for k in range(count):
			if a.size() >= budget:
				break
			a.append(p.lerp(q, float(k) / count))
			b.append(p.lerp(q, float(k + 1) / count))
			arc.append(total + world_length * (float(k) + 0.5) / count)
		total += world_length
	var body := anchor.get_parent()
	var dynamic: bool = not body is StaticBody2D
	return {
		"key": "%d:%d" % [anchor.get_instance_id(), hash(points)],
		"anchor": weakref(anchor),
		"body": weakref(body),
		"body_id": body.get_instance_id(),
		"a": a, "b": b, "arc": arc, "length": total, "closed": closed,
		"dynamic": dynamic, "enemy": body.is_in_group("enemies"),
		"fingerprint": hash([points, anchor.global_scale, spacing, a.size()]),
		"index": index,
	}

static func is_live(record: Dictionary) -> bool:
	var anchor: Node = record.anchor.get_ref()
	if not is_instance_valid(anchor) or not anchor.is_inside_tree():
		return false
	if anchor.get("disabled") == true:
		return false
	return true

static func segment_world(record: Dictionary, index: int) -> PackedVector2Array:
	var anchor: Node2D = record.anchor.get_ref()
	if not is_instance_valid(anchor) or index < 0 or index >= record.a.size():
		return PackedVector2Array()
	return PackedVector2Array([anchor.to_global(record.a[index]), anchor.to_global(record.b[index])])

static func make_track(record: Dictionary, origin: Vector2, radius: float, propagation_speed: float, contour_speed: float) -> Dictionary:
	if not is_live(record):
		return {}
	var anchor: Node2D = record.anchor.get_ref()
	var nearest := INF
	var seed_arc := 0.0
	for i in range(record.a.size()):
		var p: Vector2 = anchor.to_global(record.a[i])
		var q: Vector2 = anchor.to_global(record.b[i])
		var closest := Geometry2D.get_closest_point_to_segment(origin, p, q)
		var distance := origin.distance_to(closest)
		if distance < nearest:
			nearest = distance
			seed_arc = record.arc[i] + p.distance_to(closest) - p.distance_to(q) * 0.5
	if nearest > radius:
		return {}
	var arrivals := PackedFloat32Array()
	var attenuation := PackedFloat32Array()
	var last_arrival := 0.0
	var first_arrival := INF
	for i in range(record.a.size()):
		var mid: Vector2 = anchor.to_global((record.a[i] + record.b[i]) * 0.5)
		var around := absf(record.arc[i] - seed_arc)
		if record.closed:
			around = minf(around, record.length - around)
		var distance := origin.distance_to(mid)
		# Radial flight to the nearest contact, then two fronts travelling on the contour.
		# A finite contour budget prevents an entire distant collider lighting at once.
		if distance > radius or around > radius * 1.5:
			arrivals.append(-1.0)
			attenuation.append(0.0)
			continue
		var arrival := nearest / maxf(1.0, propagation_speed) + around / maxf(1.0, contour_speed)
		arrivals.append(arrival)
		attenuation.append(lerpf(1.0, 0.38, clampf(distance / radius, 0.0, 1.0)))
		last_arrival = maxf(last_arrival, arrival)
		first_arrival = minf(first_arrival, arrival)
	return {"geometry": record, "arrivals": arrivals, "attenuation": attenuation, "first_arrival": first_arrival, "last_arrival": last_arrival}
