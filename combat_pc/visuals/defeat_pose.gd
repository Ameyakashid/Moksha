@tool
class_name MokshaDefeatPose
extends RefCounted
## Original passive wireframe collapse; no root motion or collision writes.
const Combat = preload("res://combat_pc/visuals/combat_pose.gd")
const Keys = preload("res://combat_pc/visuals/combat_keys.gd")
const Slope = preload("res://combat_pc/visuals/slope_pose.gd")
const KNEEL = {"pelvis":Vector2(-1,-7),"lean":28.0,"torso":7.7,"head_tilt":18.0,"rib_width":5.8,"feet":[Vector2(5,0),Vector2(-7,-1)],"hands":[Vector2(8,-5),Vector2(2,-4)],"feet_on":[false,false],"leg_bend":[1.0,-1.0]}
const REST = {"pelvis":Vector2(-5,-4),"lean":78.0,"torso":7.2,"head_tilt":14.0,"rib_width":5.5,"feet":[Vector2(-9,0),Vector2(-16,-1)],"hands":[Vector2(13,-1),Vector2(7,-2)],"feet_on":[false,false],"leg_bend":[1.0,-1.0]}

static func sample(mode: String, progress: float) -> Dictionary:
	if mode == "defeated_air":
		var air: Dictionary = Keys.POSES.hurt_recoil.duplicate(true)
		air.feet = [Vector2(4,-3),Vector2(-6,-5)]
		air.hands = [Vector2(5,-12),Vector2(-9,-16)]
		air["key_name"] = "defeated_air"
		return air
	var p := clampf(progress,0,1)
	var key: Dictionary
	if p < 0.4:
		key = Combat.mix_keys(Keys.POSES.hurt_recoil,KNEEL,smoothstep(0,0.4,p))
	else:
		key = Combat.mix_keys(KNEEL,REST,smoothstep(0.4,0.92,p))
	key["key_name"] = "defeated_settled" if p >= 0.92 else "defeated_collapse"
	key.feet_on = [false,false]
	return key

static func finish(pose: Dictionary, t: Dictionary) -> void:
	pose.ground_support = false
	pose.weapon = {"visible":false}
	if not bool(t.get("grounded",false)): return
	var settle := smoothstep(0.4,0.92,float(pose.phase))
	var forward := Vector2(float(pose.facing),0)
	pose.bones.neck = Vector2(pose.bones.neck).lerp(Vector2(pose.bones.chest)+forward*2.1,settle)
	pose.bones.head = Vector2(pose.bones.head).lerp(Vector2(pose.bones.chest)+forward*5.3,settle)
	pose.head_tilt = lerpf(float(pose.head_tilt),90.0,settle)
	var normal: Vector2 = t.get("floor_normal",Vector2.UP)
	if not normal.is_finite() or normal.y >= -0.1: normal = Vector2.UP
	normal = normal.normalized()
	var tangent := Vector2(-normal.y,normal.x)
	var root: Vector2 = t.get("position",Vector2.ZERO)
	var plane: Vector2 = t.get("floor_contact_point",root)-root
	for bone in pose.bones:
		var point: Vector2 = pose.bones[bone]
		pose.bones[bone] = normal*plane.dot(normal)+tangent*point.x-normal*point.y
	for side in ["near","far"]:
		Slope.set_leg(pose,side,pose.bones["sole_"+side],normal)
