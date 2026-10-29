extends SceneTree
## Real attack and rigid-body outcomes feed blind feedback; no success events
## are injected. Manual actor clocks isolate combat from patrol/input timing.

const PLAYER = preload("res://scenes/actors/player.tscn")
const ENEMY = preload("res://scenes/actors/enemy.tscn")
const CRATE = preload("res://scenes/props/crate.tscn")
const SONAR = preload("res://scenes/sensory/sonar_view.tscn")
var failures: Array[String] = []
var checks := 0
var room: Node2D
var sonar
var bus: Node

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error("FAIL: " + label)
	else:
		print("PASS: ", label)

func frames(count: int = 2) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func fresh_room() -> void:
	if is_instance_valid(sonar): sonar.free()
	if is_instance_valid(room): room.free()
	await frames()
	room = Node2D.new()
	root.add_child(room)
	sonar = SONAR.instantiate()
	root.add_child(sonar)
	sonar.set_process(false)
	sonar.set_blind(true)
	sonar.bind_level(room, null)
	bus.clear_history()

func actor(scene: PackedScene, at: Vector2, manual: bool = true) -> Node2D:
	var body = scene.instantiate()
	body.position = at
	room.add_child(body)
	body.set_physics_process(not manual)
	var strike := body.get_node_or_null("StrikeComponent")
	if strike != null: strike.set_physics_process(false)
	return body

func terrain(at: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	room.add_child(body)

func reset_events(player: Node2D = null) -> void:
	bus.clear_history()
	sonar.bind_level(room, player)

func pulses(kind: StringName, source_id: int = 0) -> Array:
	return sonar.pulses.filter(func(pulse): return pulse.kind == kind and (source_id == 0 or pulse.source_id == source_id))

func events(kind: StringName, source_id: int = 0) -> Array:
	return bus.event_history.filter(func(event): return event.kind == kind and (source_id == 0 or event.source_id == source_id))

func mark_count() -> int:
	var result := 0
	for pulse in sonar.pulses:
		if not sonar.contact_mark(pulse).is_empty(): result += 1
	return result

func strike(player: Node2D, combo: int = 1) -> void:
	player.cancel_attack()
	player.hitpause = 0
	player.combo = combo - 1
	player._start_attack()
	var hit_remaining: float = player.tuning.attack_hit_remaining if combo < 3 else player.tuning.finisher_hit_remaining
	player._advance_attack(player.attack_time - hit_remaining + 0.001)

func run() -> void:
	seed(20261003)
	bus = root.get_node("NoiseBus")
	await fresh_room()
	if not sonar.has_method("contact_mark") or not sonar.has_method("origin_label_visible"):
		check(false, "sonar exposes outcome and label selection hooks used by its renderer")
	else:
		await test_real_miss_and_obstruction()
		await test_real_hit_and_expiry()
		await test_lethal_strike_labels()
		await test_nearby_equal_priority_labels()
		await test_real_guard_damage_and_invulnerability()
		await test_real_warning_interruption()
		await test_physical_prop_hit(false)
		await test_physical_prop_hit(true)
		await test_falling_break()
		await test_stationary_prop_silence()
		await test_render_pause_reset_and_bound()
	if is_instance_valid(sonar): sonar.free()
	if is_instance_valid(room): room.free()
	print("BLIND FEEDBACK: %d/%d checks passed" % [checks - failures.size(), checks])
	quit(0 if failures.is_empty() else 1)

func test_real_miss_and_obstruction() -> void:
	await fresh_room()
	var player = actor(PLAYER, Vector2(200, 150))
	var guard = actor(ENEMY, Vector2(320, 150))
	await frames()
	reset_events(player)
	strike(player)
	check(events(&"player_strike").size() == 1 and guard.hp == guard.max_hp, "real missed swing emits strike noise while leaving the distant guard unharmed")
	check(events(&"enemy_damage").is_empty() and mark_count() == 0, "a real miss never invents a successful contact mark")
	player.cancel_attack()
	guard.global_position = Vector2(245, 150)
	terrain(Vector2(222, 125), Vector2(2, 70))
	await frames()
	reset_events(player)
	strike(player)
	check(events(&"player_strike").size() == 1 and guard.hp == guard.max_hp, "terrain-obstructed swing still executes without reaching a guard behind the wall")
	check(events(&"enemy_damage").is_empty() and mark_count() == 0, "blocked melee contact never displays HIT through terrain")

func test_real_hit_and_expiry() -> void:
	await fresh_room()
	var player = actor(PLAYER, Vector2(200, 150))
	var guard = actor(ENEMY, Vector2(245, 150))
	terrain(Vector2(300, 160), Vector2(500, 20))
	await frames()
	reset_events(player)
	var contact_origin: Vector2 = guard.global_position + Vector2(0, -25)
	strike(player)
	var hits := pulses(&"enemy_damage", guard.get_instance_id())
	check(guard.hp == guard.max_hp - 1 and hits.size() == 1, "real active melee contact produces one damage event from the struck guard")
	if hits.is_empty(): return
	var pulse: Dictionary = hits[0]
	var mark: Dictionary = sonar.contact_mark(pulse)
	check(not mark.is_empty() and mark.get("origin") == contact_origin and float(mark.get("alpha", 0.0)) > 0.0, "HIT mark starts at the actual guard damage origin")
	check(sonar._label(pulse.kind) == "HIT" and sonar.origin_label_visible(pulse), "successful strike displays the distinct HIT label")
	var swings := pulses(&"player_strike")
	check(swings.size() == 1 and sonar.contact_mark(swings[0]).is_empty(), "swing intent itself remains separate from confirmed contact feedback")
	player.hitpause = 0
	for i in range(6): player.get_node("StrikeComponent")._physics_process(1.0 / 120.0)
	check(events(&"enemy_damage").size() == 1 and mark_count() == 1, "repeated active-window samples do not duplicate hit feedback")
	player.cancel_attack()
	guard.global_position += Vector2(100, -20)
	sonar.advance_simulation(0.06)
	var faded: Dictionary = sonar.contact_mark(pulse)
	check(not faded.is_empty() and faded.get("origin") == contact_origin, "contact mark remembers emission position after the guard moves")
	check(float(faded.get("alpha", 0.0)) < float(mark.get("alpha", 0.0)) and float(faded.get("alpha", 0.0)) > 0.0, "contact feedback fades instead of following or permanently revealing the guard")
	sonar.advance_simulation(4.0)
	check(sonar.contact_mark(pulse).is_empty() and sonar.pulses.is_empty(), "silence expires both the contact mark and its contour pulse")

func test_lethal_strike_labels() -> void:
	await fresh_room()
	var player = actor(PLAYER, Vector2(200, 150))
	var guard = actor(ENEMY, Vector2(245, 150))
	guard.hp = 2
	terrain(Vector2(300, 160), Vector2(500, 20))
	await frames()
	reset_events(player)
	var guard_id: int = guard.get_instance_id()
	var death_origin: Vector2 = guard.global_position + Vector2(0, -20)
	strike(player, 3)
	var hits := pulses(&"enemy_damage", guard_id)
	var deaths := pulses(&"enemy_death", guard_id)
	check(guard.is_queued_for_deletion() and hits.size() == 1 and deaths.size() == 1, "lethal real finisher records damage and death before its queued source is freed")
	if hits.is_empty() or deaths.is_empty(): return
	var hit: Dictionary = hits[0]
	var down: Dictionary = deaths[0]
	check(sonar._label(down.kind) == "DOWN" and sonar.origin_label_visible(down) and not sonar.origin_label_visible(hit), "close simultaneous damage and death labels resolve to DOWN")
	check(not hit.tracks.is_empty() and not down.tracks.is_empty() and pulses(&"enemy_damage").size() == 1 and pulses(&"enemy_death").size() == 1, "label priority preserves both independent travelling contour waves")
	await frames()
	check(not is_instance_valid(guard), "lethal fixture actually frees the dead guard")
	var mark: Dictionary = sonar.contact_mark(down)
	check(not mark.is_empty() and mark.get("origin") == death_origin and float(mark.get("alpha", 0.0)) > 0.0, "recorded DOWN feedback survives source deletion at the real death origin")
	sonar.advance_simulation(4.0)
	check(sonar.contact_mark(down).is_empty() and not sonar.origin_label_visible(down), "DOWN and its label expire even after their source has disappeared")

func test_nearby_equal_priority_labels() -> void:
	await fresh_room()
	var player = actor(PLAYER, Vector2(200, 150))
	var first = actor(ENEMY, Vector2(245, 150))
	var second = actor(ENEMY, Vector2(251, 150))
	await frames()
	reset_events(player)
	strike(player)
	var hits := pulses(&"enemy_damage")
	check(first.hp == first.max_hp - 1 and second.hp == second.max_hp - 1 and hits.size() == 2, "one real swing can contact two neighboring guards")
	var visible := 0
	for pulse in hits:
		if sonar.origin_label_visible(pulse): visible += 1
	check(visible == 1 and hits.size() == 2, "nearby equal-priority HIT labels stay readable while retaining both damage pulses")

func test_real_guard_damage_and_invulnerability() -> void:
	await fresh_room()
	var player = actor(PLAYER, Vector2(200, 150))
	var guard = actor(ENEMY, Vector2(230, 150))
	terrain(Vector2(300, 160), Vector2(500, 20))
	await frames()
	reset_events(player)
	guard.target = player
	guard.cooldown = 0
	guard._physics_process(0.001)
	for i in range(36): guard._physics_process(0.01)
	var hurts := pulses(&"player_damage", player.get_instance_id())
	check(player.hp == player.max_hp - guard.tuning.attack_damage and hurts.size() == 1, "real guard windup and attack produce player damage")
	if hurts.is_empty(): return
	var hurt: Dictionary = hurts[0]
	var mark: Dictionary = sonar.contact_mark(hurt)
	check(sonar._label(hurt.kind) == "HURT" and not mark.is_empty() and mark.get("origin") == player.global_position + Vector2(0, -24), "incoming damage has distinct HURT feedback at the damaged player's position")
	check(sonar.origin_label_visible(hurt), "HURT remains readable among the guard's nearby draw and strike noises")
	reset_events(player)
	var hp_before: int = player.hp
	guard.windup = 0
	guard.cooldown = 0
	guard._physics_process(0.001)
	for i in range(36): guard._physics_process(0.01)
	check(events(&"enemy_attack").size() == 1 and player.hp == hp_before and player.invuln > 0, "second real guard attack resolves during player invulnerability")
	check(pulses(&"player_damage").is_empty() and mark_count() == 0, "an invulnerable dodge does not fabricate HURT or successful contact feedback")

func test_real_warning_interruption() -> void:
	await fresh_room()
	var player = actor(PLAYER, Vector2(200, 150))
	var guard = actor(ENEMY, Vector2(230, 150))
	await frames()
	reset_events(player)
	guard.target = player
	guard.cooldown = 0
	guard._physics_process(0.001)
	var warnings := pulses(&"enemy_windup", guard.get_instance_id())
	check(warnings.size() == 1 and not sonar.threat_mark(warnings[0]).is_empty(), "real close guard AI emits a directional windup warning")
	if warnings.is_empty(): return
	strike(player)
	check(guard.windup == 0 and events(&"enemy_damage").size() == 1, "real melee damage interrupts the guard's active windup")
	check(sonar.threat_mark(warnings[0]).is_empty() and not sonar.origin_label_visible(warnings[0]) and pulses(&"enemy_windup").size() == 1, "confirmed interrupt retires stale DRAW feedback while preserving its travelling wave")

func test_physical_prop_hit(lethal: bool) -> void:
	await fresh_room()
	terrain(Vector2(700, 350), Vector2(700, 20))
	var player = actor(PLAYER, Vector2(580, 340))
	var guard = actor(ENEMY, Vector2(710, 340))
	guard.hp = 3 if lethal else 9
	var prop = actor(CRATE, Vector2(610, 312), false)
	prop.tuning = prop.tuning.duplicate()
	prop.tuning.launch_lift = 0
	prop.tuning.launch_spin_range = Vector2.ZERO
	prop.tuning.hard_impacts_to_break = 99
	var guard_id: int = guard.get_instance_id()
	var prop_id: int = prop.get_instance_id()
	var damage_origins: Array[Vector2] = []
	var prop_hits: Array[bool] = []
	guard.damaged.connect(func(body, _damage, _direction, prop_hit):
		damage_origins.append(body.global_position + Vector2(0, -25))
		prop_hits.append(prop_hit))
	await frames()
	reset_events(player)
	strike(player)
	check(prop.hit_count == 1 and events(&"enemy_damage").is_empty(), "real melee launches a prop without directly reaching the distant guard (%s)" % ("lethal" if lethal else "nonlethal"))
	player.cancel_attack()
	await frames(65)
	var hits := pulses(&"enemy_damage", guard_id)
	var breaks := pulses(&"prop_break", prop_id)
	check(prop_hits == [true] and hits.size() == 1, "launched rigid-body collision generates exactly one real prop damage event (%s)" % ("lethal" if lethal else "nonlethal"))
	check(not is_instance_valid(prop) and breaks.size() == 1, "consumed physical projectile records exactly one BREAK before deletion (%s)" % ("lethal" if lethal else "nonlethal"))
	if hits.is_empty() or breaks.is_empty(): return
	var hit: Dictionary = hits[0]
	var broken: Dictionary = breaks[0]
	check(not damage_origins.is_empty() and sonar.contact_mark(hit).get("origin") == damage_origins[0], "prop damage feedback uses the collided guard's actual origin (%s)" % ("lethal" if lethal else "nonlethal"))
	check(not sonar.contact_mark(broken).is_empty() and sonar._label(broken.kind) == "BREAK", "physical projectile destruction retains its own BREAK mark (%s)" % ("lethal" if lethal else "nonlethal"))
	if lethal:
		var deaths := pulses(&"enemy_death", guard_id)
		check(not is_instance_valid(guard) and deaths.size() == 1, "physical prop can kill and free its real guard target")
		if deaths.is_empty(): return
		var down: Dictionary = deaths[0]
		check(sonar.origin_label_visible(down) and not sonar.origin_label_visible(hit) and not sonar.origin_label_visible(broken), "nearby lethal prop damage, death and break labels resolve to DOWN across sources")
		check(not hit.tracks.is_empty() and not down.tracks.is_empty() and not broken.tracks.is_empty(), "lethal prop label selection preserves all three independent waves")
	else:
		check(guard.hp == 6 and pulses(&"enemy_death", guard_id).is_empty(), "nonlethal prop damage never invents DOWN")
		check(int(sonar.origin_label_visible(hit)) + int(sonar.origin_label_visible(broken)) == 1, "close physical damage and break labels do not pile up")

func test_falling_break() -> void:
	await fresh_room()
	terrain(Vector2(700, 350), Vector2(500, 20))
	var prop = actor(CRATE, Vector2(700, 180), false)
	prop.tuning = prop.tuning.duplicate()
	prop.tuning.hard_impacts_to_break = 1
	var prop_id: int = prop.get_instance_id()
	var destroy_origins: Array[Vector2] = []
	prop.destroyed.connect(func(body): destroy_origins.append(body.global_position))
	reset_events()
	await frames(100)
	var breaks := pulses(&"prop_break", prop_id)
	check(not is_instance_valid(prop) and breaks.size() == 1 and destroy_origins.size() == 1, "hard real ground impact breaks a falling prop once")
	if breaks.is_empty(): return
	var pulse: Dictionary = breaks[0]
	check(sonar.origin_label_visible(pulse) and sonar._label(pulse.kind) == "BREAK" and sonar.contact_mark(pulse).get("origin") == destroy_origins[0], "isolated physical break visibly identifies the destroyed prop at its recorded origin")

func test_stationary_prop_silence() -> void:
	await fresh_room()
	terrain(Vector2(400, 350), Vector2(700, 20))
	var prop = actor(CRATE, Vector2(400, 325), false)
	prop.tuning = prop.tuning.duplicate()
	prop.tuning.hard_impacts_to_break = 99
	await frames(240)
	check(is_instance_valid(prop) and prop.linear_velocity.length() < 1.0, "physical stationary-prop fixture genuinely settles on terrain")
	reset_events()
	await frames(240)
	check(events(&"prop_impact").is_empty() and events(&"prop_break").is_empty() and mark_count() == 0, "resting contact produces no recurring impact, BREAK or contact-feedback spam")

func test_render_pause_reset_and_bound() -> void:
	await fresh_room()
	root.canvas_transform = Transform2D.IDENTITY
	terrain(Vector2(300, 160), Vector2(500, 20))
	var player = actor(PLAYER, Vector2(200, 150))
	for i in range(24):
		var guard = actor(ENEMY, Vector2(245 + (i % 3) * 2, 150))
		guard.hp = 1
	await frames()
	reset_events(player)
	strike(player)
	player.cancel_attack()
	check(events(&"enemy_damage").size() == 24 and events(&"enemy_death").size() == 24, "noisy overlap fixture consists of 24 actual simultaneous melee defeats")
	check(sonar.pulses.size() == sonar.tuning.max_active_pulses and sonar.dropped_pulse_count == sonar.accepted_event_count - sonar.tuning.max_active_pulses, "dense real contact feedback obeys the shared finite pulse budget")
	await frames()
	sonar.refresh_geometry()
	sonar.advance_simulation(0.06)
	await process_frame
	RenderingServer.force_draw(false)
	var drawn: Dictionary = sonar.debug_snapshot()
	check(drawn.draw_blackout and drawn.draw_proprioception and drawn.draw_contacts > 0 and drawn.draw_contacts <= sonar.pulses.size(), "actual blind draw callback renders bounded contacts above the black cover")
	check(drawn.draw_labels == 1 and drawn.draw_segments > 0 and drawn.draw_segments <= sonar.tuning.max_draw_segments, "noisy actual draw submits one readable DOWN label while retaining bounded travelling contours")
	var remembered: Dictionary = sonar.pulses.back()
	var mark_before: Dictionary = sonar.contact_mark(remembered)
	paused = true
	sonar.advance_simulation(1.0)
	var paused_mark: Dictionary = sonar.contact_mark(remembered)
	check(paused_mark == mark_before, "pause freezes a real post-deletion contact marker's origin and fade")
	paused = false
	sonar.advance_simulation(0.06)
	check(float(sonar.contact_mark(remembered).get("alpha", 0.0)) < float(paused_mark.get("alpha", 0.0)), "resume continues the same real contact marker's finite fade")
	var started := Time.get_ticks_usec()
	for repetition in range(100):
		for pulse in sonar.pulses:
			sonar.contact_mark(pulse)
			sonar.origin_label_visible(pulse)
	var mean_usec := float(Time.get_ticks_usec() - started) / 100.0
	print("BLIND FEEDBACK METRIC: %d-pulse contact/label evaluation %.1f us per pass; CPU instrumentation, not GPU/frame-rate proof" % [sonar.pulses.size(), mean_usec])
	sonar.advance_simulation(1.0)
	await process_frame
	RenderingServer.force_draw(false)
	var expired: Dictionary = sonar.debug_snapshot()
	check(expired.draw_contacts == 0 and expired.draw_labels == 0 and not sonar.pulses.is_empty(), "contact glyphs and labels disappear before the remaining travelling waves finish")
	reset_events(player)
	await process_frame
	RenderingServer.force_draw(false)
	var reset: Dictionary = sonar.debug_snapshot()
	check(reset.pulse_count == 0 and reset.draw_contacts == 0 and reset.draw_labels == 0 and reset.history.is_empty(), "level rebind clears every contact, label, pulse and prior event record")
