@tool
extends "res://combat_pc/visuals/wireframe.gd"
## Optional view-only replacement. Keeps all motor, contact, phase and weapon
## authority in the existing PC. Original wireframe.gd remains the baseline.
const Lithe = preload("res://combat_pc/visuals/lithe_pose.gd")

@export_range(0.0, 0.12, 0.005) var locomotion_blend_seconds := 0.055
var _lithe_previous: Dictionary = {}
var _lithe_entry: Dictionary = {}
var _lithe_mode := ""
var _lithe_blend_age := 0.0
var _lithe_dt := 0.0

func present(dt: float, telemetry: Dictionary = {}) -> void:
	var tick := int(telemetry.get("tick_id", -1))
	if dt < 0.0 or (tick >= 0 and tick == _last_tick):
		return
	_lithe_dt = 0.0 if bool(telemetry.get("paused", false)) else dt
	super.present(dt, telemetry)
	if str(_pose.get("mode", "")) not in Lithe.MODES:
		_lithe_mode = str(_pose.get("mode", ""))
		_lithe_entry.clear()
	_lithe_previous = _pose.duplicate(true)

func _apply_support(root: Vector2, support_delta: Vector2) -> void:
	var mode := str(_pose.get("mode", "idle"))
	if mode in Lithe.MODES:
		var inputs := _telemetry.duplicate(true)
		inputs.visual_time = _clock
		inputs.gait_phase = _gait_phase
		_pose = Lithe.evaluate(mode, float(_pose.phase), inputs)
		_blend_locomotion_entry(mode)
	# Support locking runs AFTER pose construction, never after a smoothing
	# filter. A planted foot therefore stays exactly on its world-space anchor.
	super._apply_support(root, support_delta)

func _blend_locomotion_entry(mode: String) -> void:
	var eligible := mode in Lithe.MODES and not mode.begins_with("roll_") and mode != "crouch"
	var previous_eligible := _lithe_mode in Lithe.MODES and not _lithe_mode.begins_with("roll_") and _lithe_mode != "crouch"
	if mode != _lithe_mode:
		_lithe_entry = _lithe_previous.duplicate(true) if eligible and previous_eligible else {}
		_lithe_blend_age = 0.0
		_lithe_mode = mode
	_lithe_blend_age += _lithe_dt
	if _lithe_entry.is_empty() or locomotion_blend_seconds <= 0 or _lithe_blend_age >= locomotion_blend_seconds:
		return
	# Do not drag a mirrored old pose through the body on immediate reversal.
	if int(_lithe_entry.get("facing", 1)) != int(_pose.facing) or bool(_pose.get("slope_support", false)):
		return
	var weight := smoothstep(0.0, locomotion_blend_seconds, _lithe_blend_age)
	var bones: Dictionary = _pose.bones
	for name in ["pelvis", "chest", "neck", "head", "hip_near", "hip_far", "shoulder_near", "shoulder_far", "rib_near", "rib_far", "waist_near", "waist_far", "palm_near", "palm_far"]:
		bones[name] = Vector2(_lithe_entry.bones[name]).lerp(bones[name], weight)
	for i in 2:
		var side := "near" if i == 0 else "far"
		var shoulder: Vector2 = bones["shoulder_"+side]
		var delta: Vector2 = Vector2(bones["palm_"+side])-shoulder
		bones["palm_"+side] = shoulder+delta.normalized()*clampf(delta.length(), 0.3, 11.6)
		bones["elbow_"+side] = Pose.solve_elbow(shoulder, bones["palm_"+side], 6, 5.8, (-1.0 if i == 0 else 1.0)*float(_pose.facing))
		var hip: Vector2 = bones["hip_"+side]
		var ankle: Vector2 = bones["ankle_"+side]
		if hip.distance_to(ankle) > 15.85:
			var corrected := hip+(ankle-hip).normalized()*15.85
			var adjustment := corrected-ankle
			for prefix in ["ankle_", "sole_", "heel_", "toe_"]:
				bones[prefix+side] += adjustment
			_pose.planted_feet[i] = false
		bones["knee_"+side] = Pose.solve_elbow(hip, bones["ankle_"+side], 8, 8, -float(_pose.facing))

func evaluate_pose(mode: String, phase: float, telemetry: Dictionary = {}) -> Dictionary:
	return Lithe.evaluate(mode, phase, telemetry)

func reset_presentation() -> void:
	super.reset_presentation()
	_lithe_previous.clear()
	_lithe_entry.clear()
	_lithe_mode = ""
	_lithe_blend_age = 0.0

func _preview() -> void:
	super._preview()
	if Engine.is_editor_hint() and preview_pose in Lithe.MODES:
		_pose = Lithe.evaluate(preview_pose, preview_phase, {"velocity": Vector2(260*preview_facing, 0), "facing": preview_facing, "grounded": not preview_pose in ["jump", "air_jump", "jump_rise", "jump_apex", "fall"], "gait_phase": preview_phase})
		queue_redraw()

func _draw() -> void:
	if _pose.is_empty():
		return
	var j: Dictionary = _pose.bones
	var front := Color(0.92, 0.98, 0.97)
	var rear := Color(0.38, 0.54, 0.59)
	var core := Color(0.65, 0.79, 0.81)
	_chain(j, ["hip_far", "knee_far", "ankle_far"], rear, stroke_width*0.78)
	_chain(j, ["shoulder_far", "elbow_far", "palm_far"], rear, stroke_width*0.78)
	_foot(j, "far", rear, stroke_width)
	_palm(j, "far", rear)
	_chain(j, ["shoulder_far", "rib_far", "waist_far", "hip_far", "hip_near", "waist_near", "rib_near", "shoulder_near", "shoulder_far"], core, stroke_width*0.72)
	_chain(j, ["pelvis", "chest", "neck"], core, stroke_width*0.72)
	_chain(j, ["hip_far", "pelvis", "hip_near"], core, stroke_width*0.65)
	_chain(j, ["shoulder_far", "chest", "shoulder_near"], core, stroke_width*0.65)
	_chain(j, ["hip_near", "knee_near", "ankle_near"], front, stroke_width)
	_chain(j, ["shoulder_near", "elbow_near", "palm_near"], front, stroke_width)
	_foot(j, "near", front, stroke_width*1.2)
	_palm(j, "near", front)
	var outline := PackedVector2Array()
	var angle := deg_to_rad(float(_pose.head_tilt))
	var head_scale: Vector2 = _pose.head_scale
	var facing := float(_pose.facing)
	for offset in [Vector2(-2.1,-2.0), Vector2(0.7,-2.7), Vector2(2.2,-1.6), Vector2(2.6,-0.25), Vector2(3.2,0.55), Vector2(1.6,1.1), Vector2(0.7,2.5), Vector2(-1.8,2.0), Vector2(-2.5,0.5), Vector2(-2.1,-2.0)]:
		var point: Vector2 = (offset*head_scale).rotated(angle)
		point.x *= facing
		outline.append(Vector2(j.head)+point)
	# The neck terminates on the actual skull outline. It is not a floating
	# ring above a disconnected torso, including during a full roll rotation.
	draw_line(j.neck, outline[6], core, stroke_width*0.85, true)
	draw_polyline(outline, front, stroke_width*0.9, true)
	_draw_weapon()
	_draw_shield()
	if show_contact_marks:
		for i in 2:
			if bool(_pose.planted_feet[i]):
				draw_circle(j["sole_"+("near" if i == 0 else "far")], 1.1, Color(0.42,0.96,0.71), true, -1, true)
