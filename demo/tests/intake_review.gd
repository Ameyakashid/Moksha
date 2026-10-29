extends "res://demo/mission.gd"
## Review starts at real sector index 1; save disabled, no special gameplay rules.
func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--recovery=right": sectors[1]["spawn"]=Vector2(1880,-100)
	super._ready()
	save_enabled=false
	start_new(true)
	load_sector(1)
