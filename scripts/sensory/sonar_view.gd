extends CanvasLayer
## Reusable sound-origin visualisation. Attach below the HUD CanvasLayer.
## bind_level() scopes geometry and sources; set_blind() covers the world in black.
## Pure white travelling contour fragments remain after each real noise briefly.

const SonarTuning = preload("res://resources/sensory/sonar_tuning.gd")
const Geometry = preload("res://scripts/sensory/sonar_geometry.gd")
const CanvasScript = preload("res://scripts/sensory/sonar_canvas.gd")

@export var tuning: SonarTuning = preload("res://resources/sensory/sonar_default.tres")
@export var simulation_enabled: bool = true
@export var blind: bool = false
@export var preview_when_sighted: bool = false

var event_history: Array[Dictionary] = []
var pulses: Array[Dictionary] = []
var geometry: Array[Dictionary] = []
var elapsed: float = 0.0
var accepted_event_count: int = 0
var dropped_pulse_count: int = 0
var geometry_generation: int = 0
var last_draw_segments: int = 0
var last_draw_blackout: bool = false
var last_draw_proprioception: bool = false
var last_draw_origins: int = 0
var last_draw_threats: int = 0
var last_draw_contacts: int = 0
var last_draw_labels: int = 0
var _level: Node2D
var _player: Node2D
var _canvas: Node2D
var _refresh_clock: float = 0.0
var _bus: Node

func _ready() -> void:
	layer = 20
	_canvas = Node2D.new()
	_canvas.name = "WhiteContours"
	_canvas.set_script(CanvasScript)
	_canvas.sonar = self
	add_child(_canvas)
	_bus = get_node_or_null("/root/NoiseBus")
	if _bus != null and _bus.has_signal("noise_emitted"):
		_bus.noise_emitted.connect(_on_noise_emitted)

func bind_level(level: Node2D, player: Node2D) -> void:
	_level = level
	_player = player
	clear_pulses()
	event_history.clear()
	accepted_event_count = 0
	dropped_pulse_count = 0
	elapsed = 0.0
	_refresh_clock = 0.0
	refresh_geometry()
	_redraw()

func set_blind(value: bool) -> void:
	if blind != value:
		clear_pulses()
	blind = value
	_redraw()

func clear_pulses() -> void:
	pulses.clear()
	last_draw_segments = 0
	last_draw_origins = 0
	last_draw_threats = 0
	last_draw_contacts = 0
	last_draw_labels = 0
	_redraw()

func refresh_geometry() -> void:
	if not is_instance_valid(_level):
		geometry.clear()
		return
	var old: Dictionary = {}
	for record in geometry:
		old[record.key] = record
	var found := Geometry.collect(_level, _player, tuning.sample_spacing, tuning.max_geometry_segments)
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
				var track := Geometry.make_track(record, pulse.origin, pulse.radius, tuning.propagation_speed, tuning.contour_speed)
				if not track.is_empty():
					updated[record.key] = track
		pulse.tracks = updated
	_redraw()

func _process(dt: float) -> void:
	advance_simulation(dt)

func advance_simulation(dt: float) -> void:
	## Deterministic simulation hook for QA; pause stops both event intake and fade.
	if not simulation_enabled or get_tree().paused or not is_finite(dt) or dt <= 0.0:
		return
	elapsed += dt
	_refresh_clock += dt
	if _refresh_clock >= maxf(0.05, tuning.geometry_refresh_seconds):
		_refresh_clock = 0.0
		refresh_geometry()
	for i in range(pulses.size() - 1, -1, -1):
		pulses[i].age += dt
		if pulses[i].age > pulses[i].lifetime:
			pulses.remove_at(i)
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
		var track := Geometry.make_track(contour, origin, profile.range, tuning.propagation_speed, tuning.contour_speed)
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

func _redraw() -> void:
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()

func _alpha_for(pulse: Dictionary, track: Dictionary, index: int) -> float:
	var arrival: float = track.arrivals[index]
	if arrival < 0.0:
		return 0.0
	var since: float = pulse.age - arrival
	if since < 0.0:
		return 0.0
	var alpha := 0.0
	if since <= tuning.bright_head_seconds:
		alpha = lerpf(1.0, 0.86, since / maxf(0.001, tuning.bright_head_seconds))
	else:
		var decay := 1.0 - (since - tuning.bright_head_seconds) / maxf(0.001, pulse.trail)
		alpha = 0.86 * pow(maxf(0.0, decay), 1.7)
	return alpha * pulse.strength * track.attenuation[index]

func _segment_alphas(record: Dictionary) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	result.resize(record.a.size())
	var head := tuning.bright_head_seconds
	var inverse_head := 1.0 / maxf(0.001, head)
	for pulse in pulses:
		if not pulse.tracks.has(record.key):
			continue
		var track: Dictionary = pulse.tracks[record.key]
		var age: float = pulse.age
		var trail: float = pulse.trail
		if age < track.first_arrival or age > track.last_arrival + head + trail:
			continue
		# Typed local arrays and early saturation avoid Dictionary/function overhead
		# for every fragment of every overlapping noise in the render hot path.
		var arrivals: PackedFloat32Array = track.arrivals
		var attenuation: PackedFloat32Array = track.attenuation
		var strength: float = pulse.strength
		var inverse_trail := 1.0 / maxf(0.001, trail)
		for i in range(mini(result.size(), arrivals.size())):
			if result[i] >= 1.0 or arrivals[i] < 0.0:
				continue
			var since := age - arrivals[i]
			if since < 0.0 or since > head + trail:
				continue
			var alpha := lerpf(1.0, 0.86, since * inverse_head) if since <= head else 0.86 * pow(maxf(0.0, 1.0 - (since - head) * inverse_trail), 1.7)
			result[i] = minf(1.0, result[i] + alpha * strength * attenuation[i])
	return result

func render_on(canvas: Node2D) -> void:
	last_draw_segments = 0
	last_draw_blackout = blind
	last_draw_proprioception = false
	last_draw_origins = 0
	last_draw_threats = 0
	last_draw_contacts = 0
	last_draw_labels = 0
	var viewport_size := get_viewport().get_visible_rect().size
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	if blind:
		canvas.draw_rect(Rect2(Vector2.ZERO, viewport_size), Color.BLACK)
	if not blind and not preview_when_sighted:
		return
	var world_to_screen := get_viewport().get_canvas_transform()
	var view_rect := Rect2(Vector2(-20, -20), viewport_size + Vector2(40, 40))
	var opacity := 1.0 if blind else tuning.quiet_preview_opacity
	# Drawing only active sampled contour fragments avoids revealing sprites or
	# drawing a global wave ring. Multiple noises add independently up to white.
	for contour in geometry:
		if not Geometry.is_live(contour):
			continue
		var anchor: Node2D = contour.anchor.get_ref()
		var alphas := _segment_alphas(contour)
		for i in range(alphas.size()):
			var alpha := alphas[i] * opacity
			if alpha < 0.015:
				continue
			var a: Vector2 = world_to_screen * anchor.to_global(contour.a[i])
			var b: Vector2 = world_to_screen * anchor.to_global(contour.b[i])
			if not view_rect.has_point(a) and not view_rect.has_point(b):
				continue
			if last_draw_segments >= tuning.max_draw_segments:
				break
			if alpha > 0.7:
				canvas.draw_line(a, b, Color(1, 1, 1, alpha * 0.13), tuning.line_width + 2.0, true)
			canvas.draw_line(a, b, Color(1, 1, 1, alpha), tuning.line_width, true)
			last_draw_segments += 1
		if last_draw_segments >= tuning.max_draw_segments:
			break
	if blind and tuning.draw_proprioception and is_instance_valid(_player):
		_draw_player_mark(canvas, world_to_screen)
		last_draw_proprioception = true
	# Contact confirmation stays legible above the operative's own weapon line.
	for pulse in pulses:
		_draw_origin(canvas, pulse, world_to_screen, opacity)

func _draw_origin(canvas: Node2D, pulse: Dictionary, world_to_screen: Transform2D, opacity: float) -> void:
	_draw_threat(canvas, pulse, world_to_screen, opacity)
	var contact := contact_mark(pulse)
	if not contact.is_empty() and origin_label_visible(pulse): _draw_contact(canvas,contact,world_to_screen,opacity)
	var duration: float = _origin_duration(pulse)
	if pulse.age > duration: return
	var p: Vector2 = world_to_screen * pulse.origin
	var phase: float = pulse.age / maxf(0.001, duration)
	var a := (1.0 - phase) * opacity
	if contact.is_empty():
		last_draw_origins += 1
		var radius := 3.0 + phase * 10.0
		for i in range(4):
			var dir := Vector2.from_angle(PI * 0.25 + i * PI * 0.5)
			canvas.draw_line(p + dir * radius, p + dir * (radius + 3.5), Color(1, 1, 1, a), 1.0, true)
		canvas.draw_circle(p, 1.3, Color(1, 1, 1, a))
	if tuning.draw_origin_labels and origin_label_visible(pulse):
		var caption := _label(pulse.kind)
		var font_size := 8 if not contact.is_empty() else 7
		var caption_size := ThemeDB.fallback_font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
		canvas.draw_rect(Rect2(p+Vector2(7,-19),Vector2(caption_size.x+6,12)),Color(0,0,0,a*0.9))
		canvas.draw_string(ThemeDB.fallback_font, p + Vector2(10, -10), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, a))
		last_draw_labels += 1

func _origin_duration(pulse: Dictionary) -> float:
	if tuning.draw_contact_feedback:
		if pulse.kind in [&"enemy_death", &"prop_break"]: return tuning.defeat_feedback_seconds
		if pulse.kind in [&"enemy_damage", &"player_damage"]: return tuning.hit_feedback_seconds
	return tuning.origin_seconds

func _origin_priority(kind: StringName) -> int:
	match kind:
		&"enemy_death": return 100
		&"player_damage": return 95
		&"prop_break": return 90
		&"enemy_windup": return 85
		&"enemy_attack": return 80
		&"enemy_damage": return 88
		&"prop_impact": return 60
		&"weapon_tap": return 40
		&"enemy_step": return 20
		_: return 0

func origin_label_visible(pulse: Dictionary) -> bool:
	## Only label precedence changes: all independent contour waves remain intact.
	if _label(pulse.kind).is_empty() or pulse.age > _origin_duration(pulse): return false
	if pulse.kind in [&"enemy_windup",&"enemy_attack"] and _threat_interrupted(pulse): return false
	var priority := _origin_priority(pulse.kind)
	for other in pulses:
		if other.sequence == pulse.sequence or other.age > _origin_duration(other): continue
		if _label(other.kind).is_empty() or pulse.origin.distance_to(other.origin) > tuning.origin_label_separation: continue
		var other_priority := _origin_priority(other.kind)
		if other_priority > priority or (other_priority == priority and other.sequence > pulse.sequence): return false
	return true

func contact_mark(pulse: Dictionary) -> Dictionary:
	## Confirmation exists only for emitted damage/break/death sounds. A swing or
	## footstep alone cannot imply a hit. It never follows the source afterward.
	if not tuning.draw_contact_feedback: return {}
	if pulse.kind not in [&"enemy_damage",&"enemy_death",&"player_damage",&"prop_break"]: return {}
	var duration: float = _origin_duration(pulse)
	if pulse.age > duration: return {}
	var phase: float = clampf(pulse.age / maxf(duration,0.001),0,1)
	return {"origin":pulse.origin,"kind":pulse.kind,"phase":phase,
		"alpha":pow(1.0-phase,0.85),"label":_label(pulse.kind)}

func _draw_contact(canvas: Node2D, mark: Dictionary, world_to_screen: Transform2D, opacity: float) -> void:
	var p: Vector2 = world_to_screen * mark.origin
	var a: float = mark.alpha * opacity
	var phase: float = mark.phase
	var radius := 4.0 + phase * 10.0
	var white := Color(1,1,1,a)
	if mark.kind == &"enemy_damage":
		# Opposing short brackets: one crisp contact, not a radial scan ring.
		for direction in [-1.0,1.0]:
			var x: float = direction * radius
			canvas.draw_polyline(PackedVector2Array([p+Vector2(x+direction*3,-5),p+Vector2(x,0),p+Vector2(x+direction*3,5)]),white,1.5,true)
		if phase < 0.28: canvas.draw_circle(p,2.0*(1.0-phase),white)
	elif mark.kind == &"player_damage":
		for direction in [-1.0,1.0]:
			canvas.draw_line(p+Vector2(-7,direction*radius),p+Vector2(7,direction*radius),white,1.5,true)
	else:
		# Defeat/break fragments spread from the contact then fully disappear.
		for i in range(4):
			var direction := Vector2.from_angle(PI*0.25+i*PI*0.5)
			canvas.draw_line(p+direction*radius,p+direction*(radius+5),white,1.5,true)
		if mark.kind == &"enemy_death" and phase < 0.4:
			canvas.draw_line(p+Vector2(-4,-4),p+Vector2(4,4),white,1.4,true)
			canvas.draw_line(p+Vector2(-4,4),p+Vector2(4,-4),white,1.4,true)
	last_draw_contacts += 1

func threat_mark(pulse: Dictionary) -> Dictionary:
	## A remembered direction from an actual audible draw/strike, never a tracker.
	## Source position and facing stay fixed after emission, even if it moves.
	if not tuning.draw_threat_direction or int(pulse.get("direction", 0)) == 0:
		return {}
	var winding: bool = pulse.kind == &"enemy_windup"
	if not winding and pulse.kind != &"enemy_attack": return {}
	# Actual later damage interrupts this guard's attack. Retire its obsolete
	# warning using received sounds, without polling an invisible actor's state.
	if _threat_interrupted(pulse): return {}
	var duration: float = tuning.threat_warning_seconds if winding else tuning.threat_strike_seconds
	if pulse.age > duration: return {}
	return {"origin": pulse.origin, "direction": int(pulse.direction), "winding": winding,
		"alpha": clampf(1.0 - pulse.age / maxf(0.001, duration), 0.0, 1.0)}

func _threat_interrupted(pulse: Dictionary) -> bool:
	for other in pulses:
		if other.source_id == pulse.source_id and other.sequence > pulse.sequence and other.kind in [&"enemy_damage",&"enemy_death"]:
			return true
	return false

func _draw_threat(canvas: Node2D, pulse: Dictionary, world_to_screen: Transform2D, opacity: float) -> void:
	var mark := threat_mark(pulse)
	if mark.is_empty(): return
	var p: Vector2 = world_to_screen * mark.origin
	var forward := Vector2(float(mark.direction), 0)
	var length: float = tuning.threat_marker_length
	var white := Color(1, 1, 1, float(mark.alpha) * opacity)
	var tip := p + forward * length
	canvas.draw_line(p, tip, white, 1.3 if mark.winding else 2.0, true)
	canvas.draw_polyline(PackedVector2Array([tip - forward * 5 + Vector2(0,-4), tip, tip - forward * 5 + Vector2(0,4)]), white, 1.3, true)
	if mark.winding:
		canvas.draw_line(p + Vector2(0,-6), p + Vector2(0,6), white, 1.3, true)
	else:
		canvas.draw_line(p + Vector2(0,-3), tip + Vector2(0,-3), Color(1,1,1,white.a*0.45), 1.0, true)
	last_draw_threats += 1

func _draw_player_mark(canvas: Node2D, world_to_screen: Transform2D) -> void:
	# Proprioception describes only the operative's own body and held weapon.
	# Pose changes expose jump, roll and attack intent without revealing terrain.
	var p: Vector2 = world_to_screen * _player.global_position
	var white := Color(1, 1, 1, 0.7)
	var facing := float(_player.get("facing")) if _player.get("facing") != null else 1.0
	var velocity: Vector2 = _player.get("velocity") if _player.get("velocity") != null else Vector2.ZERO
	var rolling: bool = _player.get("dash_time") != null and _player.get("dash_time") > 0
	var grounded: bool = _player is CharacterBody2D and _player.is_on_floor()
	var stride := 0.0
	if grounded and absf(velocity.x) > 15 and _player.get("step_clock") != null:
		stride = sin(float(_player.get("step_clock")) * 1.5) * 5.0
	var head := Vector2(3 * facing, -18) if rolling else Vector2(0, -33)
	var shoulder := Vector2(0, -15) if rolling else Vector2(0, -27)
	var hip := Vector2(-5 * facing, -8) if rolling else Vector2(0, -13)
	canvas.draw_arc(p + head, 3.4, 0, TAU, 14, white, 1.0, true)
	canvas.draw_line(p + shoulder, p + hip, white, 1.0, true)
	var left_foot := Vector2(-4-stride,-1)
	var right_foot := Vector2(4+stride,-1)
	if not grounded or rolling:
		left_foot = Vector2(-7 * facing,-5)
		right_foot = Vector2(5 * facing,-9)
	canvas.draw_polyline(PackedVector2Array([p + left_foot, p + hip, p + right_foot]), white, 1.0, true)
	var hand := p + shoulder + Vector2(9 * facing,8)
	var graphics := _player.get_node_or_null("Graphics")
	if is_instance_valid(graphics) and graphics.has_method("weapon_tip"):
		var weapon := graphics.get_node_or_null("Weapon") as Node2D
		if is_instance_valid(weapon):
			hand = world_to_screen * weapon.global_position
			canvas.draw_line(hand, world_to_screen * graphics.weapon_tip(), Color(1,1,1,0.85), 1.15, true)
	canvas.draw_polyline(PackedVector2Array([p + shoulder + Vector2(-4 * facing,6),p + shoulder,hand]), white, 1.0, true)

func _label(kind: StringName) -> String:
	match String(kind):
		"weapon_tap", "tap": return "TAP"
		"enemy_step", "enemy_footstep": return "STEP"
		"prop_impact": return "CLANG"
		"prop_break": return "BREAK"
		"enemy_windup": return "DRAW"
		"enemy_attack": return "STRIKE"
		"enemy_damage": return "HIT"
		"enemy_death": return "DOWN"
		"player_damage": return "HURT"
		"sacrifice": return "PULSE"
		_: return ""

func debug_snapshot() -> Dictionary:
	var segment_count := 0
	var active_segment_count := 0
	var peak_alpha := 0.0
	for contour in geometry:
		if not Geometry.is_live(contour):
			continue
		segment_count += contour.a.size()
		for alpha in _segment_alphas(contour):
			peak_alpha = maxf(peak_alpha, alpha)
			if alpha >= 0.015:
				active_segment_count += 1
	var events: Array[Dictionary] = []
	for pulse in pulses:
		events.append({"origin": pulse.origin, "kind": pulse.kind, "age": pulse.age, "range": pulse.radius, "source_id": pulse.source_id})
	return {
		"blind": blind, "simulation_enabled": simulation_enabled, "elapsed": elapsed,
		"pulse_count": pulses.size(), "geometry_count": geometry.size(),
		"geometry_segments": segment_count, "geometry_generation": geometry_generation,
		"active_geometry_segments": active_segment_count, "peak_contour_alpha": peak_alpha,
		"preview_when_sighted": preview_when_sighted,
		"draw_segments": last_draw_segments, "accepted_event_count": accepted_event_count,
		"draw_blackout": last_draw_blackout, "draw_proprioception": last_draw_proprioception,
		"draw_origins": last_draw_origins,
		"draw_threats": last_draw_threats,
		"draw_contacts": last_draw_contacts,
		"draw_labels": last_draw_labels,
		"dropped_pulse_count": dropped_pulse_count, "pulses": events,
		"history": event_history.duplicate(true),
	}

func debug_project_world(world_position: Vector2) -> Vector2:
	## Uses the same active Camera2D transform as the screen-space renderer.
	return get_viewport().get_canvas_transform() * world_position

func debug_sample(world_position: Vector2, tolerance: float = 8.0) -> Dictionary:
	## Samples actual nearby collision contour fragments, never empty world space.
	var result := {"on_geometry": false, "alpha": 0.0, "distance": INF, "sources": [], "arrival_times": [], "segment": PackedVector2Array()}
	var best_record: Dictionary = {}
	var best_index := -1
	for contour in geometry:
		if not Geometry.is_live(contour):
			continue
		for i in range(contour.a.size()):
			var segment := Geometry.segment_world(contour, i)
			var nearest := Geometry2D.get_closest_point_to_segment(world_position, segment[0], segment[1])
			var d := world_position.distance_to(nearest)
			if d < result.distance:
				result.distance = d
				result.segment = segment
				best_record = contour
				best_index = i
	if best_index < 0 or result.distance > tolerance:
		return result
	result.on_geometry = true
	for pulse in pulses:
		if not pulse.tracks.has(best_record.key):
			continue
		var track: Dictionary = pulse.tracks[best_record.key]
		if best_index >= track.arrivals.size() or track.arrivals[best_index] < 0:
			continue
		result.arrival_times.append({"origin": pulse.origin, "kind": pulse.kind, "arrival": track.arrivals[best_index]})
		var alpha := _alpha_for(pulse, track, best_index)
		if alpha > 0.0:
			result.alpha = minf(1.0, result.alpha + alpha)
			result.sources.append({"origin": pulse.origin, "kind": pulse.kind, "alpha": alpha})
	return result
