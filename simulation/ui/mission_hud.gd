@tool
extends Node2D
## Presentation-only snapshot owner. No host lookup, input or simulation authority.
const Appearance = preload("res://demo/views/hud_appearance.gd")
const DEFAULTS := {"state": "title", "authored_area_count": 0, "ending_count": 0, "continue_available": false, "intro_time": 0.0, "player_present": false, "sector_title": "", "sector_text": "", "sector_hint": "", "has_freight": false, "blind": false, "health_current": 0.0, "health_capacity": 1.0, "elapsed": 0.0, "objective": "", "chapter_visible": false, "notice_visible": false, "notice": "", "prompt": "", "archive_text": "", "cache_count": 0, "cache_total": 0, "deaths": 0, "kills": 0, "panel_override": false, "panel_title": "", "panel_body": "", "panel_footer": ""}
var _snapshot: Dictionary = DEFAULTS.duplicate(true)
@export var appearance: Appearance:
	set(value):
		appearance = value
		_sync_view()
func _ready() -> void:
	_sync_view()
func set_snapshot(value: Dictionary) -> bool:
	var next: Dictionary = DEFAULTS.duplicate(true)
	for key in DEFAULTS:
		if not value.has(key): continue
		var item: Variant = value[key]
		var expected: int = typeof(DEFAULTS[key])
		if expected == TYPE_FLOAT:
			if typeof(item) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(item)): return false
			next[key] = float(item)
		elif typeof(item) != expected: return false
		else: next[key] = item
	if next.health_capacity <= 0.0 or next.authored_area_count < 0 or next.ending_count < 0: return false
	_snapshot = next
	_sync_view()
	return true
func get_snapshot() -> Dictionary:
	return _snapshot.duplicate(true)
func _sync_view() -> void:
	var view := get_node_or_null("View")
	if view == null: return
	view.appearance = appearance
	view.set_snapshot(_snapshot)
