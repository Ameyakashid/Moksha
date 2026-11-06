extends "res://campaign/logic/campaign.gd"
## Deliberately broken test-only negative control.
func _cancel_sector_transition() -> void:
	_level_transition_snapshot.clear()
