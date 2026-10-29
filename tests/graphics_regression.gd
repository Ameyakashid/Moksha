extends SceneTree
## Presentation invariants and a real landing; controller gameplay regressions
## remain in actors_regression.gd. Run with --headless --fixed-fps 120.

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1
	print("PASS: " if condition else "FAIL: ", label)

func run() -> void:
	var player = load("res://scenes/actors/player.tscn").instantiate()
	root.add_child(player)
	player.input_enabled = false
	player.set_physics_process(false)
	var graphics = player.graphics
	graphics.set_process(false)
	var sprite: AnimatedSprite2D = graphics.sprite
	var weapon: Node2D = graphics.weapon
	var original_body: Transform2D = player.transform
	var original_collision: Transform2D = player.get_node("CollisionShape2D").transform
	var scale_y: float = graphics._sprite_scale.y
	for direction in [-1, 1]:
		for state in [&"idle", &"run", &"jump", &"fall", &"hurt", &"dash", &"attack_1"]:
			graphics.present(state, direction)
			graphics.present_combat(0.25 if state == &"attack_1" else -1.0, 1, state == &"dash", Vector2.ZERO, false)
			graphics._process(0.06)
			var foot_left: Vector2 = sprite.transform * Vector2(-40, 0)
			var foot_right: Vector2 = sprite.transform * Vector2(40, 0)
			check(is_zero_approx(foot_left.y) and is_zero_approx(foot_right.y) and sprite.position.is_zero_approx(), "%s facing %d keeps the foot origin/line fixed" % [state, direction])
	check(player.transform == original_body and player.get_node("CollisionShape2D").transform == original_collision, "procedural poses never move the actor or collision")
	for combo in [1, 2, 3]:
		var duration: float = player.tuning.finisher_seconds if combo == 3 else player.tuning.attack_seconds
		var remaining: float = player.tuning.finisher_hit_remaining if combo == 3 else player.tuning.attack_hit_remaining
		var contact := 1.0 - remaining / duration
		for direction in [-1, 1]:
			graphics.present(StringName("attack_%d" % combo), direction)
			graphics.present_combat(contact, combo, false, Vector2.ZERO, false)
			var reach: Vector2 = graphics.weapon_tip() - weapon.global_position
			check(reach.x * direction > 30.0 and absf(reach.y) < 0.01, "combo %d faces its contact forward at controller hit time (%d)" % [combo, direction])
			graphics.present_combat(0.99999, combo, false, Vector2.ZERO, false)
			check(absf(weapon.rotation - graphics.REST_ANGLE * direction) < 0.001 and is_zero_approx(weapon._sweep), "combo %d returns to a quiet carry at recovery (%d)" % [combo, direction])
	graphics.present(&"attack_1", 1)
	graphics.present_combat(0.22, 1, false, Vector2.ZERO, false)
	check(absf(weapon._sweep) > 0.0, "moving attack has a restrained sweep")
	graphics.present(&"dash", 1)
	graphics.present_combat(-1.0, 1, true, Vector2.ZERO, false)
	check(is_zero_approx(weapon._sweep), "interrupting a swing clears its sweep immediately")
	graphics._state_seconds = player.tuning.dash_seconds * 0.5
	graphics._process(0.0)
	check(sprite.animation == &"fall" and sprite.transform.y.y < scale_y * 0.8, "roll visibly tucks the existing bent-knee pose")
	graphics.present(&"dash", 1, false)
	var frozen: Transform2D = sprite.transform
	var frozen_weapon: Transform2D = weapon.transform
	var frozen_time: float = graphics._state_seconds
	graphics._process(0.25)
	check(sprite.transform == frozen and weapon.transform == frozen_weapon and graphics._state_seconds == frozen_time and sprite.speed_scale == 0.0, "local hitpause/simulation pause freezes procedural motion and frame cycles")
	graphics.present(&"run", 1)
	player.velocity.x = player.tuning.move_speed * 1.25
	graphics.present(&"run", 1)
	check(is_equal_approx(sprite.speed_scale, 1.25), "sight speed reward also increases the run cycle rate")
	graphics.present(&"tap", -1)
	graphics.present_combat(-1.0, 0, false, Vector2(-30, -4), true)
	var to_contact: Vector2 = Vector2(-30, -4) - weapon.global_position
	var to_tip: Vector2 = graphics.weapon_tip() - weapon.global_position
	check(to_contact.normalized().dot(to_tip.normalized()) > 0.9999, "mirrored tap still aims at the actual contact")
	graphics.present(&"death", 1)
	check(not weapon.visible, "death hides the separate weapon")
	graphics.present(&"idle", 1, true, false)
	check(not weapon.visible and not sprite.visible, "damage blink hides the body and weapon together")
	for path in ["res://scenes/actors/enemy.tscn", "res://scenes/actors/elite_enemy.tscn"]:
		var guard = load(path).instantiate()
		root.add_child(guard)
		guard.set_physics_process(false)
		guard.graphics.set_process(false)
		guard.velocity.x = guard.tuning.move_speed * 0.5
		guard.graphics.present(&"walk", -1)
		check(is_equal_approx(guard.graphics.sprite.speed_scale, guard.tuning.move_speed * 0.5 / 42.0), "%s walk rate follows actual speed" % guard.name)
		guard.graphics.present(&"windup", -1)
		guard.graphics._process(0.2)
		guard.graphics.present_status(guard.hp, guard.max_hp, true, true)
		check(guard.graphics.telegraph.visible and guard.graphics.telegraph.rotation == 0.0 and guard.graphics.sprite.position.is_zero_approx(), "%s windup keeps UI upright and feet anchored" % guard.name)
		guard.queue_free()
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(0, 90)
	var floor_collision := CollisionShape2D.new()
	var floor_shape := RectangleShape2D.new()
	floor_shape.size = Vector2(300, 20)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	root.add_child(floor_body)
	player.position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.set_physics_process(true)
	graphics.set_process(true)
	var settled := false
	for frame in range(100):
		await physics_frame
		await process_frame
		if player.is_on_floor():
			settled = graphics._landing_remaining > 0.0 and sprite.transform.y.y < scale_y
			break
	check(settled, "a real fall onto a floor triggers the landing compression")
	for frame in range(30):
		await physics_frame
		await process_frame
	check(is_zero_approx(graphics._landing_remaining) and is_equal_approx(sprite.transform.y.y, scale_y), "landing settle recovers fully without a residual scale")
	print("GRAPHICS REGRESSION: %d/%d passed" % [checks - failures, checks])
	quit(1 if failures else 0)
