extends SceneTree
func _initialize() -> void:
	var districts: Array[Dictionary] = preload("res://campaign/logic/campaign_data.gd").sectors()
	var optional: Array[Dictionary] = []
	var required := 0
	var optional_count := 0
	var rewards := 0
	for district in districts:
		var goals: Array[Dictionary] = []
		for goal in district.get("objectives",[]):
			if not goal.get("optional",false): required += 1; continue
			optional_count += 1
			if goal.has("reward"): rewards += 1
			goals.append({"id":goal.id,"kind":goal.kind,"reward":goal.get("reward","")})
		if not goals.is_empty(): optional.append({"district":district.id,"goals":goals})
	print("OPTIONAL_INVENTORY "+JSON.stringify({"districts":districts.size(),"required_objectives":required,"optional_objectives":optional_count,"rewarded_optional_objectives":rewards,"optional_districts":optional.size(),"inventory":optional}))
	quit()
