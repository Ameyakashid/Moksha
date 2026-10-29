extends Control
## Stage selector only. Each stage is independently editable and runnable.
func _ready() -> void:
	$Footing.pressed.connect(func(): get_tree().change_scene_to_file("res://simulation/footing_sandbox.tscn"))
	$Hearing.pressed.connect(func(): get_tree().change_scene_to_file("res://simulation/hearing_sandbox.tscn"))

	$Impact.pressed.connect(func(): get_tree().change_scene_to_file("res://simulation/impact_sandbox.tscn"))

	$Movement.pressed.connect(func(): get_tree().change_scene_to_file("res://simulation/movement_sandbox.tscn"))

	$Strike.pressed.connect(func(): get_tree().change_scene_to_file("res://simulation/strike_sandbox.tscn"))

	$Projectile.pressed.connect(func(): get_tree().change_scene_to_file("res://simulation/projectile_sandbox.tscn"))

	$Bracing.pressed.connect(func(): get_tree().change_scene_to_file("res://simulation/bracing_sandbox.tscn"))

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F12:
		get_viewport().get_texture().get_image().save_png("res://simulation/evidence/native_gym.png")
