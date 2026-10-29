extends "res://demo/mission.gd"
## Sector-start fixture; sight choice is made at the existing real hub station.
func _ready()->void:
 super._ready()
 save_enabled=false
 start_new(true)
 for i in sectors.size():
  if str(sectors[i].get("id",""))=="relay_works":load_sector(i);break
