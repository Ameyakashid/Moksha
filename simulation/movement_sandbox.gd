extends Node2D
## Scene composition and diagnostics. Never supplies movement or game outcomes.
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_F12: get_viewport().get_texture().get_image().save_png("res://simulation/evidence/native_movement.png")
		KEY_ESCAPE: get_tree().change_scene_to_file("res://simulation/gym.tscn")
		KEY_R: get_tree().reload_current_scene()
func _process(_dt: float) -> void:
	$HUD/Status.text = "PLAYER  support %s | %s | health %.0f | sounds %d\nNPC  support %s | %s | health %.0f | sounds %d\nNPC observation: %s" % [
		$Player.grounded, $Player.main_action, $Player/Health.current_health, $Player/NoiseRelay.forwarded_count,
		$NPC.grounded, $NPC/PatrolPolicy.state, $NPC/Health.current_health, $NPC/NoiseRelay.forwarded_count, $NPC/PatrolPolicy.reason]
