extends Node2D
## Composition only: no attack outcomes, teleport loops, perception triggers,
## velocity changes or special-case actor support. R reloads the whole sandbox.
const Probe = preload("res://simulation/components/terrain_probe.gd")
func _ready() -> void:
	$Enemy.configure($Player, get_node("/root/NoiseBus"))
func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F12:
		get_viewport().get_texture().get_image().save_png("res://simulation/evidence/native_footing.png")
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_tree().change_scene_to_file("res://simulation/gym.tscn")
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		get_tree().reload_current_scene()
func _process(_dt: float) -> void:
	var prospective := Probe.obstacle($Enemy, $Enemy.facing, 24, deg_to_rad($Enemy.tuning.max_slope_degrees), $Enemy.collision_mask, $Enemy.terrain_probe_profile)
	$HUD/Status.text = "PC support: %s | NPC support: %s\nProspective NPC terrain: %s" % [
		$Player.grounded, $Enemy.is_on_floor(),
		"Clear" if prospective.is_empty() else prospective]
