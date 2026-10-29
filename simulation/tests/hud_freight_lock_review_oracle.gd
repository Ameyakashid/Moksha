extends "res://simulation/tests/hud_legacy_oracle.gd"
func render_hud(c:Node2D)->void:
	if state=="complete":
		_panel(c,"FREIGHT LOCK / COMPLETE","Cargo seated. The physical interlock is released.\n\nThis records the isolated Freight Lock playtest.","Enter / N  Return to title")
	else: super.render_hud(c)
