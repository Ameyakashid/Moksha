extends SceneTree
func _initialize()->void:
	var sectors=load("res://campaign/logic/campaign_data.gd").sectors()
	var levels:Dictionary={}
	for d in sectors:
		var level:String=str(d.level)
		if not levels.has(level):levels[level]={"districts":0,"width":0,"enemies":0,"objectives":{},"required":0,"optional":0,"doors":0,"hazards":0,"lifts":0,"freight":0,"all_kill_rooms":0,"district_details":[]}
		var x:Dictionary=levels[level];x.districts+=1;x.width+=d.width;x.enemies+=d.enemies.size();x.doors+=d.get("objective_doors",[]).size();x.hazards+=d.get("hazards",[]).size();x.lifts+=d.get("lifts",[]).size();x.freight+=int(d.has("freight"));x.all_kill_rooms+=int(d.get("lock",false))
		for o in d.get("objectives",[]):
			x.objectives[o.kind]=x.objectives.get(o.kind,0)+1
			x["optional" if o.get("optional",false) else "required"]+=1
		x.district_details.append({"id":d.id,"width":d.width,"objectives":d.get("objectives",[]).size(),"relays":d.get("relays",[d.relay] if d.has("relay") else []).size(),"lock":d.get("lock",false)})
	var file=FileAccess.open("res://campaign/qa_audit/content_inventory.json",FileAccess.WRITE);file.store_string(JSON.stringify(levels,"\t"));print(JSON.stringify(levels));quit()
