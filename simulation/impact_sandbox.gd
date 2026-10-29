extends Node2D
## Composition and diagnostics only. Cargo starts in ordinary free fall.
## No trigger assigns health, motion, contact, guard success or target selection.
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_R: get_tree().reload_current_scene()
		KEY_ESCAPE: get_tree().change_scene_to_file("res://simulation/gym.tscn")
		KEY_F12: get_viewport().get_texture().get_image().save_png("res://simulation/evidence/native_impact.png")
func _process(_dt: float) -> void:
	var pc := $Player/PhysicalImpactReceiver
	var npc := $Enemy/PhysicalImpactReceiver
	$HUD/Status.text = "PC health %.2f / hits %d | NPC health %.2f / hits %d\nPC response: %s | NPC response: %s" % [
		$Player/Health.current_health, pc.accepted_count, $Enemy/StrikeHealth/Health.current_health, npc.accepted_count,
		pc.last_receipt.get("outcome", "waiting"), npc.last_receipt.get("outcome", "waiting")]
