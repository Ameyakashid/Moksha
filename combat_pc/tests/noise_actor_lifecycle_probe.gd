extends SceneTree
const PLAYER = preload("res://combat_pc/player.tscn")
var actor: Node
var legacy: Array = []
var receipts: Array = []
var checks := 0
var failures: Array[String] = []
var place := Vector2(120, 80)
var moved := Vector2(700, -300)

func _initialize() -> void:
	_run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _new() -> void:
	if is_instance_valid(actor): actor.free()
	actor = PLAYER.instantiate()
	actor.automatic_physics = false
	actor.position = place
	actor.profile = actor.profile.duplicate(true)
	actor.combat_profile = actor.combat_profile.duplicate(true)
	actor.shield_profile = actor.shield_profile.duplicate(true)
	root.add_child(actor)
	actor.noise_requested.connect(func(origin, kind, loudness, source): legacy.append({"origin":origin,"kind":kind,"loudness":loudness,"source":source}))
	actor.noise_committed.connect(func(event): receipts.append(event))
	legacy.clear()
	receipts.clear()
func _roll() -> void:
	actor.grounded = true
	actor._roll_buffer = 1.0
	actor.set("_input", {"x":0.0})
	actor._try_roll()
func _land(mode := "land") -> void:
	actor.grounded = true
	actor._ground_contact_registered = false
	if mode == "dive":
		actor.main_action = &"dive"
		actor.dive_phase = &"descent"
		actor._dive_start_y = 0.0
	if mode == "hard":
		actor.enable_hard_landing = true
		actor._fall_history_active = true
		actor._fall_apex_y = -800.0
	actor._dispatch_landing(800.0)
func _run() -> void:
	_new()
	actor._commit_noise(place, &"land", 1.25, actor.noise_generation())
	_check(legacy.size() == 1 and receipts.size() == 1, "one legacy and one receipt")
	var first: Dictionary = receipts[0]
	_check(first.size() == 6 and first.is_read_only(), "exact immutable six-field dictionary")
	_check(first.origin == place and first.kind == &"land" and first.loudness == 1.25 and first.actor_id == actor.get_instance_id(), "exact scalar values")
	var old_generation: int = actor.noise_generation()
	actor.reset_actor(moved)
	actor._commit_noise(place, &"land", 1.0, old_generation)
	_check(receipts.size() == 1 and legacy.size() == 1, "old generation suppressed before legacy")
	actor._commit_noise(moved, &"roll", 1.0, actor.noise_generation())
	_check(receipts[1].serial > first.serial and receipts[1].generation > first.generation, "serial monotonic across reset")
	for loudness in [0.0, -1.0, INF, NAN]: actor._commit_noise(place, &"land", loudness, actor.noise_generation())
	actor._commit_noise(Vector2(INF, 1), &"land", 1.0, actor.noise_generation())
	_check(receipts.size() == 2 and legacy.size() == 7, "invalid receipt filtered while preserving legacy callback")
	_new()
	actor.noise_requested.connect(func(_a, _b, _c, _d): actor.reset_actor(moved))
	actor._commit_noise(place, &"roll", 1.0, actor.noise_generation())
	_check(legacy.size() == 1 and receipts.is_empty(), "legacy reset rejects stale receipt")
	_new()
	actor.noise_requested.connect(func(_a, _b, _c, _d): actor.global_position = moved)
	actor._commit_noise(place, &"roll", 1.0, actor.noise_generation())
	_check(receipts.size() == 1 and receipts[0].origin == place and actor.global_position == moved, "legacy teleport preserves admitted origin")
	_new()
	actor.noise_requested.connect(func(_a, _b, _c, _d): actor.queue_free())
	actor._commit_noise(place, &"roll", 1.0, actor.noise_generation())
	_check(legacy.size() == 1 and receipts.is_empty(), "queued owner suppresses receipt")
	_new()
	actor.apply_hitpause(0.5)
	actor._commit_noise(place, &"guard", 1.0, actor.noise_generation())
	_check(receipts.size() == 1, "genuine event is allowed during local pause")
	for event in [&"roll_started", &"crouch_enter"]:
		_new()
		actor.movement_event.connect(func(name_, _payload):
			if name_ == event: actor.reset_actor(moved))
		_roll()
		_check(legacy.is_empty() and receipts.is_empty() and actor.main_action == &"locomotion" and actor.roll_phase == &"", "roll reset fence " + String(event))
	_new()
	actor.action_changed.connect(func(_previous, current):
		if current == &"roll": actor.reset_actor(moved))
	_roll()
	_check(legacy.is_empty() and receipts.is_empty() and actor.main_action == &"locomotion" and actor.roll_phase == &"", "roll action reset leaves fresh lifecycle intact")
	_new()
	var roll_loudness: float = actor.combat_profile.roll_loudness
	actor.movement_event.connect(func(name_, _payload):
		if name_ == &"roll_started":
			actor.global_position = moved
			actor.combat_profile.roll_loudness = 99.0)
	_roll()
	_check(receipts.size() == 1 and receipts[0].origin == place and receipts[0].loudness == roll_loudness, "roll captures origin and loudness before callback")
	for event in [&"landed", &"dive_impact", &"dive_phase_changed", &"hard_land_started", &"hard_land_phase_changed"]:
		_new()
		actor.movement_event.connect(func(name_, _payload):
			if name_ == event: actor.reset_actor(moved))
		_land("dive" if event in [&"dive_impact", &"dive_phase_changed"] else ("hard" if String(event).begins_with("hard") else "land"))
		_check(legacy.is_empty() and receipts.is_empty() and actor.global_position == moved, "landing reset fence " + String(event))
	for mode in ["land", "dive", "hard"]:
		_new()
		actor.movement_event.connect(func(name_, _payload):
			if name_ == &"landed":
				actor.global_position = moved
				actor._dive_impacted_this_tick = false)
		_land(mode)
		var expected_kind: StringName = {"land":&"land", "dive":&"dive_impact", "hard":&"hard_land"}[mode]
		_check(receipts.size() == 1 and receipts[0].origin == place and receipts[0].kind == expected_kind, "landing captured kind and origin " + mode)
	_new()
	var hurt_loudness: float = actor.combat_profile.hurt_loudness
	actor.movement_event.connect(func(name_, _payload):
		if name_ == &"hurt_started":
			actor.global_position = moved
			actor.combat_profile.hurt_loudness = 99.0)
	actor.receive_hit({"amount":1.0,"hitpause":0.0})
	_check(receipts.size() == 1 and receipts[0].origin == place and receipts[0].loudness == hurt_loudness, "hurt captures admitted origin and loudness")
	print("ACTOR_NOISE_PROBE: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures: printerr(failure)
	if is_instance_valid(actor): actor.free()
	quit(0 if failures.is_empty() else 1)
