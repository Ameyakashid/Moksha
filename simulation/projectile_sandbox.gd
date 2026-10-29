extends Node2D
## Native fixture presentation; movement/actions/contact stay in components.
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_ESCAPE: get_tree().change_scene_to_file("res://simulation/gym.tscn")
		KEY_R: get_tree().reload_current_scene()
		KEY_F12: get_viewport().get_texture().get_image().save_png("res://simulation/evidence/native_projectile.png")
func _process(_dt: float) -> void:
	$HUD/Status.text = "PC  health %.1f | %s / %s | shots %d | contacts %d\nNPC health %.1f | %s / %s | shots %d | contacts %d\nFlying carriers %d | K just before contact reflects a real bolt" % [
		$Player/Health.current_health,$Player.main_action,$Player.weapon_phase,$Player/ProjectileEmitter.emitted_count,$Player/ProjectileReceiver.accepted_count,
		$NPC/Health.current_health,$NPC.main_action,$NPC.weapon_phase,$NPC/ProjectileEmitter.emitted_count,$NPC/ProjectileReceiver.accepted_count,get_tree().get_nodes_in_group("shared_projectiles").size()]
	queue_redraw()
func _draw() -> void:
	for actor in [$Player,$NPC]:
		var emitter: Node = actor.get_node("ProjectileEmitter")
		if actor.weapon_phase == &"windup" and not emitter._pending.is_empty():
			var muzzle: Vector2 = actor.position + Vector2(emitter.profile.muzzle_offset.x*actor.attack_facing,emitter.profile.muzzle_offset.y)
			draw_line(muzzle,to_local(emitter._pending.aim),Color(0.5,0.7,0.7,0.45),1)
