extends "res://demo/mission.gd"
## Isolated playable module. No teleports, bots or fixture-driven progression.
func _ready()->void:
	sectors=[preload("res://demo/areas/relay_works.gd").sector(),{"title":"CIRCUITS RESTORED","subtitle":"Relay Works module complete","width":700,"theme":"interior","text":"The three crews' routes are open again.","hint":"E at the lift records this module run.","platforms":[],"enemies":[],"props":[],"ending":true}]
	super._ready()
	save_enabled=false
	start_new(true)

func _hud_snapshot() -> Dictionary:
	var data := super._hud_snapshot()
	if state == "complete":
		data.merge({"panel_override": true, "panel_title": "RELAY WORKS / COMPLETE", "panel_body": "Three circuits restored. The short passages are open.\n\nActive play: %02d:%02d     Defeats: %d\nGuards: %d     Archive: %d / 1\n\nThis records the isolated Relay Works playtest." % [int(elapsed)/60,int(elapsed)%60,deaths,kills,caches.size()], "panel_footer": "Enter / N  Return to title"})
	return data
