extends "res://demo/mission.gd"
## Isolated review substitutes only sector0; production mission_data stays untouched.
func _ready() -> void:
	sectors[0]=preload("res://demo/areas/rainline_neighbourhood.gd").sector()
	super._ready()
	save_enabled=false
	start_new(true)
