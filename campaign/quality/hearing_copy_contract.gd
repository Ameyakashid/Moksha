extends SceneTree
## Presentation-only staged snapshots. No gameplay traversal claim.
var checks:=0
var failures:Array[String]=[]
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true);host.set_physics_process(false)
	var index:=0
	for i in host.sectors.size():
		if host.sectors[i].id=="l2_exchange":index=i
	host.load_sector(index);host.set_physics_process(false)
	var authored:Dictionary=host.sectors[index].duplicate(true)
	var retained:Dictionary=host._hud_snapshot()
	check(retained.sector_text==authored.text and retained.sector_hint==authored.hint,"retained hearing Exchange copy unchanged")
	host.hearing_retained=false
	var focused:Dictionary=host._hud_snapshot()
	check(focused.sector_text.contains("not yet validated in this prototype") and not focused.sector_text.contains("offers sight for speed"),"hearing-traded brief truthfully explains temporary limit")
	check(focused.sector_hint.contains("temporary combined-loss limit") and not focused.sector_hint.contains("choose sight trade"),"hearing-traded hint does not promise unavailable choice")
	check(focused.sector_text.ends_with(str(authored.text).split("\n",true,1)[1]),"remaining circuit/lift/stair prose preserved")
	check(focused.sector_hint.ends_with("Lift or stairs reach calibration. W/S climbs the recovery ladder."),"route instructions preserved")
	host.blind=true
	var dual:Dictionary=host._hud_snapshot()
	check(dual.sector_text.begins_with("Both sight and hearing are traded") and not dual.sector_text.contains("Sight stays intact"),"loaded dual loss label does not invent sight")
	check(dual.focus_specialization.is_empty() and dual.sector_hint.begins_with("Both senses traded; no sound-map."),"loaded dual loss does not promise focus or sound-map")
	host.blind=false;host.hearing_retained=true;host.state="hearing_choice"
	var offer:Dictionary=host._hud_snapshot()
	check(offer.panel_body.contains("Prototype limit:") and offer.panel_body.contains("combined sight/hearing loss is not yet validated"),"temporary limit disclosed before acceptance")
	var view=host.hud.get_node("View")
	for controller in [false,true]:
		var text:String=view.device_text(offer.panel_body,controller)
		var layout:Dictionary=view.panel_layout(offer.panel_title,text,offer.panel_footer)
		check(layout.body_top+layout.body_lines.size()*(layout.body_size+3)<=287,"offer measured body fits")
		check(309+maxi(0,layout.footer_lines.size()-1)*15<337,"offer measured footer fits")
	check(host.sectors[index]==authored,"snapshot copy never mutates authored district data")
	host.free();await process_frame
	print(JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"scope":"staged copy/layout measurements, not native pixels"}));quit(0 if failures.is_empty() else 1)
