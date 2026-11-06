@tool
extends "res://simulation/ui/mission_hud.gd"
## Campaign-only extension of the original typed HUD snapshot boundary.
## Unknown keys are still discarded. Invalid campaign input leaves both snapshots
## untouched, and the original owner remains the validator for all shared fields.
const CAMPAIGN_FIELDS := {"guidance":"", "district_index":0, "district_count":0, "level_index":0, "lens":"", "required_done":0, "required_total":0, "gate_open":false, "input_device":""}
var _campaign_snapshot:Dictionary={}
func set_snapshot(value:Dictionary)->bool:
	var next:Dictionary={}
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
	return true
func _sync_view()->void:
	_snapshot.merge(_campaign_snapshot,true)
	super._sync_view()
