extends "res://demo/mission.gd"
## Isolated production-host module. No fixture movement or objective shortcuts.
func _ready()->void:
	sectors=[preload("res://demo/areas/freight_lock.gd").sector(),{"title":"FREIGHT DELIVERED","subtitle":"Freight Lock module complete","width":700,"theme":"interior","text":"The physical interlock is released.","hint":"E at the lift records this module run.","platforms":[],"enemies":[],"props":[],"ending":true}]
	super._ready()
	save_enabled=false
	start_new(true)

func _hud_snapshot() -> Dictionary:
	var data := super._hud_snapshot()
	if state == "complete":
		data.merge({"panel_override": true, "panel_title": "FREIGHT LOCK / COMPLETE", "panel_body": "Cargo seated. The physical interlock is released.\n\nThis records the isolated Freight Lock playtest.", "panel_footer": "Enter / N  Return to title"})
	return data
