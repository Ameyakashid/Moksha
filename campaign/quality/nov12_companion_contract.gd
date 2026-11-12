extends SceneTree
const Director=preload("res://campaign/narrative/companion_director.gd")
const Lines=preload("res://campaign/narrative/companion_lines.gd")
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String)->void:
	checks+=1
	if not value:failures.append(label);push_error(label)
func _initialize()->void:
	var d=Director.new()
	var events:Array[String]=["clinic_cell","clinic_power"]
	d.tick(3,"clinic",events,false);check(d.text().is_empty() and d.seen.is_empty(),"hidden not consumed")
	d.tick(3,"clinic",events,true);check(d.active.id=="clinic_power","author priority")
	check(d.seen.is_empty(),"selection is not acknowledgement")
	d.tick(10,"clinic",events,true);check(not d.active.is_empty(),"unpresented does not expire")
	d.acknowledge();check(d.seen.has("clinic_power"),"acknowledged only")
	d.tick(.1,"clinic",[],true);check(d.text().is_empty(),"stale event retired")
	d.tick(9,"clinic",events,true);check(d.active.id=="clinic_cell","next eligible after cooldown")
	d.tick(.1,"other",[],true);check(d.text().is_empty(),"room retirement")
	d.reset();check(d.seen.is_empty() and d.text().is_empty(),"new session clear")
	var roof:Array[String]=["rain_roof"]
	d.tick(3,"rainline",roof,true);d.acknowledge()
	check(not d.seen.has("rain_street"),"quiet reminder remains distinct from roof observation")
	d.preempt();check(d.cooldown>=8,"UI preemption retains cooldown");d.tick(10,"rainline",roof,true);check(d.text().is_empty(),"retry no repeated line")
	d.reset();d.enabled=false;d.tick(10,"rainline",roof,true);check(d.text().is_empty() and d.seen.is_empty(),"disabled presentation no consumption")
	var ids:Dictionary={}
	var hud=load("res://campaign/views/campaign_hud.gd").new()
	for entry in Lines.entries():
		check(not ids.has(entry.id),"unique ID");ids[entry.id]=true
		var layout:Dictionary=hud.context_layout({"notice_visible":true,"notice":entry.text},57)
		check(not layout.context_truncated,"full line fits bounded HUD")
	check(ids.size()==14,"14 authored entries incl exclusive choices")
	var owner=load("res://campaign/views/campaign_hud_owner.gd").new()
	var view=load("res://campaign/views/campaign_hud.gd").new();view.name="View";owner.add_child(view)
	var delivered:Array=[]
	owner.companion_presentation_accepted.connect(func(id:String,blocked:bool):delivered.append([id,blocked]))
	check(not owner.set_snapshot({"state":"playing","notice_visible":"wrong","companion_line_id":"clinic_cell"}),"invalid snapshot rejected")
	check(delivered.is_empty(),"invalid cannot acknowledge")
	check(owner.set_snapshot({"state":"playing","notice_visible":true,"notice":"Intellect: Test","companion_line_id":"clinic_cell"}),"valid presentation accepted")
	check(delivered==[["clinic_cell",false]],"explicit accepted line signal")
	owner.get_snapshot();check(delivered.size()==1,"snapshot read has no delivery")
	owner.set_snapshot({"state":"playing","notice_visible":false,"companion_line_id":"clinic_cell"})
	check(delivered[-1]==["",false],"invisible line ID cannot acknowledge")
	owner.set_snapshot({"state":"playing","notice_visible":true,"notice":"Priority notice"})
	check(delivered[-1]==["",true],"ordinary notice preempts")
	owner.free()
	hud.free()
	print("COMPANION_CONTRACT_RESULT ",JSON.stringify({"passed":failures.is_empty(),"checks":checks,"failures":failures}));quit(0 if failures.is_empty() else 1)
