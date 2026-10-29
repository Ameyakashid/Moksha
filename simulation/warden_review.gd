extends "res://demo/mission.gd"
## Isolated native review, not full mission evidence. Only initial room selection
## and player spawn differ; actual factory, authored foes and ordinary play follow.
func _ready() -> void:
	save_enabled = false
	var arena: Dictionary = sectors[6].duplicate(true)
	arena.spawn = Vector2(920,300)
	sectors.assign([arena])
	super._ready()
	start_new(true)
	chapter_left = 0
	notice = "WARDEN REVIEW / Initial room fixture · A-D move · Space jump · J strike · K parry"
	notice_left = 12
