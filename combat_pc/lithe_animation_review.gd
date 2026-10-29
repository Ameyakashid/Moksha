extends Node2D
## Isolated A/B presentation review. Both enlarged views observe ONE real PC.
const Player = preload("res://combat_pc/player.tscn")
const Original = preload("res://combat_pc/visuals/wireframe.gd")
const Lithe = preload("res://combat_pc/visuals/lithe_wireframe.gd")
var actor: Node2D
var baseline: Node2D
var refined: Node2D
var elapsed := 0.0
var demo := true
var capture := false
var captured := {}
var font: Font

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("081218"))
	font = ThemeDB.fallback_font
	capture = "--lithe-capture" in OS.get_cmdline_user_args()
	var floor := StaticBody2D.new()
	floor.position = Vector2(320, 325)
	floor.collision_layer = 1
	floor.collision_mask = 0
	var collider := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(2000, 20)
	collider.shape = rectangle
	floor.add_child(collider)
	add_child(floor)
	actor = Player.instantiate()
	actor.name = "LivePlayer"
	actor.automatic_physics = false
	actor.position = Vector2(100, 315)
	actor.profile = load("res://combat_pc/resources/air_response_agile.tres")
	actor.melee_chain = load("res://combat_pc/resources/responsive_chain.tres")
	actor.get_node("Visual").set_script(Lithe)
	actor.get_node("Visual").ground_presentation = load("res://combat_pc/resources/ground_presentation_agile.tres")
	add_child(actor)
	baseline = Original.new()
	refined = Lithe.new()
	baseline.position = Vector2(185, 212)
	refined.position = Vector2(455, 212)
	baseline.scale = Vector2(3.4, 3.4)
	refined.scale = Vector2(3.4, 3.4)
	add_child(baseline)
	add_child(refined)
	actor.movement_event.connect(baseline.event)
	actor.movement_event.connect(refined.event)

func _physics_process(dt: float) -> void:
	var previous := elapsed
	elapsed += dt
	if demo:
		var frame := {"right": 1.0 if elapsed < 1.6 else 0.0, "left": 1.0 if elapsed > 2.2 and elapsed < 2.8 else 0.0}
		frame["jump_pressed"] = previous < 1.0 and elapsed >= 1.0
		frame["jump"] = elapsed >= 1.0 and elapsed < 1.28
		frame["jump_released"] = previous < 1.28 and elapsed >= 1.28
		frame["roll_pressed"] = previous < 2.8 and elapsed >= 2.8
		frame["attack_pressed"] = (previous < 4.0 and elapsed >= 4.0) or (previous < 4.5 and elapsed >= 4.5) or (previous < 5.0 and elapsed >= 5.0)
		actor.physics_tick(dt, frame)
	else:
		actor.physics_tick(dt)
	var telemetry: Dictionary = actor.telemetry()
	baseline.present(dt, telemetry)
	refined.present(dt, telemetry)
	if capture:
		for row in [[0.4, "run"], [1.14, "jump"], [2.98, "roll"], [4.12, "melee"]]:
			if elapsed >= row[0] and not captured.has(row[1]):
				captured[row[1]] = true
				_capture_frame.call_deferred(str(row[1]))
		if elapsed > 5.4:
			get_tree().quit()
	elif elapsed > 6.5 or actor.position.y > 700 or actor.position.x < -100 or actor.position.x > 750:
		_reset()
	queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.physical_keycode == KEY_R:
		demo = true
		_reset()
	elif event.physical_keycode == KEY_G:
		refined.show_contact_marks = not refined.show_contact_marks
		baseline.show_contact_marks = refined.show_contact_marks
	elif event.physical_keycode in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_J, KEY_K, KEY_SHIFT]:
		demo = false

func _reset() -> void:
	actor.reset_actor(Vector2(100, 315))
	baseline.reset_presentation()
	refined.reset_presentation()
	elapsed = 0.0

func _capture_frame(label: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "res://combat_pc/tests/lithe_review_"+label+".png"
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("LITHE_CAPTURE ", label, " ", result)

func _draw() -> void:
	if font == null:
		return
	var bright := Color("dceceb")
	var muted := Color("78919c")
	draw_string(font, Vector2(24, 29), "MOKSHA / CONNECTED MOTION", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, bright)
	draw_string(font, Vector2(24, 50), "One real controller. Two replaceable views. Original authored animation.", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, muted)
	draw_line(Vector2(320, 73), Vector2(320, 230), Color("253940"), 1)
	draw_string(font, Vector2(87, 80), "ORIGINAL BASELINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, muted)
	draw_string(font, Vector2(379, 80), "LITHE / CONNECTED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, bright)
	for x in [185, 455]:
		draw_line(Vector2(x-95, 212), Vector2(x+95, 212), Color("354e55"), 1)
	draw_line(Vector2(24, 315), Vector2(616, 315), Color("4a666d"), 1)
	draw_string(font, Vector2(24, 249), "LIVE ACTOR  /  " + ("AUTOMATIC REEL" if demo else "YOUR INPUT"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, muted)
	if is_instance_valid(refined):
		draw_string(font, Vector2(375, 249), refined.pose_name.to_upper().replace("_", " "), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, bright)
	draw_string(font, Vector2(24, 342), "A/D move   Space jump   Shift roll   J melee   K shield   G feet   R replay", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, muted)
