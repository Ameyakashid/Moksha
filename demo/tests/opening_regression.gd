extends SceneTree
func _initialize()->void:
	var scene=load("res://demo/components/opening_scene.gd")
	var failures:Array[String]=[]
	var checks:=0
	for t in [0.0,0.3,0.4,0.55,0.62,0.72,1.0,1.08,1.15,1.2,2.0]:
		var p=scene.pose(t)
		for key in ["throw_hand","spear_tip","head","catch_hand"]:
			checks+=1
			if not p[key].is_finite(): failures.append("nonfinite "+key)
	for pair in [[0.0,0.4],[0.55,0.72]]:
		checks+=1
		if scene.pose(pair[0]).throw_hand!=scene.pose(pair[1]).throw_hand: failures.append("release micropause")
	checks+=3
	if scene.pose(1.2).catch_hand!=Vector2(335,198): failures.append("hand at former head")
	if scene.pose(1.2).head.distance_to(Vector2(335,198))<15: failures.append("head clear of spear")
	if scene.pose(1.2).spear_tip!=scene.pose(1.2).catch_hand: failures.append("catch contact")
	var f=FileAccess.open("res://demo/evidence/opening_regression.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"checks":checks,"failures":failures,"scope":"View-only timing/contact math, native review separate"},"\t"))
	print("OPENING ",checks," checks ",failures)
	quit(0 if failures.is_empty() else 1)
