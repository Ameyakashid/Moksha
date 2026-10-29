extends "res://combat_pc/visuals/lithe_wireframe.gd"
## Read-only wardrobe over authoritative lithe pose; no second animation clock.
var source_visual: Node2D
const INK = Color("101c24")
const COAT = Color("42616b")
const TRIM = Color("a66f48")
const TROUSERS = Color("515b60")
const SKIN = Color("c99b7d")
const HAIR = Color("c9ceca")
func _ready() -> void:
	# Deliberately do not subscribe to motor events: the existing Visual owns poses.
	pass
func _process(_dt: float) -> void:
	if is_instance_valid(source_visual):set_pose(source_visual.get_pose())
func set_pose(value: Dictionary) -> void:
	_pose = value.duplicate(true)
	queue_redraw()
func _limb(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(a,b,INK,width+1.2,true)
	draw_line(a,b,color,width,true)
func _limbs(j: Dictionary, side: String, shade: float) -> void:
	_limb(j["hip_"+side],j["knee_"+side],TROUSERS.darkened(shade),3.5)
	_limb(j["knee_"+side],j["ankle_"+side],TROUSERS.darkened(shade+.1),3.0)
	# Boots end on the exact planted sole, never below the authored floor.
	draw_colored_polygon(PackedVector2Array([j["ankle_"+side]+Vector2(0,-1),j["heel_"+side],j["toe_"+side]]),INK)
	draw_line(j["heel_"+side],j["toe_"+side],TRIM.darkened(shade),1,true)
	_limb(j["shoulder_"+side],j["elbow_"+side],COAT.darkened(shade),3.7)
	_limb(j["elbow_"+side],j["palm_"+side],COAT.darkened(shade+.08),2.8)
	draw_circle(j["palm_"+side],1.05,SKIN.darkened(shade),true,-1,true)
func _head_point(offset: Vector2) -> Vector2:
	var point := (offset*Vector2(_pose.head_scale)).rotated(deg_to_rad(float(_pose.head_tilt)))
	point.x *= float(_pose.facing)
	return Vector2(_pose.bones.head)+point
func _draw() -> void:
	if _pose.is_empty():return
	var j: Dictionary = _pose.bones
	_limbs(j,"far",.32)
	var torso := PackedVector2Array()
	for key in ["shoulder_far","rib_far","waist_far","hip_far","hip_near","waist_near","rib_near","shoulder_near"]:torso.append(j[key])
	draw_colored_polygon(torso,COAT)
	torso.append(torso[0]);draw_polyline(torso,INK,1.2,true)
	# Split coat panels follow pelvis/knees through roll, ledge and climb poses.
	for side in ["far","near"]:
		var hip: Vector2 = j["hip_"+side]
		var hem: Vector2 = hip.lerp(j["knee_"+side],.55)
		var away := (hip-Vector2(j.pelvis)).normalized()*1.4
		draw_line(hip+away*.5,hem+away*.5,COAT.darkened(.14),2.4,true)
	_limb(j.chest,j.neck,COAT.lightened(.05),3)
	draw_line(j.chest,j.pelvis,TRIM.darkened(.1),.7,true)
	draw_line(j.waist_far,j.waist_near,INK,1.7,true)
	_limbs(j,"near",0)
	# Copper reinforced shoulder and knee remain attached to the approved joints.
	draw_circle(j.shoulder_near,2.0,TRIM,true,-1,true)
	draw_line(j.knee_near+Vector2(-1.2,0),j.knee_near+Vector2(1.2,0),TRIM,1.6,true)
	var outline := PackedVector2Array()
	for offset in [Vector2(-2.1,-2),Vector2(.7,-2.7),Vector2(2.2,-1.6),Vector2(2.6,-.25),Vector2(3.2,.55),Vector2(1.6,1.1),Vector2(.7,2.5),Vector2(-1.8,2),Vector2(-2.5,.5)]:outline.append(_head_point(offset))
	draw_line(j.neck,_head_point(Vector2(.7,2.5)),SKIN,2.0,true)
	draw_colored_polygon(outline,SKIN)
	outline.append(outline[0]);draw_polyline(outline,INK,.75,true)
	var hair := PackedVector2Array()
	for offset in [Vector2(-2.1,-2),Vector2(.7,-2.7),Vector2(2.2,-1.6),Vector2(.2,-1.2),Vector2(-1.8,.5),Vector2(-2.5,.5)]:hair.append(_head_point(offset))
	draw_colored_polygon(hair,HAIR)
	var beard := PackedVector2Array()
	for offset in [Vector2(1.6,1.1),Vector2(.7,2.5),Vector2(-1.8,2),Vector2(-1.5,.5),Vector2(0,1.2)]:beard.append(_head_point(offset))
	draw_colored_polygon(beard,HAIR.darkened(.18))
	draw_line(_head_point(Vector2(.5,-.5)),_head_point(Vector2(2,-.4)),INK,.75,true)
	# These are inherited unchanged: no copied or retimed combat feedback.
	_draw_weapon()
	_draw_shield()
	if show_contact_marks:
		for i in 2:
			if bool(_pose.planted_feet[i]):draw_circle(j["sole_"+("near" if i==0 else "far")],1.1,Color("6bf5b5"),true,-1,true)
