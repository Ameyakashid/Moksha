extends "res://campaign/quality/nov6_full_campaign_route.gd"
## Continuous normal-title first-three-district acceptance, not manual play.
## Only ordinary inputs; the clinic return waypoint proves the opened shortcut.
var clinic_closed_seen:=false
var clinic_roof_crossed:=false
var clinic_open_seen:=false
var clinic_street_crossed:=false
var previous_clinic_position:=Vector2.ZERO
var clinic_observed:=false
var finished:=false
func decide()->Dictionary:
	if host.sector>=3 and not finished:
		finished=true
		var drift:Array[String]=[]
		for path in full_sources:
			if FileAccess.get_sha256(path)!=full_sources[path]:drift.append(path)
		if not clinic_closed_seen:failures.append("Clinic shortcut was not observed closed before reserve power")
		if not clinic_roof_crossed:failures.append("No physical outbound roof crossing above the closed shortcut")
		if not clinic_open_seen:failures.append("Restored clinic generator did not open street shortcut")
		if not clinic_street_crossed:failures.append("No physical return-trip crossing through the opened street shortcut")
		if objective_receipts.size()!=3:failures.append("Missing required objective/gate receipts for three districts")
		if host.deaths!=0:failures.append("Unexpected death")
		if not drift.is_empty():failures.append("Source drift")
		var report:Dictionary={"passed":failures.is_empty(),"hz":hz,"lens":host.lens,"districts":["rainline","city_clinic","city_tram_depot"],"active_seconds":host.elapsed,"deaths":host.deaths,"objective_receipts":objective_receipts,"clinic_closed_seen":clinic_closed_seen,"clinic_roof_crossed":clinic_roof_crossed,"clinic_open_seen":clinic_open_seen,"clinic_street_crossed":clinic_street_crossed,"events":events,"source_hashes":full_sources,"source_drift":drift,"failures":failures,"method":"Normal title and ordinary automated input. No state/position/health/objective writes. Explicit walking target after restoring clinic power proves real street-shortcut traversal. Not manual play or human duration validation."}
		var path:="res://campaign/quality/nov12_opening_route_%d.json"%hz
		FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
		print("NOV12_OPENING_ROUTE_RESULT "+JSON.stringify({"passed":report.passed,"hz":hz,"seconds":host.elapsed,"failures":failures}))
		quit(0 if report.passed else 1)
		return {}
	if str(host.sectors[host.sector].id)=="city_clinic":
		var gate:Node
		for node in host.room.get_children():
			if node.get_script()==preload("res://campaign/logic/objective_door.gd") and absf(node.position.x-2850)<1:gate=node
		if is_instance_valid(gate):
			if not host.goal_done("generator") and not gate.opened:clinic_closed_seen=true
			if host.goal_done("generator") and gate.opened:clinic_open_seen=true
			var p:Vector2=host.player.position
			if clinic_observed and previous_clinic_position.x<2850 and p.x>=2850:
				if not gate.opened and p.y<0 and previous_clinic_position.y<0:clinic_roof_crossed=true
				if gate.opened and p.y>100 and previous_clinic_position.y>100:clinic_street_crossed=true
			previous_clinic_position=p;clinic_observed=true
	return super.decide()
func navigate(target:Vector2,data:Dictionary)->Dictionary:
	if str(data.id)=="city_clinic" and host.goal_done("generator") and not clinic_street_crossed:
		var fighting:bool=host.enemies.any(func(enemy):return is_instance_valid(enemy) and not enemy.dead and target.distance_to(enemy.position)<2 and host.player.position.distance_to(enemy.position)<115)
		if not fighting:
			var old_have_goal:=have_goal;have_goal=false
			var result:Dictionary=super.navigate(Vector2(2960,300),data)
			have_goal=old_have_goal
			return result
	return super.navigate(target,data)
