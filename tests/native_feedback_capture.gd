extends Node
## Passive native QA recorder: observes real play, never drives actors or inputs.
## It saves first damage/defeat/break frames at the engine's completed draw.
var recorded: Dictionary = {}
func _ready() -> void:
	get_node("/root/NoiseBus").noise_emitted.connect(_on_noise)
func _on_noise(_origin: Vector2, kind: StringName, _loudness: float, _source: Node) -> void:
	if kind not in [&"enemy_damage",&"enemy_death",&"prop_break",&"player_damage"] or recorded.has(kind): return
	recorded[kind] = true
	_capture.call_deferred(String(kind))
func _capture(kind: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://delivery/MOKSHA-contact-"+kind+".png")
