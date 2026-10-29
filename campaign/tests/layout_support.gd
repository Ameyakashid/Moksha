extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
	var failures:Array[String]=[]
	var levels:Dictionary={};var objectives:=0;var enemies:=0;var width:=0.0
	for d in preload("res://campaign/logic/campaign_data.gd").sectors():
		levels[d.level]=int(levels.get(d.level,0))+1;width+=d.width;enemies+=d.enemies.size()+d.get("captains",[]).size()
		for spec in d.get("objectives",[]):
			objectives+=1
			var p:Vector2=spec.at
			var supported:bool=absf(p.y-300)<1 and not d.get("gaps",[]).any(func(gap):return p.x>gap.x and p.x<gap.y)
			for rect in d.platforms:
				if absf(p.y-rect.position.y)<1 and p.x>=rect.position.x and p.x<=rect.end.x:supported=true
				if rect.size.y>18 and rect.grow(-1).has_point(p-Vector2(0,1)):failures.append(d.id+" objective embedded:"+spec.id)
			if not supported:failures.append(d.id+" objective unsupported:"+spec.id)
	print("LAYOUT_INVENTORY levels=",levels," objectives=",objectives," enemies=",enemies," width=",width," failures=",failures)
	quit(0 if failures.is_empty() else 1)
