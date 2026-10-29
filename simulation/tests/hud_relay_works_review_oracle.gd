extends "res://simulation/tests/hud_legacy_oracle.gd"
func render_hud(c:Node2D)->void:
	if state=="complete":
		_panel(c,"RELAY WORKS / COMPLETE","Three circuits restored. The short passages are open.\n\nActive play: %02d:%02d     Defeats: %d\nGuards: %d     Archive: %d / 1\n\nThis records the isolated Relay Works playtest." % [int(elapsed)/60,int(elapsed)%60,deaths,kills,caches.size()],"Enter / N  Return to title")
	else: super.render_hud(c)
