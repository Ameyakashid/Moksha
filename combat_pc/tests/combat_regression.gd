extends SceneTree
## Independent real-physics acceptance for original MOKSHA roll/melee tuning.
## The pinned Dead Cells audit supplies interface intent, not these values.
const PLAYER = preload("res://combat_pc/player.tscn")
const SURFACE = preload("res://combat_pc/fixtures/test_surface.tscn")
const TARGET = preload("res://combat_pc/fixtures/contact_target.tscn")
const CONTACT = preload("res://combat_pc/components/contact_adapter.gd")
const CRATE = preload("res://scenes/props/crate.tscn")

class PhysicsDriver extends Node:
	var actor: Node
	var frame: Variant = {}
	var ticks := 0
	var enabled := true
	func _physics_process(delta: float) -> void:
		if enabled and is_instance_valid(actor):
			if not actor.automatic_physics: actor.physics_tick(delta, frame)
			ticks += 1

var world: Node2D
var actor: Node
var driver: PhysicsDriver
var contact: Node
var hz := 120
var dt := 1.0 / 120.0
var checks := 0
var failures: Array[String] = []
var scenarios: Array[Dictionary] = []
var name_ := ""
var frames: Array[Dictionary] = []
var assertions: Array[Dictionary] = []
var events: Array[Dictionary] = []
var strikes: Array[Dictionary] = []
var measurements := {}
var start_failures := 0
var start_checks := 0
var starting_hashes := {}
var production_paths: Array[String] = [
	"res://combat_pc/player.gd", "res://combat_pc/player.tscn",
	"res://combat_pc/resources/movement_profile.gd", "res://combat_pc/resources/movement_profile.tres",
	"res://combat_pc/resources/combat_profile.gd", "res://combat_pc/resources/combat_profile.tres",
	"res://combat_pc/components/contact_adapter.gd", "res://combat_pc/fixtures/contact_target.gd", "res://combat_pc/fixtures/contact_target.tscn",
	"res://combat_pc/fixtures/test_surface.gd", "res://combat_pc/fixtures/test_surface.tscn",
	"res://scenes/props/crate.tscn", "res://prop.gd", "res://resources/tuning/prop_tuning.gd", "res://resources/tuning/crate_default.tres"
]

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): hz = int(argument.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	dt = 1.0 / hz
	_run.call_deferred()

func _run() -> void:
	for path in production_paths: starting_hashes[path] = FileAccess.get_sha256(path)
	await _combat_cases()
	var hashes := {}
	for path in production_paths: hashes[path] = FileAccess.get_sha256(path)
	hashes["res://combat_pc/tests/combat_regression.gd"] = FileAccess.get_sha256("res://combat_pc/tests/combat_regression.gd")
	var stable := true
	for path in starting_hashes: stable = stable and starting_hashes[path] == hashes[path]
	if not stable: failures.append("Production files changed during run; final rerun required")
	var report := {
		"milestone": 2, "physics_hz": hz, "checks": checks, "failures": failures,
		"scenarios": scenarios, "engine": Engine.get_version_info(),
		"generated_utc": Time.get_datetime_string_from_system(true),
		"production_hash_stable_during_run": stable, "starting_hashes": starting_hashes, "hashes": hashes,
		"execution": "Actual Godot physics callbacks, production actor sweeps and space queries; runtime-only 60/120 Hz overrides",
		"numeric_source": "Original MOKSHA combat/movement profiles; no recovered Dead Cells constants",
		"movement_profile": _resource_values(load("res://combat_pc/resources/movement_profile.tres")),
		"combat_profile": _resource_values(load("res://combat_pc/resources/combat_profile.tres")),
		"limits": ["Headless physical acceptance; native presentation review is separate", "No Dead Cells executable or exact-tuning parity claim"]
	}
	FileAccess.open("res://combat_pc/tests/combat_results_%dhz.json" % hz, FileAccess.WRITE).store_string(JSON.stringify(_safe(report), "  "))
	print("MOKSHA COMBAT %dHz: %d scenarios, %d checks, %d failures" % [hz, scenarios.size(), checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)

func _combat_cases() -> void:
	await _roll_geometry()
	await _roll_budget_and_cancels()
	await _melee_phases()
	await _melee_cancellations()
	await _contact_routing()
	await _hitpause_input()
	await _damage_and_reset()
	await _native_combat_input()
	await _extra_combat_edges()

func _begin(label: String, at := Vector2(100, 200), floor_present := true) -> void:
	name_ = label; frames = []; assertions = []; events = []; strikes = []; measurements = {}
	start_failures = failures.size(); start_checks = checks
	world = Node2D.new(); root.add_child(world)
	if floor_present: _surface(Vector2(-1000, 200), Vector2(3000, 40))
	actor = PLAYER.instantiate(); actor.position = at; actor.automatic_physics = false
	actor.profile = actor.profile.duplicate(true); actor.combat_profile = actor.combat_profile.duplicate(true)
	world.add_child(actor)
	actor.movement_event.connect(func(event_name: StringName, payload: Dictionary):
		events.append({"event": String(event_name), "tick": driver.ticks if is_instance_valid(driver) else 0, "data": _safe(payload)}))
	if actor.has_signal("strike_sample"):
		actor.strike_sample.connect(func(_source: Node, snapshot: Dictionary):
			strikes.append({"tick": driver.ticks if is_instance_valid(driver) else 0, "sample": _safe(snapshot)}))
	contact = actor.get_node("ContactAdapter")
	driver = PhysicsDriver.new(); driver.actor = actor; driver.process_physics_priority = 20; world.add_child(driver)
	await _step({}, 2)

func _surface(at: Vector2, size: Vector2, one_way := false) -> Node:
	var body = SURFACE.instantiate(); body.position = at; body.size = size; body.one_way = one_way; world.add_child(body)
	return body

func _target(at: Vector2, size := Vector2(16, 30)) -> Node:
	var target = TARGET.instantiate(); target.position = at; target.size = size; world.add_child(target)
	return target

func _until(predicate: Callable, frame: Variant = {}, maximum_seconds := 2.0) -> bool:
	for _i in range(ceili(maximum_seconds / dt)):
		if bool(predicate.call()): return true
		await _step(frame)
	return bool(predicate.call())

func _step(frame: Variant = {}, count := 1) -> void:
	driver.frame = frame
	for _i in count:
		var target = driver.ticks + 1
		while driver.ticks < target:
			await physics_frame
			await process_frame
		var snapshot: Dictionary = actor.telemetry()
		snapshot["tick"] = driver.ticks; snapshot["input"] = _safe(frame)
		frames.append(_safe(snapshot))

func _seconds(frame: Variant, seconds: float) -> void:
	await _step(frame, maxi(1, ceili(seconds / dt)))

func _finish() -> void:
	scenarios.append({"name": name_, "checks": checks - start_checks, "failures": failures.size() - start_failures,
		"assertions": assertions, "measurements": measurements, "events": events, "strikes": strikes, "frames": frames})
	driver.enabled = false; world.queue_free()
	await physics_frame
	await process_frame
	world = null; actor = null; driver = null; contact = null

func _check(value: bool, label: String) -> void:
	checks += 1; assertions.append({"passed": value, "label": label})
	if not value:
		failures.append(name_ + ": " + label); printerr("FAIL: " + failures.back())

func _near(value: float, expected: float, tolerance: float, label: String) -> void:
	_check(absf(value - expected) <= tolerance, "%s actual %.6f expected %.6f ± %.6f" % [label, value, expected, tolerance])

func _count(event_name: String) -> int:
	var count := 0
	for event in events:
		if event.event == event_name: count += 1
	return count

func _safe(value: Variant) -> Variant:
	if value is Vector2: return [value.x, value.y]
	if value is Array:
		var result := []
		for item in value: result.append(_safe(item))
		return result
	if value is Dictionary:
		var result := {}
		for key in value: result[str(key)] = _safe(value[key])
		return result
	if value is Object: return str(value)
	return value

func _resource_values(resource: Resource) -> Dictionary:
	var values := {}
	for property in resource.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: values[property.name] = _safe(resource.get(property.name))
	return values

func _solid_overlap() -> bool:
	var query = PhysicsShapeQueryParameters2D.new(); var shape = RectangleShape2D.new()
	shape.size = Vector2(actor.profile.body_width - 0.12, actor.body_height - 0.12)
	query.shape = shape; query.transform = Transform2D(0, actor.global_position + Vector2(0, -actor.body_height * .5))
	query.collision_mask = 1; query.exclude = [actor.get_rid()]
	return not actor.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _direction(direction: int, extra: Dictionary = {}) -> Dictionary:
	return ({"right": 1.0} if direction > 0 else {"left": 1.0}).merged(extra)

func _roll_duration() -> float:
	var p = actor.combat_profile
	return p.roll_start_seconds + p.roll_travel_seconds + p.roll_recovery_seconds

func _roll_time() -> float:
	return float(actor.telemetry().roll_progress) * _roll_duration()

func _weapon_time() -> float:
	var p = actor.combat_profile
	var duration: float = p.attack_windup_seconds if actor.weapon_phase == &"windup" else (p.attack_active_seconds if actor.weapon_phase == &"active" else p.attack_recovery_seconds)
	return float(actor.telemetry().weapon_phase_progress) * duration

func _roll_geometry() -> void:
	for direction in [-1, 1]:
		await _begin("roll phases and held input %d" % direction)
		var start: Vector2 = actor.global_position
		await _step(_direction(direction, {"roll": true}))
		_check(actor.main_action == &"roll" and actor.roll_direction == direction and actor.crouched, "fresh directional edge starts small horizontal roll")
		var seen := {}; var roll_ticks := 1; var safe := not _solid_overlap()
		while actor.main_action == &"roll" and roll_ticks < hz * 2:
			seen[String(actor.roll_phase)] = true
			await _step(_direction(-direction, {"roll": true}))
			roll_ticks += 1; safe = safe and not _solid_overlap()
		measurements = {"roll_seconds": (roll_ticks - 1) * dt, "roll_distance": absf(actor.global_position.x - start.x)}
		_check(seen.has("start") and seen.has("travel") and seen.has("recovery"), "observed startup, travel and recovery on actual body")
		_near((roll_ticks - 1) * dt, _roll_duration(), dt + .000001, "roll duration remains authored seconds")
		_check(actor.main_action != &"roll" and not actor.is_roll_invulnerable() and safe, "roll completion clears i-frames and remains collision-safe")
		await _seconds({"roll": true}, actor.combat_profile.roll_cooldown_seconds + dt)
		_check(_count("roll_started") == 1, "held roll never retriggers after cooldown")
		await _step(); await _step({"roll": true})
		_check(actor.main_action == &"roll", "fresh release/repress after cooldown starts a new roll")
		await _finish()
	await _begin("low ceiling roll expiry and clearance")
	var roof = _surface(Vector2(125, 166), Vector2(400, 12)); await _step()
	await _step({"right": 1.0, "roll": true})
	await _seconds({}, _roll_duration() + 3 * dt)
	_check(actor.global_position.x > 140 and actor.main_action != &"roll", "roll enters tunnel and still expires beneath roof")
	_check(actor.crouched and not actor.can_stand() and not actor.is_roll_invulnerable() and not _solid_overlap(), "expiry keeps safe small collider without extending roll protection")
	await _step({"jump": true})
	_check(_count("ground_jump") == 0 and not _solid_overlap(), "jump cannot expand expired roll through ceiling")
	roof.queue_free(); await _step({}, 2)
	_check(not actor.crouched and actor.can_stand(), "standing resumes when actual headroom clears")
	await _finish()
	for direction in [-1, 1]:
		await _begin("high speed roll thin wall %d" % direction)
		actor.combat_profile.roll_start_speed *= 8; actor.combat_profile.roll_end_speed *= 8
		_surface(Vector2(150 if direction > 0 else 46, 30), Vector2(4, 170)); await _step()
		await _step(_direction(direction, {"roll": true})); await _seconds(_direction(direction), _roll_duration() + dt)
		_check(actor.global_position.x <= 150 - actor.profile.body_width * .5 + .15 if direction > 0 else actor.global_position.x >= 50 + actor.profile.body_width * .5 - .15, "eight-times profile speed cannot sweep through four-pixel wall")
		_check(not _solid_overlap() and actor.main_action != &"roll", "blocked roll exits without embedding or sticking in action")
		await _finish()

func _roll_budget_and_cancels() -> void:
	await _begin("air roll preserves finite jump budget", Vector2(100, -200), false)
	actor.velocity.y = -actor.profile.jump_speed
	var jump_budget: int = actor.air_jumps_left
	await _step({"right": 1.0, "roll": true})
	_check(actor.main_action == &"roll" and not actor.air_roll_available and actor.air_jumps_left == jump_budget, "air roll consumes its own allowance without adding or spending an air jump")
	await _seconds({}, actor.combat_profile.roll_cooldown_seconds + _roll_duration())
	await _step({"roll": true})
	_check(actor.main_action != &"roll" and _count("roll_started") == 1, "cooldown alone cannot replenish an airborne roll")
	await _step(); await _step({"jump": true})
	_check(_count("air_jump") == 1 and actor.air_jumps_left == jump_budget - 1, "fresh air jump after roll uses existing finite budget")
	await _finish()
	await _begin("ground roll leaves ledge then lands", Vector2(100, 100), false)
	_surface(Vector2(0, 100), Vector2(115, 30)); _surface(Vector2(0, 260), Vector2(700, 40)); await _step({}, 2)
	await _step({"right": 1.0, "roll": true})
	await _until(func(): return not actor.grounded, {}, .2)
	_check(not actor.grounded and not actor.air_roll_available, "rolling off genuine support consumes airborne allowance")
	await _until(func(): return actor.grounded and actor.global_position.y > 200, {}, 2)
	_check(actor.grounded and actor.air_roll_available and actor.air_jumps_left == actor.profile.air_jump_count, "actual lower floor landing replenishes both budgets")
	await _seconds({}, actor.combat_profile.roll_cooldown_seconds); await _step({"roll": true})
	_check(actor.main_action == &"roll", "new roll becomes available after actual landing and cooldown")
	await _finish()
	for early in [true, false]:
		await _begin("roll jump buffer " + ("expires before cancel" if early else "survives to cancel"))
		await _step({"roll": true})
		if not early: await _until(func(): return _roll_time() >= actor.combat_profile.roll_jump_cancel_after - actor.profile.jump_buffer_seconds * .5, {}, .4)
		await _step({"jump": true})
		_check(actor.main_action == &"roll" and _count("ground_jump") == 0, "jump is denied before authored cancel boundary")
		await _until(func(): return actor.main_action != &"roll", {"jump": true}, .5)
		_check(_count("ground_jump") == (0 if early else 1), "buffer expiration determines whether cancel produces one ground jump")
		_check(not actor.is_roll_invulnerable(), "jump cancel or expiry removes roll protection immediately")
		await _finish()
	await _begin("roll attack cancel and simultaneous priority")
	await _step({"roll": true, "attack": true, "jump": true})
	_check(actor.main_action == &"roll" and actor.weapon_phase == &"idle" and _count("ground_jump") == 0, "eligible simultaneous inputs choose roll before jump and attack")
	await _until(func(): return _roll_time() >= actor.combat_profile.roll_attack_cancel_after, {}, .4)
	await _step({"attack": true})
	_check(actor.main_action != &"roll" and actor.weapon_phase == &"windup" and not actor.is_roll_invulnerable(), "allowed melee interruption ends roll and its protection")
	await _finish()

func _melee_phases() -> void:
	await _begin("melee permissions at phase boundaries")
	var p = actor.combat_profile
	await _step({"right": 1.0, "attack": true})
	_check(actor.weapon_phase == &"windup" and actor.weapon_permissions.can_turn and actor.weapon_permissions.can_jump, "windup allows turning and jump cancellation")
	_near(actor.weapon_permissions.move_scale, p.attack_windup_move_scale, .000001, "windup movement scale comes from profile")
	await _step({"left": 1.0})
	_check(actor.facing == -1 and actor.velocity.x < 0, "real windup input can reverse facing and movement")
	await _until(func(): return actor.weapon_phase == &"active", {"left": 1.0})
	var active_facing: int = actor.facing
	await _step({"right": 1.0, "jump": true})
	_check(actor.weapon_phase == &"active" and actor.facing == active_facing and _count("ground_jump") == 0, "active strike locks facing and denies immediate jump")
	_near(actor.velocity.x, active_facing * p.attack_active_ground_speed, .01, "active motion uses committed authored ground speed")
	await _until(func(): return actor.weapon_phase != &"active", {"right": 1.0, "jump": true})
	_check(actor.weapon_phase == &"idle" and _count("ground_jump") == 1, "live buffered jump cancels at first recovery opportunity")
	var strike_count = strikes.size(); await _seconds({}, p.attack_recovery_seconds)
	_check(strikes.size() == strike_count, "canceled attack emits no later strike samples")
	await _finish()

func _contact_routing() -> void:
	for direction in [-1, 1]:
		await _begin("close forward target overlaps actor origin %d" % direction)
		actor.facing = direction
		var close = _target(Vector2(100 + direction * 4, 200)); await _step({}, 2)
		await _step({"attack": true}); await _until(func(): return actor.weapon_phase == &"idle")
		_check(close.hits == 1, "target with forward strike overlap is hittable even when its hurtbox also overlaps attack origin")
		await _finish()
	for direction in [-1, 1]:
		await _begin("actual contact dedup and facing %d" % direction)
		actor.facing = direction
		var front = _target(Vector2(100 + direction * 29, 200))
		var second = _target(Vector2(100 + direction * 34, 196))
		var behind = _target(Vector2(100 - direction * 22, 200))
		await _step({}, 2); await _step({"attack": true})
		await _until(func(): return actor.weapon_phase == &"idle", {"attack": true})
		_check(front.hits == 1 and second.hits == 1 and behind.hits == 0, "one swing hits each forward target once and never a rear target")
		_check(_count("hitpause_started") == 1 and _count("strike_confirmed") == 2, "multiple contacts produce one impact pause per swing")
		_check(front.last_impulse.x * direction > 0 and second.last_serial == front.last_serial, "directional contact payload retains shared swing identity")
		await _step(); await _step({"attack": true}); await _until(func(): return actor.weapon_phase == &"idle")
		_check(front.hits == 2 and second.hits == 2, "next swing resets target dedup without repeating within a swing")
		await _finish()
	await _begin("wall occlusion blocks actual melee contact")
	var target = _target(Vector2(135, 200)); _surface(Vector2(116, 130), Vector2(4, 70)); await _step({}, 2)
	await _step({"attack": true}); await _until(func(): return actor.weapon_phase == &"idle")
	_check(target.hits == 0 and contact.occluded_contacts > 0, "overlapping strike cannot damage a target across solid wall")
	_check(not _solid_overlap(), "committed attack movement also respects same wall")
	await _finish()
	await _begin("narrow target swept between active samples")
	actor.combat_profile.attack_active_ground_speed = actor.profile.run_speed * 8
	actor.combat_profile.strike_size.x = 2
	var narrow = _target(Vector2(127, 200), Vector2(1, 24)); await _step({}, 2)
	await _step({"attack": true}); await _until(func(): return actor.weapon_phase == &"active")
	_check(narrow.hits == 1, "adapter samples continuous first active travel across one-pixel hurtbox")
	await _finish()
	await _begin("stale strike rejection after damage and reset")
	await _step({"attack": true}); await _until(func(): return actor.weapon_phase == &"active")
	var stale: Dictionary = actor.strike_snapshot()
	var later = _target(actor.global_position + Vector2(26, 0)); await _step()
	var before: int = later.hits
	actor.receive_hit({"rollable": false, "impulse": Vector2.ZERO, "hitpause": 0.0})
	contact.sample_strike(actor, stale)
	_check(later.hits == before and not actor.confirm_strike(int(stale.serial), later.get_instance_id() + 1, later.global_position), "forced damage invalidates delayed adapter callbacks and direct stale confirmation")
	actor.reset_actor(Vector2(100, 200)); await _step({}, 2)
	await _step({"attack": true}); await _until(func(): return actor.weapon_phase == &"active")
	_check(actor.attack_serial > int(stale.serial) and not actor.confirm_strike(int(stale.serial), later.get_instance_id() + 2, later.global_position), "reset and new attack cannot reuse old active generation")
	await _finish()

func _hitpause_input() -> void:
	for action in ["roll", "attack"]:
		await _begin("hitpause captures single " + action + " edge")
		var pause: float = maxf(actor.combat_profile.roll_buffer_seconds, actor.combat_profile.attack_buffer_seconds) * 2
		actor.apply_hitpause(pause)
		var initial: Vector2 = actor.global_position; var clock: float = actor.telemetry().time
		await _step({action: true}); await _step(); await _step({action: true})
		var buffered: float = actor.telemetry()[action + "_buffer"]
		await _until(func(): return actor.hitpause_remaining <= 0, {action: true})
		_check(actor.global_position == initial and actor.telemetry().time == clock and actor.telemetry()[action + "_buffer"] == buffered, "freeze holds actor movement and buffer clocks while sampling repeated input edges")
		await _step({action: true})
		_check(actor.main_action == &"roll" if action == "roll" else actor.weapon_phase == &"windup", "queued latest edge executes on first resumed simulation tick")
		await _seconds({action: true}, 1)
		_check(_count("roll_started" if action == "roll" else "attack_started") == 1, "frozen rapid presses collapse to one consumed queue and held input does not repeat")
		await _finish()
	for repress in [false, true]:
		await _begin("jump tap through hitpause " + ("latest held repress" if repress else "released tap"))
		actor.apply_hitpause(.2)
		await _step({"jump": true}); await _step()
		if repress: await _step({"jump": true})
		await _until(func(): return actor.hitpause_remaining <= 0, {"jump": repress})
		await _step({"jump": repress})
		_check(_count("ground_jump") == 1, "frozen jump tap becomes one actual resumed launch")
		if repress: _check(actor.velocity.y < -actor.profile.jump_release_rise_cap, "new held press supersedes older release latch and preserves full ascent")
		else: _check(actor.velocity.y >= -actor.profile.jump_release_rise_cap, "released paused tap applies variable-jump cut on resumed launch")
		await _finish()
	await _begin("buffer expiration uses unfrozen actor time")
	actor.set_weapon_permissions({"can_attack": false})
	await _step({"attack": true}); var original: float = actor.telemetry().attack_buffer
	actor.apply_hitpause(actor.combat_profile.attack_buffer_seconds * 2)
	await _until(func(): return actor.hitpause_remaining <= 0)
	_near(actor.telemetry().attack_buffer, original, .000001, "unavailable buffer lifetime is frozen for arbitrarily longer wall time")
	await _seconds({}, actor.combat_profile.attack_buffer_seconds + 2 * dt)
	actor.set_weapon_permissions(); await _step()
	_check(actor.weapon_phase == &"idle" and _count("attack_started") == 0, "expired simulation-time buffer does not resurrect when action becomes permitted")
	await _finish()
	for action in ["jump", "roll", "attack"]:
		await _begin("disabled held input does not fabricate " + action)
		actor.allow_input = false; await _step({action: true}, 3)
		actor.allow_input = true; await _step({action: true}, 2)
		_check(_count("ground_jump") == 0 and _count("roll_started") == 0 and _count("attack_started") == 0, "re-enabling controls does not synthesize a held-button edge")
		await _step(); await _step({action: true})
		_check(_count("ground_jump" if action == "jump" else ("roll_started" if action == "roll" else "attack_started")) == 1, "fresh release and repress remains usable after disabled interval")
		await _finish()
	await _begin("pause freezes action and cooldown with moving support", Vector2(100, 160), false)
	var support = _surface(Vector2(20, 160), Vector2(400, 30)); await _step({}, 2)
	await _step({"roll": true}); await _seconds({}, actor.combat_profile.roll_start_seconds)
	var old: Dictionary = actor.telemetry(); var old_position: Vector2 = actor.global_position
	support.moving = true; support.travel = Vector2(100, -20); support.travel_speed = 60
	actor.apply_hitpause(.15); await _until(func(): return actor.hitpause_remaining <= 0)
	var after: Dictionary = actor.telemetry()
	_check(after.roll_elapsed == old.roll_elapsed and after.roll_cooldown == old.roll_cooldown, "local freeze holds action and cooldown clocks")
	_check(actor.global_position.x > old_position.x and actor.global_position.y < old_position.y and not _solid_overlap(), "moving carrier still transports frozen actor safely")
	await _finish()

func _damage_and_reset() -> void:
	await _begin("exclusive iframe end at nominal actor time")
	await _step({"roll": true})
	var end_ticks: int = roundi(actor.combat_profile.roll_invulnerable_until / dt)
	await _step({}, end_ticks)
	measurements = {"advances_since_roll_start": end_ticks, "nominal_elapsed": end_ticks * dt, "stored_elapsed": actor.telemetry().roll_elapsed}
	_check(not actor.is_roll_invulnerable(), "roll protection ends at the exact nominal profile boundary rather than one tick later from accumulation")
	_check(actor.receive_hit({"rollable": true, "hitpause": 0.0, "impulse": Vector2.ZERO}), "hit at exact nominal exclusive end is accepted")
	await _finish()
	for boundary in ["before_start", "first_inside", "last_inside", "first_outside"]:
		await _begin("rollable hit iframe " + boundary)
		var p = actor.combat_profile
		await _step({"roll": true})
		var advances := ceili(p.roll_invulnerable_from / dt) - 1 if boundary == "before_start" else (ceili(p.roll_invulnerable_from / dt) if boundary == "first_inside" else (ceili(p.roll_invulnerable_until / dt) - 1 if boundary == "last_inside" else ceili(p.roll_invulnerable_until / dt)))
		await _step({}, maxi(0, advances))
		var elapsed = _roll_time(); var expected_protected: bool = boundary in ["first_inside", "last_inside"]
		var accepted: bool = actor.receive_hit({"rollable": true, "impulse": Vector2(-100, -40), "hitpause": 0.0})
		measurements = {"roll_elapsed_at_hit": elapsed, "nominal_elapsed": advances * dt, "expected_protected": expected_protected, "accepted": accepted}
		_check(accepted != expected_protected and actor.is_roll_invulnerable() == expected_protected, "receive_hit honors inclusive start and exclusive end at sampled boundary")
		_check(actor.main_action == (&"roll" if expected_protected else &"hurt"), "only accepted damage interrupts roll owner")
		await _finish()
	await _begin("unrollable damage clears active owners and intent")
	await _step({"roll": true}); await _until(func(): return actor.is_roll_invulnerable())
	actor.apply_hitpause(.2); await _step({"attack": true, "jump": true})
	var accepted: bool = actor.receive_hit({"rollable": false, "source_position": Vector2(200, 200), "impulse": Vector2(-180, -100), "hitpause": .06})
	var t: Dictionary = actor.telemetry()
	_check(accepted and actor.main_action == &"hurt" and not actor.is_roll_invulnerable() and actor.weapon_phase == &"idle", "unrollable hit bypasses roll protection and cancels both owners")
	_check(t.jump_buffer == 0 and t.roll_buffer == 0 and t.attack_buffer == 0 and actor.velocity == Vector2(-180, -100), "accepted damage clears older buffered actions and adopts explicit impulse")
	await _until(func(): return actor.hitpause_remaining <= 0)
	await _seconds({}, actor.combat_profile.hurt_seconds + 2 * dt)
	_check(actor.main_action != &"hurt" and _count("attack_started") == 0 and _count("ground_jump") == 0, "hurt finishes in actor time without replaying pre-hit intent")
	await _finish()
	for state in ["roll", "attack", "hurt"]:
		await _begin("reset discards " + state + " and pause")
		if state == "hurt": actor.receive_hit({"rollable": false})
		else: await _step({state: true})
		actor.apply_hitpause(.2); await _step({"jump": true, "roll": true, "attack": true})
		var old_serial: int = actor.attack_serial
		actor.reset_actor(Vector2(70, 200), -1); var t0: Dictionary = actor.telemetry()
		_check(actor.main_action == &"locomotion" and actor.weapon_phase == &"idle" and actor.velocity == Vector2.ZERO and actor.facing == -1, "reset restores neutral actor at requested transform")
		_check(t0.hitpause_remaining == 0 and t0.roll_cooldown == 0 and t0.jump_buffer == 0 and t0.roll_buffer == 0 and t0.attack_buffer == 0 and actor.air_roll_available, "reset clears pause cooldown buffers and airborne-roll debt")
		_check(not actor.confirm_strike(old_serial, 12345, actor.global_position), "pre-reset strike identity has no active authority")
		await _step({}, 2); _check(actor.grounded and not _solid_overlap(), "reset resumes normal collision and floor support")
		await _finish()

func _key(code: Key, pressed: bool) -> void:
	var event = InputEventKey.new(); event.physical_keycode = code; event.pressed = pressed
	Input.parse_input_event(event)

func _native_combat_input() -> void:
	await _begin("native parsed combat input through local hitpause")
	actor.automatic_physics = true
	actor.apply_hitpause(.2)
	_key(KEY_J, true); await _step(null); _key(KEY_J, false); await _step(null)
	await _until(func(): return actor.hitpause_remaining <= 0, null)
	await _step(null)
	_check(actor.weapon_phase == &"windup" and _count("attack_started") == 1, "native parsed J tap during pause survives to one resumed attack")
	_key(KEY_SHIFT, true); await _step(null)
	_check(actor.main_action == &"roll" and actor.weapon_phase == &"idle", "native Shift cancels permitted windup using same actor")
	_key(KEY_SHIFT, false); await _step(null)
	await _finish()

func _melee_cancellations() -> void:
	for cancel in ["jump", "roll"]:
		await _begin("windup " + cancel + " cancels pending strike")
		await _step({"attack": true}); await _step({cancel: true})
		_check(actor.weapon_phase == &"idle" and (actor.main_action == &"roll" if cancel == "roll" else _count("ground_jump") == 1), "allowed windup interruption clears weapon owner immediately")
		await _seconds({}, .6)
		_check(strikes.is_empty(), "canceled windup never materializes its old active strike")
		await _finish()
	await _begin("active roll buffer and recovery permission")
	await _step({"attack": true}); await _until(func(): return actor.weapon_phase == &"active")
	await _step({"roll": true})
	_check(actor.weapon_phase == &"active" and actor.main_action != &"roll", "roll is denied during committed active phase")
	await _until(func(): return actor.main_action == &"roll", {"roll": true}, .4)
	_check(actor.main_action == &"roll" and actor.weapon_phase == &"idle", "buffered roll executes once when recovery permits it")
	await _finish()
	await _begin("external permissions intersect weapon phases")
	actor.set_weapon_permissions({"can_move": false, "can_turn": true, "can_jump": false, "move_scale": .5})
	await _step({"attack": true, "left": 1.0, "jump": true})
	_check(actor.facing == -1 and actor.move_x == 0 and _count("ground_jump") == 0, "host movement and jump locks preserve permitted windup turn")
	_near(actor.weapon_permissions.move_scale, .5 * actor.combat_profile.attack_windup_move_scale, .000001, "host and phase scales multiply")
	await _until(func(): return actor.weapon_phase == &"active")
	_check(not actor.weapon_permissions.can_move and not actor.weapon_permissions.can_turn and not actor.weapon_permissions.can_jump and not actor.weapon_permissions.can_roll and not actor.weapon_permissions.can_attack, "active effective permission snapshot denies movement, turning and every player interruption")
	await _until(func(): return actor.weapon_phase == &"recovery")
	_check(not actor.weapon_permissions.can_move and actor.weapon_permissions.can_turn and not actor.weapon_permissions.can_jump, "recovery restores only permissions also allowed by host")
	_near(actor.weapon_permissions.move_scale, .5 * actor.combat_profile.attack_recovery_move_scale, .000001, "recovery scale preserves host multiplier")
	await _finish()
	await _begin("held melee and late recovery buffer")
	await _step({"attack": true}); var serial: int = actor.attack_serial
	var starting_tick: int = driver.ticks
	await _until(func(): return actor.weapon_phase == &"idle", {"attack": true})
	var attack_seconds: float = (driver.ticks - starting_tick) * dt
	measurements["attack_seconds"] = attack_seconds
	_near(attack_seconds, actor.combat_profile.attack_windup_seconds + actor.combat_profile.attack_active_seconds + actor.combat_profile.attack_recovery_seconds, dt + .000001, "complete melee phase time matches authored seconds")
	await _seconds({"attack": true}, .4)
	_check(actor.attack_serial == serial and actor.weapon_phase == &"idle", "holding attack does not create repeated swings")
	await _step(); await _step({"attack": true}); serial = actor.attack_serial
	await _until(func(): return actor.weapon_phase == &"recovery")
	await _until(func(): return _weapon_time() >= actor.combat_profile.attack_recovery_seconds - actor.combat_profile.attack_buffer_seconds * .5)
	await _step({"attack": true})
	_check(actor.attack_serial == serial, "new swing cannot interrupt existing recovery")
	await _until(func(): return actor.attack_serial > serial, {"attack": true}, .4)
	_check(actor.attack_serial == serial + 1 and actor.weapon_phase == &"windup", "late recovery edge becomes exactly one buffered new swing")
	await _finish()

func _extra_combat_edges() -> void:
	await _begin("hurt hitpause retains rising carrier clearance", Vector2(100, 160), false)
	var rising = _surface(Vector2(0, 160), Vector2(400, 30)); await _step({}, 2)
	rising.moving = true; rising.travel = Vector2(0, -60); rising.travel_speed = 100
	await _step()
	actor.receive_hit({"rollable": false})
	_check(not actor.weapon_permissions.can_roll and not actor.weapon_permissions.can_attack, "hurt effective permissions expose attack and roll denials to host")
	var safe := true
	while actor.hitpause_remaining > 0:
		await _step(); safe = safe and not _solid_overlap()
	_check(safe, "receiving damage on a rising carrier cannot embed frozen hurt body during impact pause")
	await _step()
	_check(actor.velocity.y < 0 and not _solid_overlap(), "resumed hurt impulse separates from carrier without overlap")
	await _finish()
	await _begin("existing crate receives real melee launch")
	var crate = CRATE.instantiate(); crate.position = Vector2(131, 186); world.add_child(crate)
	var launched := [0]
	crate.launched.connect(func(_prop): launched[0] += 1)
	await _step({}, 3); await _step({"attack": true})
	await _until(func(): return launched[0] > 0, {}, .5)
	_check(launched[0] == 1 and crate.charge > 0 and crate.hit_count == 1, "existing rigid-body crate receives one real adapter launch and charge")
	var launch_position: Vector2 = crate.global_position
	# apply_central_impulse is committed by the subsequent PhysicsServer step.
	await _step({}, 2)
	_check(crate.linear_velocity.x > crate.tuning.launch_speed * .5 and crate.global_position.x > launch_position.x, "existing prop launch carries substantial forward momentum after actual solver integration")
	measurements = {"launch_count": launched[0], "charge": crate.charge, "velocity": crate.linear_velocity}
	await _finish()
	await _begin("landing during airborne roll keeps coherent action", Vector2(100, 185))
	actor.velocity.y = 180
	await _step({"roll": true}); await _until(func(): return actor.grounded, {}, .2)
	_check(actor.grounded and actor.main_action == &"roll" and actor.air_roll_available and actor.air_jumps_left == actor.profile.air_jump_count, "real landing during roll restores budgets without discarding active roll")
	_check(actor.crouched and not _solid_overlap(), "landed roll preserves small collision body without embedding")
	await _until(func(): return actor.main_action != &"roll")
	_check(not actor.crouched and actor.grounded, "roll expiry after landing restores ordinary standing support")
	await _finish()
	for late in [false, true]:
		await _begin("roll cooldown buffer " + ("late survives" if late else "early expires"))
		await _step({"roll": true})
		if late: await _until(func(): return actor.main_action != &"roll")
		else: await _seconds({}, actor.combat_profile.roll_start_seconds)
		await _step({"roll": true})
		_check(_count("roll_started") == 1, "cooldown rejects immediate new roll despite fresh edge")
		await _seconds({"roll": true}, actor.combat_profile.roll_cooldown_seconds + _roll_duration())
		_check(_count("roll_started") == (2 if late else 1), "only a buffer still alive at cooldown expiry starts one additional roll")
		await _finish()
	await _begin("hitpause cannot sweep stale carrier strike path", Vector2(100, 160), false)
	var carrier = _surface(Vector2(0, 160), Vector2(400, 30)); await _step({}, 2)
	await _step({"attack": true}); await _until(func(): return actor.weapon_phase == &"active")
	var active_elapsed: float = actor.telemetry().weapon_elapsed
	var stale: Dictionary = actor.strike_snapshot()
	var skipped = _target(actor.global_position + Vector2(30 + actor.combat_profile.strike_size.x * .5, 0), Vector2(1, 24))
	carrier.moving = true; carrier.travel = Vector2(100, 0); carrier.travel_speed = 300
	actor.apply_hitpause(.2)
	_check(not actor.strike_snapshot().eligible and not actor.confirm_strike(actor.attack_serial, skipped.get_instance_id(), skipped.global_position), "public snapshots and delayed confirmations cannot deal damage during local freeze")
	await _until(func(): return actor.hitpause_remaining <= 0)
	carrier.moving = false
	_check(actor.telemetry().weapon_elapsed == active_elapsed and skipped.hits == 0, "paused carrier travels while active phase and contacts remain frozen")
	await _step()
	_check(skipped.hits == 0, "resumption does not sweep damage over space crossed only during paused transport")
	measurements = {"old_strike_center": stale.center, "resumed_center": actor.strike_snapshot().center}
	await _finish()
	await _begin("scene pause suspends active physics and resumes once")
	await _step({"attack": true})
	var before: Dictionary = actor.telemetry(); var before_ticks: int = driver.ticks
	paused = true
	for _i in range(5): await process_frame
	_check(driver.ticks == before_ticks and actor.telemetry().weapon_elapsed == before.weapon_elapsed, "SceneTree pause suspends actor and test physics driver")
	paused = false; await _step()
	_check(_count("attack_started") == 1 and actor.telemetry().weapon_elapsed > before.weapon_elapsed, "scene resume advances original action without replaying input edge")
	await _finish()
