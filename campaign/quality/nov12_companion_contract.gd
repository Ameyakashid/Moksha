extends SceneTree
const Director=preload("res://campaign/narrative/companion_director.gd")
const Lines=preload("res://campaign/narrative/companion_lines.gd")
var checks:=0
func check(value:bool,label:String)->void:
	checks+=1
	if not value:push_error(label);quit(1)
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
	check(d.seen.has("rain_street"),"exclusive route observation")
	d.retire();d.tick(10,"rainline",roof,true);check(d.text().is_empty(),"retry no repeated line")
	d.reset();d.enabled=false;d.tick(10,"rainline",roof,true);check(d.text().is_empty() and d.seen.is_empty(),"disabled presentation no consumption")
	var ids:Dictionary={}
	var hud=load("res://campaign/views/campaign_hud.gd").new()
	for entry in Lines.entries():
		check(not ids.has(entry.id),"unique ID");ids[entry.id]=true
		var layout:Dictionary=hud.context_layout({"notice_visible":true,"notice":entry.text},57)
		check(not layout.context_truncated,"full line fits bounded HUD")
	check(ids.size()==14,"14 authored entries incl exclusive choices")
	hud.free()
	print("COMPANION_CONTRACT_PASS ",checks);quit(0)
