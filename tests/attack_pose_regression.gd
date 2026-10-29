extends SceneTree
## Drawn attack presentation must follow the existing controller contact windows.
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS: " if ok else "FAIL: ",label)
func run() -> void:
	var player = load("res://scenes/actors/player.tscn").instantiate()
	root.add_child(player)
	player.input_enabled = false
	player.set_physics_process(false)
	var graphics = player.graphics
	graphics.set_process(false)
	var profile = graphics.attack_pose
	check(profile != null and profile.is_usable(),"player prefab owns a replaceable valid attack art profile")
	if profile == null or not profile.is_usable():
		quit(1)
		return
	var original_body: Transform2D = player.transform
	var original_collision: Transform2D = player.get_node("CollisionShape2D").transform
	var base_offset: Vector2 = graphics.sprite.offset
	var base_frames: SpriteFrames = graphics.sprite.sprite_frames
	var speed: float = player.tuning.move_speed
	for combo in [1,2,3]:
		var duration: float = player.tuning.finisher_seconds if combo == 3 else player.tuning.attack_seconds
		var hit_remaining: float = player.tuning.finisher_hit_remaining if combo == 3 else player.tuning.attack_hit_remaining
		var contact := 1.0-hit_remaining/duration
		var end: float = contact+player.tuning.attack_active_seconds/duration
		for direction in [-1,1]:
			graphics.present(StringName("attack_%d" % combo),direction)
			graphics.present_combat(contact-0.001,combo,false,Vector2.ZERO,false)
			check(graphics.sprite.frame < profile.contact_frame,"combo %d/%d anticipation precedes hit time" % [combo,direction])
			graphics.present_combat(contact,combo,false,Vector2.ZERO,false)
			check(graphics.sprite.frame == profile.contact_frame,"combo %d/%d contact drawing starts at actual hit time" % [combo,direction])
			check(graphics.sprite.sprite_frames == profile.frames and graphics.sprite.offset == -profile.foot_origin,"drawn pose uses its own resource and source foot pivot")
			var hand: Vector2 = graphics.sprite.transform * profile.hand_anchors[graphics.sprite.frame]
			check(graphics.weapon.position.distance_to(hand) < 0.001,"separate baton stays on the measured contact grip")
			var tip: Vector2 = graphics.weapon_tip()-graphics.weapon.global_position
			check(tip.x*direction > 30 and absf(tip.y) < 0.001,"contact baton still points into the unchanged forward hitbox")
			graphics.present_combat(end+0.001,combo,false,Vector2.ZERO,false)
			check(graphics.sprite.frame >= profile.recovery_frame,"body recovery starts after active hit window")
			graphics.present(StringName("attack_%d" % combo),direction,false)
			var frame: int = graphics.sprite.frame
			graphics._process(0.3)
			check(graphics.sprite.frame == frame and is_zero_approx(graphics.sprite.speed_scale),"hitpause does not advance drawn attack frames")
	for state in [&"dash",&"hurt",&"idle",&"run",&"jump"]:
		graphics.present(state,1)
		graphics.present_combat(-1,1,state==&"dash",Vector2.ZERO,false)
		check(graphics.sprite.sprite_frames == base_frames and graphics.sprite.offset == base_offset,"%s interruption restores original locomotion art and pivot" % state)
	check(player.transform == original_body and player.get_node("CollisionShape2D").transform == original_collision,"art swap never alters character or collider transform")
	check(player.tuning.move_speed == speed and player.tuning.attack_seconds == 0.19 and player.tuning.finisher_seconds == 0.26,"original movement and combo timing remain unchanged")
	graphics.attack_pose = null
	graphics.present(&"attack_1",1)
	graphics.present_combat(0.25,1,false,Vector2.ZERO,false)
	check(graphics.sprite.sprite_frames == base_frames and graphics.sprite.animation == &"ready","removing optional profile cleanly restores reusable ready-pose fallback")
	player.free()
	print("ATTACK ART REGRESSION: %d/%d passed" % [checks-failures,checks])
	quit(1 if failures else 0)
