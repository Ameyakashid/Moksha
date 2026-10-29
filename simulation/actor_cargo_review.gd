extends "res://demo/mission.gd"
## Native review of unchanged authored mission geometry. Only initial spawn and
## room selection differ; all cargo, policies and motor contacts are production.
func _ready() -> void:
	save_enabled=false
	var area:Dictionary=sectors[0].duplicate(true)
	area.spawn=Vector2(605,300)
	sectors.assign([area])
	super._ready(); start_new(true); chapter_left=0
	notice="CARGO CONTACT REVIEW / A-D push · Space stand/jump · J launch · K guard · R reset"
	notice_left=18
