extends "res://demo/mission.gd"
## Explicit sector-start fixture; production physics and live enemies unchanged.
func _ready()->void:
	sectors[3]=preload("res://demo/areas/freight_journey.gd").sector()
	super._ready()
	save_enabled=false
	start_new(true)
	load_sector(3)
	for arg in OS.get_cmdline_user_args():
		if arg=="--sacrifice":
			blind=true
			_apply_trade()
			sonar.set_blind(true)
