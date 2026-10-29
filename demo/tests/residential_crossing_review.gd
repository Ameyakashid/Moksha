extends "res://demo/mission.gd"
## Explicit sector-start/sight fixture, not a real Exchange choice or full journey.
func _ready()->void:
 super._ready()
 save_enabled=false
 start_new(true)
 for arg in OS.get_cmdline_user_args():
  if arg=="--sacrifice":blind=true
 load_sector(5)
