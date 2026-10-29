@tool
class_name MokshaChainTarget
extends MokshaContactTarget
## Passive instrument: records every delivered strike so duplicate effects stay
## visible. It has no health, AI, movement authority or independent hit timer.
@export_range(1, 12, 1) var history_limit := 6
var strike_history: Array[Dictionary] = []
var total_damage := 0.0

func receive_strike(payload: Dictionary) -> void:
	var record := {"serial": int(payload.get("serial", -1)),
		"step": int(payload.get("step_index", -1)),
		"label": str(payload.get("step_label", "HIT")),
		"damage": float(payload.get("damage", 0)),
		"contact_position": payload.get("contact_position", global_position),
		"impulse": payload.get("impulse", Vector2.ZERO)}
	strike_history.append(record)
	while strike_history.size() > history_limit: strike_history.pop_front()
	total_damage += record.damage
	super.receive_strike(payload)

func reset_target() -> void:
	strike_history.clear()
	total_damage = 0
	super.reset_target()

func _draw() -> void:
	super._draw()
	if Engine.is_editor_hint() or strike_history.is_empty(): return
	var latest: Dictionary = strike_history.back()
	var text := "%s / #%d / %.1f DMG" % [latest.label, latest.serial, total_damage]
	draw_string(ThemeDB.fallback_font, Vector2(-20, 23), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color("89c9bc"))
