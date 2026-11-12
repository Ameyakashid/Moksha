extends SceneTree
func _initialize()->void:
	var route=preload("res://campaign/quality/nov12_thermal_route.gd")
	var failures:Array=[]
	for at in [Vector2.ZERO,Vector2(3310,120),Vector2(3430,-90)]:
		var plan:Dictionary=route.stationary_plan(at)
		if plan.keys().size()!=4 or plan.get("target")!=at:failures.append("Transition target schema")
		for field in ["up","jump","drop"]:
			if typeof(plan.get(field))!=TYPE_BOOL or plan[field]:failures.append("Transition boolean schema: "+field)
	print("THERMAL_OBSERVER_UNIT ",JSON.stringify({"passed":failures.is_empty(),"failures":failures}))
	quit(0 if failures.is_empty() else 1)
