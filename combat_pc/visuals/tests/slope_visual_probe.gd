extends SceneTree
const Visual=preload("res://combat_pc/visuals/wireframe.gd")
func _init() -> void: _run.call_deferred()
func _run() -> void:
	var rows:Array=[]
	for angle in [-PI/4,-atan(0.5),atan(0.5),PI/4]:
		for facing in [-1,1]:
			for mode in ["idle","run","brake"]:
				var view=Visual.new()
				var normal:=Vector2.UP.rotated(angle)
				var plane:=Vector2(-signf(angle)*8,0)
				view.present(0,{"position":Vector2.ZERO,"grounded":true,"pose":mode,"facing":facing,"velocity":Vector2(120*facing,120*facing*tan(angle)) if mode!="idle" else Vector2.ZERO,"floor_normal":normal,"floor_contact_point":plane,"support_id":1,"body_width":16.0,"body_height":34.0})
				var pose:Dictionary=view.get_pose();var gaps:Array=[];var angles:Array=[];var reachable:Array=[]
				for side in ["near","far"]:
					gaps.append((Vector2(pose.bones["sole_"+side])-plane).dot(normal))
					angles.append(absf(Vector2(pose.bones["toe_"+side]-pose.bones["heel_"+side]).normalized().dot(normal)))
					var hip:Vector2=pose.bones["hip_"+side]
					reachable.append(absf((hip-plane).dot(normal)-1.4)<=15.98)
				rows.append({"degrees":rad_to_deg(angle),"facing":facing,"mode":mode,"sole_signed_plane_gap":gaps,"sole_normal_dot":angles,"some_contact_reachable_from_current_hip":reachable,"planted":pose.planted_feet})
				view.free()
	var report:Dictionary={"scope":"Pre-correction ordinary slope probe using the authoritative rectangle-uphill-corner contact geometry; synthetic, not an actual gameplay recording","wireframe_sha256":FileAccess.get_sha256("res://combat_pc/visuals/wireframe.gd"),"rows":rows}
	FileAccess.open("res://combat_pc/visuals/tests/slope_visual_current_probe.json" if FileAccess.file_exists("res://combat_pc/visuals/tests/slope_visual_defect_baseline.json") else "res://combat_pc/visuals/tests/slope_visual_defect_baseline.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report));quit()
