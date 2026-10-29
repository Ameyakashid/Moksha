extends "res://scripts/sensory/sonar_view.gd"
## Demo rendering adapter. The preserved propagation/contour model is unchanged.
## Cull whole off-screen contours before alpha evaluation; submit visible lines
## in two batches instead of thousands of individual draw commands.
var _bounds_cache: Dictionary = {}
var _shape_cache: Dictionary = {}
var _watched_shapes: Dictionary = {}

func bind_level(level: Node2D, player: Node2D) -> void:
	_bounds_cache.clear()
	_shape_cache.clear()
	super.bind_level(level,player)

func _local_bounds(record: Dictionary) -> Rect2:
	var key: String = str(record.key)+":"+str(record.fingerprint)
	if _bounds_cache.has(key): return _bounds_cache[key]
	var bounds := Rect2(Vector2(record.a[0]),Vector2.ZERO)
	for p in record.a: bounds=bounds.expand(p)
	for p in record.b: bounds=bounds.expand(p)
	bounds=bounds.grow(3)
	_bounds_cache[key]=bounds
	return bounds

func render_on(canvas: Node2D) -> void:
	last_draw_segments=0
	last_draw_blackout=blind
	last_draw_proprioception=false
	last_draw_origins=0
	last_draw_threats=0
	last_draw_contacts=0
	last_draw_labels=0
	var viewport_size := get_viewport().get_visible_rect().size
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	if blind: canvas.draw_rect(Rect2(Vector2.ZERO,viewport_size),Color.BLACK)
	if not blind and not preview_when_sighted: return
	var world_to_screen := get_viewport().get_canvas_transform()
	var view := Rect2(Vector2(-20,-20),viewport_size+Vector2(40,40))
	var opacity := 1.0 if blind else tuning.quiet_preview_opacity
	var lines := PackedVector2Array()
	var colors := PackedColorArray()
	var glow_lines := PackedVector2Array()
	var glow_colors := PackedColorArray()
	for contour in geometry:
		if not Geometry.is_live(contour): continue
		var anchor: Node2D=contour.anchor.get_ref()
		var transform := world_to_screen*anchor.global_transform
		if not view.intersects(transform*_local_bounds(contour)): continue
		var alphas := _segment_alphas(contour)
		for i in alphas.size():
			var alpha: float=alphas[i]*opacity
			if alpha<0.015: continue
			var a: Vector2=transform*contour.a[i]
			var b: Vector2=transform*contour.b[i]
			if not view.has_point(a) and not view.has_point(b): continue
			if last_draw_segments>=tuning.max_draw_segments: break
			lines.append(a)
			lines.append(b)
			var ink := Color(1,1,1,alpha)
			colors.append(ink)
			if alpha>0.7:
				glow_lines.append(a)
				glow_lines.append(b)
				glow_colors.append(Color(1,1,1,alpha*0.13))
			last_draw_segments+=1
		if last_draw_segments>=tuning.max_draw_segments: break
	if not glow_lines.is_empty(): canvas.draw_multiline_colors(glow_lines,glow_colors,tuning.line_width+2.0,true)
	if not lines.is_empty(): canvas.draw_multiline_colors(lines,colors,tuning.line_width,true)
	# Body proprioception is the actual lithe pose on a separate view-only layer.
	for pulse in pulses: _draw_origin(canvas,pulse,world_to_screen,opacity)

# Collision contours are local-space geometry. Translation/rotation never require
# resampling them; live transforms are applied by tracks/rendering. Shape changes
# invalidate the cache, while a tree walk still notices added/removed/disabled nodes.
func _invalidate_shape_cache() -> void:
	_shape_cache.clear()
	_bounds_cache.clear()

func _collect_cached_geometry() -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	_collect_cached_node(_level,result,maxi(0,tuning.max_geometry_segments))
	return result

func _collect_cached_node(node:Node,result:Array[Dictionary],budget:int)->int:
	if node==_player or node.is_in_group("sonar_ignore") or budget<=0: return budget
	if node is CollisionShape2D and not node.disabled and node.shape!=null and node.get_parent() is PhysicsBody2D:
		var shape_id:int=node.shape.get_instance_id()
		if not _watched_shapes.has(shape_id):
			node.shape.changed.connect(_invalidate_shape_cache)
			_watched_shapes[shape_id]=true
		var signature=hash([shape_id,node.global_scale,tuning.sample_spacing,budget])
		var key:int=node.get_instance_id()
		var cached:Dictionary=_shape_cache.get(key,{})
		if cached.get("signature",0)!=signature:
			var records:Array[Dictionary]=[]
			var remaining:=budget
			for polygon in Geometry._shape_contours(node.shape):
				var record:=Geometry._make_record(node,polygon.points,polygon.closed,maxf(2,tuning.sample_spacing),remaining,result.size()+records.size())
				if not record.is_empty():
					records.append(record)
					remaining-=record.a.size()
			cached={"signature":signature,"records":records}
			_shape_cache[key]=cached
		for record in cached.records:
			result.append(record)
			budget-=record.a.size()
	elif node is CollisionPolygon2D and not node.disabled and node.get_parent() is PhysicsBody2D:
		var record:=Geometry._make_record(node,node.polygon,true,maxf(2,tuning.sample_spacing),budget,result.size())
		if not record.is_empty():
			result.append(record)
			budget-=record.a.size()
	for child in node.get_children(): budget=_collect_cached_node(child,result,budget)
	return budget

func _bounded_track(record:Dictionary,origin:Vector2,radius:float)->Dictionary:
	if not Geometry.is_live(record): return {}
	var anchor:Node2D=record.anchor.get_ref()
	var box:Rect2=anchor.global_transform*_local_bounds(record)
	var nearest:=Vector2(clampf(origin.x,box.position.x,box.end.x),clampf(origin.y,box.position.y,box.end.y))
	if nearest.distance_squared_to(origin)>radius*radius: return {}
	return Geometry.make_track(record,origin,radius,tuning.propagation_speed,tuning.contour_speed)

func refresh_geometry() -> void:
	if not is_instance_valid(_level):
		geometry.clear()
		return
	var old: Dictionary = {}
	for record in geometry:
		old[record.key] = record
	var found := _collect_cached_geometry()
	geometry.clear()
	for record in found:
		if old.has(record.key) and old[record.key].fingerprint == record.fingerprint:
			geometry.append(old[record.key])
		else:
			geometry.append(record)
	geometry_generation += 1
	# Preserve emission-time arrival timing on unchanged moving colliders. New and
	# changed shapes get real updated contours; deleted geometry cannot leave ghosts.
	for pulse in pulses:
		var updated: Dictionary = {}
		for record in geometry:
			if pulse.tracks.has(record.key) and pulse.tracks[record.key].geometry.fingerprint == record.fingerprint:
				updated[record.key] = pulse.tracks[record.key]
			else:
				var track := _bounded_track(record, pulse.origin, pulse.radius)
				if not track.is_empty():
					updated[record.key] = track
		pulse.tracks = updated
	_redraw()

func _on_noise_emitted(origin: Vector2, kind: StringName, loudness: float, source: Node = null) -> void:
	if not simulation_enabled or get_tree().paused or not is_instance_valid(_level):
		return
	if not origin.is_finite() or not is_finite(loudness) or loudness <= 0.0:
		return
	# Provenance is mandatory: unscoped events and freed/old-level sources must
	# never disclose a different level after a restart or transition.
	if not is_instance_valid(source) or source.is_queued_for_deletion():
		return
	if source != _level and not _level.is_ancestor_of(source):
		return
	var profile := tuning.profile(kind, loudness)
	accepted_event_count += 1
	var record := {
		"sequence": accepted_event_count, "origin": origin, "kind": kind,
		"loudness": loudness, "time": elapsed,
		"source_id": source.get_instance_id() if is_instance_valid(source) else 0,
		"direction": int(signf(float(source.get("facing")))) if source.get("facing") != null else 0,
	}
	event_history.append(record)
	while event_history.size() > maxi(0, tuning.history_limit):
		event_history.pop_front()
	var pulse := record.duplicate()
	pulse["radius"] = profile.range
	pulse["strength"] = profile.strength
	pulse["trail"] = profile.trail
	pulse["age"] = 0.0
	pulse["tracks"] = {}
	var last_arrival := 0.0
	for contour in geometry:
		var track := _bounded_track(contour, origin, profile.range)
		if not track.is_empty():
			pulse.tracks[contour.key] = track
			last_arrival = maxf(last_arrival, track.last_arrival)
	# Conservative finite expiry also permits a runtime prop/shape entering geometry.
	pulse["lifetime"] = maxf(last_arrival, profile.range / tuning.propagation_speed + profile.range * 1.5 / tuning.contour_speed) + tuning.bright_head_seconds + profile.trail
	pulses.append(pulse)
	while pulses.size() > maxi(1, tuning.max_active_pulses):
		pulses.pop_front()
		dropped_pulse_count += 1
	_redraw()

