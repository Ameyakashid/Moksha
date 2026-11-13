@tool
extends "res://simulation/ui/mission_hud.gd"
## Campaign-only extension of the original typed HUD snapshot boundary.
## Unknown keys are still discarded. Invalid campaign input leaves both snapshots
## untouched, and the original owner remains the validator for all shared fields.
signal tactical_presentation_accepted(id:String,text:String)
signal companion_presentation_accepted(id:String,blocked:bool)
const CAMPAIGN_FIELDS := {"ladder_attached":false,"ladder_contact":false,"hearing_retained":true,"smell_retained":true,"focus_specialization":"","last_result_available":false,"completion_save_failed":false,"tactical_line_id":"","companion_line_id":"", "guidance":"", "district_index":0, "district_count":0, "level_index":0, "lens":"", "required_done":0, "required_total":0, "gate_open":false, "input_device":""}
var _campaign_snapshot:Dictionary={}
func set_snapshot(value:Dictionary)->bool:
	# Omitted grip must retire a previous true hint, without extending shared HUD state.
	var next:Dictionary={"tactical_line_id":"","ladder_attached":false,"ladder_contact":false,"smell_retained":true}
	for key in CAMPAIGN_FIELDS:
		if not value.has(key):continue
		if typeof(value[key])!=typeof(CAMPAIGN_FIELDS[key]):return false
		if key=="input_device" and value[key] not in ["keyboard","controller"]:return false
		if typeof(value[key])==TYPE_INT and value[key]<0:return false
		next[key]=value[key]
	var previous:=_campaign_snapshot
	_campaign_snapshot=next
	if not super.set_snapshot(value):
		_campaign_snapshot=previous
		return false
	var line_id:=str(next.get("companion_line_id",""))
	if not value.get("notice_visible",false) or str(value.get("notice","")).is_empty():line_id=""
	var blocked:bool=value.get("state","")!="playing" or value.get("chapter_visible",false) or not str(value.get("prompt","")).is_empty() or (value.get("notice_visible",false) and line_id.is_empty())
	if get_node_or_null("View")!=null:
		companion_presentation_accepted.emit(line_id,blocked)
		var tactical_id:=str(next.get("tactical_line_id",""))
		if _snapshot.get("tactical_line_id","")==tactical_id and _snapshot.get("notice_visible",false) and _snapshot.get("notice","")==value.get("notice","") and not tactical_id.is_empty() and value.get("state","")=="playing" and value.get("notice_visible",false) and not value.get("chapter_visible",false) and not value.get("panel_override",false) and str(value.get("prompt","")).is_empty():
			tactical_presentation_accepted.emit(tactical_id,str(value.get("notice","")))
	return true
func _sync_view()->void:
	_snapshot.merge(_campaign_snapshot,true)
	super._sync_view()

func caption_safe_rect()->Rect2:
	var view:=get_node_or_null("View")
	return view.caption_safe_rect() if view!=null and view.has_method("caption_safe_rect") else get_viewport_rect()

func caption_exclusion_rects()->Array[Rect2]:
	var view=get_node_or_null("View")
	if is_instance_valid(view) and view.has_method("caption_exclusion_rects"):return view.caption_exclusion_rects()
	var empty:Array[Rect2]=[]
	return empty
