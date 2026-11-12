extends SceneTree
## Protect fe9936a content except the explicitly authored return connector/signage.
func _initialize()->void:
	var levels:Array=preload("res://campaign/layouts/level_02.gd").sectors()
	var failures:Array=[]
	for d in levels:
		if d.id!="l2_thermal_foundry":continue
		if d.platforms.size()!=13 or d.platforms[-1]!=Rect2(3240,120,160,18):failures.append("Connector geometry")
		if d.objective_doors.size()!=3 or d.objective_doors[-1]!={"at":Vector2(3340,90),"size":Vector2(24,180),"requires":["feed"]}:failures.append("Feed shutter geometry/dependency")
		if d.platforms.slice(0,-1)!=[Rect2(420,240,250,60),Rect2(810,180,340,18),Rect2(1290,120,400,18),Rect2(1830,60,360,18),Rect2(2330,0,410,18),Rect2(2880,120,360,18),Rect2(3400,180,380,18),Rect2(3940,240,260,60),Rect2(1150,-70,350,18),Rect2(3050,-90,350,18),Rect2(1970,245,160,55),Rect2(3520,245,170,55)]:failures.append("Original platforms changed")
		if d.objective_doors.slice(0,-1)!=[{"at":Vector2(3880,150),"size":Vector2(28,300),"requires":["coolant"]},{"at":Vector2(4490,150),"size":Vector2(28,300),"requires":["coolant"]}]:failures.append("Original doors changed")
		if not d.platforms.has(Rect2(3050,-90,350,18)):failures.append("Upper service route removed")
		if d.ladders!=[[530,300,60],[980,300,120],[1450,300,180],[1990,300,240],[2520,300,300],[3050,300,180],[3550,300,120],[1330,120,190],[3210,120,210]]:failures.append("Fixed recovery ladders changed")
		for key in ["platforms","objective_doors","signs"]:d.erase(key)
	if JSON.stringify(levels).sha256_text()!="27d24056a5ece002c0a99ffa06d1d2e6a31fb13dcd22e51e8bc47242523b547d":failures.append("Protected levels/objectives/enemies/hazards/rewards changed")
	print("THERMAL_LAYOUT_CONTRACT ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
