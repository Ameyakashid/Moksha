@tool
extends RefCounted
## Original MOKSHA tuning. No extracted animation, reference timing or root motion.
const Base = preload("res://combat_pc/visuals/wireframe_pose.gd")
const Combat = preload("res://combat_pc/visuals/combat_pose.gd")
const CombatKeys = preload("res://combat_pc/visuals/combat_keys.gd")
const MODES = ["idle", "run", "run_fast", "run_slow", "start", "brake", "turn", "jump", "air_jump", "jump_rise", "jump_apex", "fall", "land", "land_run", "crouch", "roll_start", "roll_travel", "roll_recovery"]
const UPPER_LEG = 8.0
const LOWER_LEG = 8.0
const UPPER_ARM = 6.0
const LOWER_ARM = 5.8

static func evaluate(mode: String, phase: float, t: Dictionary = {}) -> Dictionary:
	var result: Dictionary = Base.evaluate(mode, phase, t)
	if mode not in MODES:
		return result
	var key := sample(mode, clampf(phase, 0.0, 1.0), t)
	var solved := solve(key)
	result.bones = solved.bones
	result.head_tilt = float(key.head_tilt) + float(key.lean) * 0.2
	result.head_scale = Vector2(0.92, 0.96)
	result.planted_feet = key.feet_on.duplicate()
	result.key = "lithe/" + mode
	result.authorship = "MOKSHA original lithe pose geometry and timing"
	result.body_rotation = 0.0
	result.erase("slope_support")
	if mode.begins_with("roll_"):
		Combat.finish(result, key, mode, t)
	var facing := Base.facing_of(t)
	if mode.begins_with("roll_"):
		facing = -1.0 if float(t.get("roll_direction", facing)) < 0 else 1.0
	for name in result.bones:
		result.bones[name].x *= facing
	result.facing = int(facing)
	if not bool(t.get("grounded", false)):
		result.planted_feet = [false, false]
	Base.Slope.fit(result, t)
	return result

static func ready_key() -> Dictionary:
	return {"pelvis": Vector2(0, -16.1), "lean": 5.0, "torso": 8.7, "head_tilt": -2.0, "rib_width": 4.5, "feet": [Vector2(2.7, 0), Vector2(-2.8, 0)], "hands": [Vector2(5.4, -19.2), Vector2(-3.8, -20.0)], "feet_on": [true, true]}

static func sample(mode: String, p: float, t: Dictionary) -> Dictionary:
	var key := ready_key()
	var gait := gait_key(float(t.get("gait_phase", p)), t)
	match mode:
		"idle":
			key.pelvis.y += sin(float(t.get("visual_time", 0)) * 2.4) * 0.12
		"run", "run_fast", "run_slow":
			key = gait_key(p, t)
		"start":
			key.pelvis = Vector2(-0.6, -14.1)
			key.lean = 20.0
			key.hands = [Vector2(-2.0, -20), Vector2(7, -24)]
			key = mix_key(key, gait, smoothstep(0.0, 1.0, p))
		"brake", "turn":
			key.pelvis = Vector2(-0.8, -14.0)
			key.lean = -12.0 if mode == "brake" else -6.0
			key.feet = [Vector2(6.0, 0), Vector2(-5.0, 0)]
			key.hands = [Vector2(5, -21), Vector2(-5, -21)]
			key = mix_key(key, ready_key() if mode == "brake" else gait, smoothstep(0.15, 1.0, p))
		"jump", "jump_rise", "air_jump", "jump_apex", "fall":
			key = air_key(mode, p)
		"land", "land_run":
			key.pelvis = Vector2(0, -11.2)
			key.lean = 26.0
			key.feet = [Vector2(4.2, 0), Vector2(-4.0, 0)]
			key.hands = [Vector2(7, -15), Vector2(-3, -17)]
			key = mix_key(key, gait if mode == "land_run" else ready_key(), smoothstep(0.08, 1.0, p))
		"crouch":
			key.pelvis = Vector2(-1, -6.0)
			key.lean = 40.0
			key.torso = 6.4
			key.head_tilt = -18.0
			key.feet = [Vector2(4.5, 0), Vector2(-3.6, 0)]
			key.hands = [Vector2(7, -7), Vector2(-1, -10)]
		"roll_start", "roll_travel", "roll_recovery":
			var load: Dictionary = CombatKeys.POSES.roll_load.duplicate(true)
			var tuck: Dictionary = CombatKeys.POSES.roll_tuck.duplicate(true)
			load.rib_width = 4.6
			tuck.rib_width = 4.3
			if mode == "roll_start":
				key = mix_key(load, tuck, smoothstep(0.0, 0.85, p))
			elif mode == "roll_recovery":
				key = mix_key(tuck, load, smoothstep(0.0, 0.9, p))
			else:
				key = tuck
			key["body_rotation"] = TAU * p if mode == "roll_travel" else 0.0
			key["floor_guard"] = true
	return key

static func gait_key(phase: float, t: Dictionary) -> Dictionary:
	var key := ready_key()
	var speed := Base.speed_fraction(t)
	var stride := Base.stride_for(t)
	var stance := lerpf(0.44, 0.24, speed)
	var velocity: Vector2 = t.get("floor_relative_velocity", t.get("velocity", Vector2.ZERO))
	var direction := -1.0 if velocity.x * Base.facing_of(t) < 0 else 1.0
	var p := fposmod(phase, 1.0)
	# A linear stance travels exactly opposite actual root displacement. The
	# existing view pins that foot in world/support space after this evaluation.
	key.pelvis = Vector2(0, -lerpf(15.3, 13.9, speed) + cos(p * TAU * 2.0) * 0.38)
	key.lean = lerpf(8.0, 18.0, speed)
	key.head_tilt = -float(key.lean) * 0.55
	key.torso = 8.8
	key.feet = []
	key.feet_on = []
	key.hands = []
	var chest: Vector2 = key.pelvis + Vector2(sin(deg_to_rad(key.lean)), -cos(deg_to_rad(key.lean))) * key.torso
	for i in 2:
		var q := fposmod(p + i * 0.5, 1.0)
		var front := stride * stance * 0.5
		var foot: Vector2
		if q < stance:
			foot = Vector2((front - q * stride) * direction, 0)
			key.feet_on.append(true)
		else:
			var u := (q - stance) / (1.0 - stance)
			# Cubic endpoint tangents match the stance speed at lift-off/contact.
			# Unlike eased sine/pedalling, this has no velocity hitch at footfall.
			var tangent := -stride * (1.0 - stance)
			var x := (2*u*u*u-3*u*u+1)*-front + (u*u*u-2*u*u+u)*tangent + (-2*u*u*u+3*u*u)*front + (u*u*u-u*u)*tangent
			# Heel recovery peaks early; the trailing knee folds instead of
			# stretching both legs into a low, skating split during flight.
			var recovery := smoothstep(0.0, 0.28, u)*(1.0-smoothstep(0.62, 1.0, u))
			foot = Vector2(x * direction, -lerpf(3.2, 8.5, speed) * recovery)
			key.feet_on.append(false)
		key.feet.append(foot)
		var pump := -cos(q * TAU) * lerpf(3.4, 5.4, speed) * direction
		key.hands.append(chest + Vector2(pump, 4.1 - maxf(pump, 0.0) * 0.4))
	return key

static func air_key(mode: String, p: float) -> Dictionary:
	var rise := ready_key()
	rise.pelvis = Vector2(0, -15.0)
	rise.lean = 12.0
	rise.head_tilt = -8.0
	rise.feet = [Vector2(5, -7), Vector2(-4.5, -2.5)]
	rise.hands = [Vector2(7, -28), Vector2(-4, -20)]
	rise.feet_on = [false, false]
	var apex := rise.duplicate(true)
	apex.lean = 4.0
	apex.feet = [Vector2(4.5, -5), Vector2(-4, -4)]
	apex.hands = [Vector2(7, -23), Vector2(-5, -24)]
	if mode == "jump_apex":
		return apex
	if mode == "fall":
		apex.lean = 7.0
		apex.head_tilt = 9.0
		apex.feet = [Vector2(3.2, -1.0), Vector2(-3.5, -2)]
		return apex
	if mode == "jump":
		var push := rise.duplicate(true)
		push.pelvis.y = -15.8
		push.feet = [Vector2(3, -2), Vector2(-3, -1)]
		return mix_key(push, rise, smoothstep(0.0, 0.85, p))
	if mode == "air_jump":
		var fold := apex.duplicate(true)
		fold.lean = -14.0
		fold.feet = [Vector2(5, -9), Vector2(-4, -8)]
		fold.hands = [Vector2(3, -27), Vector2(-7, -25)]
		return mix_key(fold, rise, smoothstep(0.10, 0.95, p))
	return rise

static func mix_key(a: Dictionary, b: Dictionary, weight: float) -> Dictionary:
	return Combat.mix_keys(a, b, weight)

static func solve(key: Dictionary) -> Dictionary:
	var result := Base._solve(key)
	var j: Dictionary = result.bones
	var angle := deg_to_rad(float(key.lean))
	var across := Vector2(cos(angle), sin(angle))
	# Compact shoulder/pelvis silhouette, with explicit connected attachment
	# points. Targets are reachable before solving; bones never stretch.
	for i in 2:
		var side := "near" if i == 0 else "far"
		var sign_ := 1.0 if i == 0 else -1.0
		j["hip_"+side] = Vector2(j.pelvis) + Vector2(sign_*1.1, sign_*0.15)
		j["shoulder_"+side] = Vector2(j.chest) + across*sign_*1.8
		var hip: Vector2 = j["hip_"+side]
		var ankle: Vector2 = j["ankle_"+side]
		if hip.distance_to(ankle) > 15.85:
			if bool(key.feet_on[i]):
				var vertical := ankle.y-hip.y
				var horizontal := sqrt(maxf(0.0, 15.85*15.85-vertical*vertical))
				ankle.x = clampf(ankle.x, hip.x-horizontal, hip.x+horizontal)
			else:
				ankle = hip + (ankle-hip).normalized()*15.85
		var delta: Vector2 = ankle-Vector2(j["ankle_"+side])
		for name in ["ankle_", "sole_", "heel_", "toe_"]:
			j[name+side] += delta
		var bend := -float(key.get("leg_bend", [1.0, 1.0])[i])
		j["knee_"+side] = Base.solve_elbow(hip, ankle, UPPER_LEG, LOWER_LEG, bend)
		if bool(key.get("floor_guard", false)) and j["knee_"+side].y > 0:
			j["knee_"+side] = Base.solve_elbow(hip, ankle, UPPER_LEG, LOWER_LEG, -bend)
		var shoulder: Vector2 = j["shoulder_"+side]
		var offset: Vector2 = Vector2(j["palm_"+side])-shoulder
		var palm := shoulder + offset.normalized()*clampf(offset.length(), 0.3, 11.6)
		j["palm_"+side] = palm
		j["elbow_"+side] = Base.solve_elbow(shoulder, palm, UPPER_ARM, LOWER_ARM, -sign_)
	return result
