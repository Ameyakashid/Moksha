extends Node2D
## Presentation and scene lifecycle only. No scripted combat outcomes.
func _ready() -> void:
	# Explicit scene opt-in after the separate counter acceptance proof.
	$Player/BodyShape/IncomingStrikeReceiver.counterable = true
	$NPC/BodyShape/IncomingStrikeReceiver.counterable = true
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_F12: get_viewport().get_texture().get_image().save_png("res://simulation/evidence/native_counter.png")
		KEY_ESCAPE: get_tree().change_scene_to_file("res://simulation/gym.tscn")
		KEY_R: get_tree().reload_current_scene()
func _process(_dt: float) -> void:
	$HUD/Status.text = "PLAYER  health %.2f | %s | received %d | counters %d\nNPC  health %.2f | %s | received %d | counters %d\nNPC: %s | weapon: %s" % [
		$Player/Health.current_health, $Player.main_action, $Player/BodyShape/IncomingStrikeReceiver.accepted_count, $Player/ShieldContactAdapter.confirmed_counters,
		$NPC/Health.current_health, $NPC.main_action, $NPC/BodyShape/IncomingStrikeReceiver.accepted_count, $NPC/ShieldContactAdapter.confirmed_counters,
		$NPC/MeleePolicy.reason, $NPC.weapon_phase]
