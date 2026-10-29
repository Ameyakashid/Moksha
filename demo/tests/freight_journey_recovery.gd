extends "res://demo/tests/freight_journey_route.gd"
## Input-only intentional mishandling: return through loaded deck, lose cargo
## to lower court, then climb to original cradle and use normal E replacement.
var recovery_phase:=0
var loss_observed:=false
var floor_return:=false
var replacement_observed:=false
var recovery_trace:Array=[]
func freight_plan(data:Dictionary)->Dictionary:
	if host.sector==3 and journey_stage==3 and recovery_phase<2:
		var cargo=host.room.freight_cradle.cargo
		if is_instance_valid(cargo) and cargo.global_position.y>260:loss_observed=true
		if not is_instance_valid(cargo) or not cargo.alive:loss_observed=true
		if host.player.grounded and host.player.position.x<1140 and host.player.position.y>280:
			floor_return=true
			if loss_observed:recovery_phase=2
		if frame%hz==0:recovery_trace.append({"frame":frame,"player":str(host.player.position),"cargo":freight_snapshot()})
		if recovery_phase<2:return {"raw":{"left":1.0} if host.player.position.x>1030 else {}}
	if host.sector==3 and host.room.freight_cradle.replacement_count>1:replacement_observed=true
	return super.freight_plan(data)
func run()->void:
	await super.run()
	if not loss_observed:failures.append("No physical cargo loss observed")
	if not floor_return:failures.append("No actual lower court return")
	if not replacement_observed:failures.append("No normal cradle replacement")
	var base="res://demo/evidence/freight_journey_%s_%dhz_%s.json"%[approach,hz,"traded" if sacrifice else "retained"]
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base))
	report.merge({"recovery_fixture":"input-only intentional mishandling; no state placements","loss_observed":loss_observed,"floor_return":floor_return,"replacement_observed":replacement_observed,"recovery_trace":recovery_trace,"failures":failures,"passed":failures.is_empty()},true)
	var path="res://demo/evidence/freight_journey_recovery_%dhz.json"%hz
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("FREIGHT RECOVERY ",path," failures=",failures)
	quit(0 if failures.is_empty() else 1)
