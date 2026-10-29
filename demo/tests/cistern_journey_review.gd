extends "res://demo/mission.gd"
## Isolated sector-start fixture, not a campaign/save or real sight-trade proof.
func _ready()->void:
 super._ready()
 save_enabled=false
 start_new(true)
 for arg in OS.get_cmdline_user_args():
  if arg=="--sacrifice":blind=true
 load_sector(4)
