extends SceneTree
const Pose=preload("res://combat_pc/visuals/wireframe_pose.gd")
const HEAD=[Vector2(-2.1,-2),Vector2(0.7,-2.7),Vector2(2.2,-1.6),Vector2(2.6,-0.25),Vector2(3.2,0.55),Vector2(1.6,1.1),Vector2(0.7,2.5),Vector2(-1.8,2),Vector2(-2.5,0.5)]
func _init() -> void:
	var rows:Array=[]
	for mode in ["roll_start","roll_travel","roll_recovery","attack_windup","attack_active","attack_recovery","hurt"]:
		var depth:=0.0;var sole_gap:=0.0;var worst:Dictionary={}
		for angle in [-PI/4,-atan(0.5),atan(0.5),PI/4]:
			for facing in [-1,1]:
				for low in [false,true]:
					for i in range(81):
						var p:=float(i)/80;var n:=Vector2.UP.rotated(angle);var plane:=Vector2(-signf(angle)*8,0)
						var t:Dictionary={"grounded":true,"body_height":20.0 if low else 34.0,"crouched":low,"facing":facing,"roll_direction":facing,"attack_facing":facing,"floor_normal":n,"floor_contact_point":plane}
						var pose:=Pose.evaluate(mode,p,t)
						var points:Dictionary=pose.bones.duplicate()
						for j in HEAD.size():
							var offset:Vector2=(HEAD[j]*Vector2(pose.head_scale)).rotated(deg_to_rad(float(pose.head_tilt)));offset.x*=facing
							points["head_outline"+str(j)]=Vector2(pose.bones.head)+offset
						for bone in points:
							var distance:float=(Vector2(points[bone])-plane).dot(n)
							if distance<depth:depth=distance;worst={"degrees":rad_to_deg(angle),"facing":facing,"low":low,"phase":p,"point":bone}
						for j in 2:
							if pose.planted_feet[j]:sole_gap=maxf(sole_gap,absf((Vector2(pose.bones["sole_near" if j==0 else "sole_far"])-plane).dot(n)))
		rows.append({"mode":mode,"maximum_body_plane_penetration_px":-depth,"maximum_authored_planted_sole_gap_px":sole_gap,"worst_body_point":worst})
	var report:Dictionary={"scope":"Quantified unchanged special-pose limitation on synthetic mirrored26.6/45degree floor planes; excludes weapons/effect strokes and is not native evidence","rows":rows}
	FileAccess.open("res://combat_pc/visuals/tests/slope_special_current_audit.json" if FileAccess.file_exists("res://combat_pc/visuals/tests/slope_special_pose_audit.json") else "res://combat_pc/visuals/tests/slope_special_pose_audit.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit()
