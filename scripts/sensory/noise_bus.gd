extends Node
## Autoload name: NoiseBus. Exact world-space event provenance, not audio playback.
## Optional service: actors can get_node_or_null("/root/NoiseBus").

signal noise_emitted(origin: Vector2, kind: StringName, loudness: float, source: Node)

@export var history_limit: int = 256
var event_history: Array[Dictionary] = []
var event_count: int = 0

func emit_noise(origin: Vector2, kind: StringName, loudness: float = 1.0, source: Node = null) -> void:
	if not origin.is_finite() or not is_finite(loudness) or loudness <= 0.0:
		return
	event_count += 1
	var valid_source := source if is_instance_valid(source) else null
	event_history.append({
		"sequence": event_count,
		"origin": origin,
		"kind": kind,
		"loudness": loudness,
		"source_id": valid_source.get_instance_id() if valid_source != null else 0,
		"source_name": str(valid_source.name) if valid_source != null else "",
		"ticks_msec": Time.get_ticks_msec(),
	})
	while event_history.size() > maxi(0, history_limit):
		event_history.pop_front()
	noise_emitted.emit(origin, kind, loudness, valid_source)

func clear_history() -> void:
	event_history.clear()
	event_count = 0

func debug_snapshot() -> Dictionary:
	return {"event_count": event_count, "history": event_history.duplicate(true)}
