extends "res://demo/mission.gd"
## Native review entry, not a mission route completion. The unchanged authored
## Intake room and actual mission factory run with one explicit initial spawn.
## No post-spawn movement, attack, AI, contact, Health or outcome is scripted.
func _ready() -> void:
	save_enabled = false
	var intake: Dictionary = sectors[1].duplicate(true)
	intake.spawn = Vector2(790,135)
	sectors.assign([intake])
	super._ready()
	start_new(true)
	chapter_left = 0
	notice = "SENTRY REVIEW / A-D move · Space jump · J strike · K guard/reflect · R restart"
	notice_left = 12
