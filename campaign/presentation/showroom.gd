extends Node2D
## Isolated art review only; no gameplay, noise bus interaction, saves or collision.
const Scenery = preload("res://campaign/presentation/campaign_scenery.tscn")
var paint: Node2D
var level := 1
var sight := true
var camera: Camera2D
var label: Label
func _ready() -> void:
	paint = Scenery.instantiate()
	add_child(paint)
	camera = Camera2D.new()
	camera.position = Vector2(320,150)
	add_child(camera)
	var operative = preload("res://assets/characters/operative_art.tscn").instantiate()
	operative.position = Vector2(150,300)
	add_child(operative)
	var guard = preload("res://assets/characters/guard_art.tscn").instantiate()
	guard.position = Vector2(430,300)
	add_child(guard)
	var ui := CanvasLayer.new()
	add_child(ui)
	label = Label.new()
	label.position = Vector2(12,12)
	label.add_theme_font_size_override("font_size",12)
	ui.add_child(label)
	select_theme(1)
func select_theme(value: int) -> void:
	level = value
	paint.configure_sector({"id":"review","level":level,"width":2400,"top":-80,"platforms":[Rect2(240,220,130,16),Rect2(550,180,130,100),Rect2(810,130,190,16)],"gaps":[Vector2(1080,1160)]})
	paint.set_sight_enabled(sight)
	label.text = "ART REVIEW · %s\n1–5 themes / B scenery sight gate / arrows pan / F12 screenshot" % paint.backdrop.theme.title
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	if event.keycode >= KEY_1 and event.keycode <= KEY_5:select_theme(event.keycode-KEY_1+1)
	elif event.keycode == KEY_B:
		sight = not sight
		paint.set_sight_enabled(sight)
	elif event.keycode == KEY_F12:
		var result := get_viewport().get_texture().get_image().save_png("user://campaign_theme_%d.png"%level)
		print("Screenshot result: ",result," path: ",ProjectSettings.globalize_path("user://campaign_theme_%d.png"%level))
func _process(dt: float) -> void:
	camera.position.x = clampf(camera.position.x+(float(Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_LEFT)))*dt*280,320,2080)
