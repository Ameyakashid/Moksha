extends Node2D
## Composition/diagnostics only. All observations come from actual sound events.
func _ready() -> void:
	$Enemy/HearingSensor.profile = $Enemy.hearing_profile
	$Enemy.defeated.connect(func(_actor): $Enemy/HearingSensor.enabled = false)
	$Enemy.configure($Player, get_node("/root/NoiseBus"))
	$Cargo/ImpactNoise.bind_body($Cargo, get_node("/root/NoiseBus"))
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F12:
		get_viewport().get_texture().get_image().save_png("res://simulation/evidence/native_hearing.png")
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://simulation/gym.tscn")
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
func _process(_dt: float) -> void:
	$HUD/Status.text = "PC heard: %d | NPC heard: %d | NPC decision: %s\n%s" % [$Player/HearingSensor.heard_count,
		$Enemy/HearingSensor.heard_count, $Enemy.ai_state,
		"Same hearing profile. Wall reduces range; it does not trigger an outcome."]
