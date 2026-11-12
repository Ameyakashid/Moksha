extends RefCounted
## Validated, detached authored definitions. No live nodes or filesystem writes.
## Unknown fields remain available to presentation and future content adapters.
const EXPECTED_DISTRICTS := 32

static func validate(levels:Array)->Dictionary:
	if levels.size()!=5:return _bad("Expected five level definitions.")
	var sectors:Array[Dictionary]=[]
	var ids:Dictionary={}
	for index in levels.size():
		var entries:Variant=levels[index]
		if not entries is Array or entries.is_empty():return _bad("Level %d has no district definitions."%(index+1))
		for entry in entries:
			if not entry is Dictionary:return _bad("Level %d contains an invalid district."%(index+1))
			var id:Variant=entry.get("id")
			if not id is String or id.is_empty() or ids.has(id):return _bad("Missing or duplicate district ID in level %d."%(index+1))
			ids[id]=true
			var objectives:Variant=entry.get("objectives",[])
			if not objectives is Array:return _bad("District %s has invalid objectives."%id)
			var goal_ids:Dictionary={}
			for goal in objectives:
				if not goal is Dictionary:return _bad("District %s has an invalid objective."%id)
				var goal_id:Variant=goal.get("id")
				if not goal_id is String or goal_id.is_empty() or goal_ids.has(goal_id):return _bad("Missing or duplicate objective ID in %s."%id)
				goal_ids[goal_id]=true
			for goal in objectives:
				var requires:Variant=goal.get("requires",[])
				if not requires is Array:return _bad("Invalid objective dependencies in %s."%id)
				for required in requires:
					if not required is String or not goal_ids.has(required):return _bad("Unknown objective dependency in %s."%id)
			# A known ID can still be impossible to complete (self-edge or cycle).
			var resolved:Dictionary={}
			while resolved.size()<objectives.size():
				var previous:=resolved.size()
				for goal in objectives:
					if resolved.has(goal.id):continue
					var ready:=true
					for required in goal.get("requires",[]):
						if not resolved.has(required):ready=false;break
					if ready:resolved[goal.id]=true
				if resolved.size()==previous:return _bad("Cyclic objective dependencies in %s."%id)
			var data:Dictionary=entry.duplicate(true)
			data["level"]=index+1
			sectors.append(data)
	if sectors.size()!=EXPECTED_DISTRICTS:return _bad("Expected %d districts; found %d."%[EXPECTED_DISTRICTS,sectors.size()])
	return {"ok":true,"sectors":sectors}

static func _bad(message:String)->Dictionary:
	return {"ok":false,"error":message,"sectors":[]}
