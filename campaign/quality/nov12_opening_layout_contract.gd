extends SceneTree
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label)
func _initialize()->void:
	var all:Array[Dictionary]=preload("res://campaign/logic/campaign_data.gd").sectors()
	check(all.size()==32,"32 stable districts")
	var ids:Array=[];var enemies:=0;var goals:=0
	for d in all:
		check(not d.id in ids,"unique district "+str(d.id));ids.append(d.id)
		enemies+=d.enemies.size()+d.get("captains",[]).size();goals+=d.get("objectives",[]).size()
	check(enemies==250,"same 250 enemy placements")
	check(goals==123,"same 123 authored objectives")
	var rain:Dictionary=all[0];var clinic:Dictionary=all[1];var tram:Dictionary=all[2]
	check(rain.id=="rainline" and clinic.id=="city_clinic" and tram.id=="city_tram_depot","opening order unchanged")
	check(rain.enemies[0]==[780,"sentinel",300] and rain.enemies[1]==[1170,"sentinel",300],"first ground guards separated by 390 pixels")
	check(rain.enemies.size()==17,"rainline patrol count retained")
	check(clinic.objectives.map(func(o):return o.id)==["cell","generator","patients","medic"],"clinic objective identities unchanged")
	check(clinic.objectives[1].requires==["cell"] and clinic.objectives[2].requires==["generator"],"clinic progression dependencies unchanged")
	check(clinic.objective_doors[0].at==Vector2(2850,150) and clinic.objective_doors[0].size==Vector2(24,300) and clinic.objective_doors[0].requires==["generator"],"reserve-powered street shortcut")
	check(clinic.platforms.has(Rect2(2380,-80,420,18)) and clinic.platforms.has(Rect2(2940,-145,380,18)),"closed shortcut keeps upper roof traversal")
	check(clinic.platforms.has(Rect2(2240,175,430,18)) and clinic.platforms.has(Rect2(1760,140,340,18)),"lower sheltered return terraces")
	var terrace_y:=INF
	for rect in clinic.platforms:
		if rect.position.x==1760 and rect.size==Vector2(340,18):terrace_y=rect.position.y
	check(245.0-terrace_y>=90.0,"return terrace leaves pull-up headroom over clinic floor block")
	check(tram.enemies[0]==[1320,"sentinel",300] and tram.enemies[1]==[1810,"sentry",50],"first maintenance climb has no immediate sentry")
	check(tram.hazards.size()==2 and tram.hazards[0].at==Vector2(2460,294),"hazard identities/positions retained")
	print("NOV12_OPENING_LAYOUT_RESULT "+JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
