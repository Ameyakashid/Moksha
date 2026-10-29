extends SceneTree
const Player = preload("res://combat_pc/player.tscn")
const Adapter = preload("res://combat_pc/components/shield_contact_adapter.gd")
const Melee = preload("res://combat_pc/fixtures/guard_melee_fixture.tscn")
const Emitter = preload("res://combat_pc/fixtures/guard_projectile_fixture.tscn")
const Prop = preload("res://combat_pc/fixtures/guard_prop_fixture.tscn")
const Bullet = preload("res://combat_pc/fixtures/guard_projectile.gd")
var world: Node2D
var actor: Node2D
var adapter: Node2D
var checks: Array[Dictionary] = []
var rate := 120
var dt := 1.0 / 120.0
var fixture: Node2D
var wall: Node2D

func _initialize() -> void:
	_run.call_deferred()

func check(name: String, accepted: bool, details: Dictionary = {}) -> void:
	checks.append({"name": name, "passed": accepted, "details": details})
	print("PASS " if accepted else "FAIL ", name, " ", details)

func frame(held: bool = false) -> void:
	await physics_frame
	actor.physics_tick(dt, {"shield": held})
	await process_frame

func frames(count: int, held: bool = false) -> void:
	for unused in range(maxi(1, roundi(count * rate / 120.0))): await frame(held)

func make_wall(at: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	world.add_child(body)
	return body

func setup(scene: PackedScene, at: Vector2) -> void:
	if is_instance_valid(fixture): fixture.free()
	if is_instance_valid(wall): wall.free()
	actor.reset_actor(Vector2.ZERO, 1)
	adapter.reset_counters()
	fixture = scene.instantiate()
	fixture.position = at
	world.add_child(fixture)
	await frames(3)

func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--rate="): rate = int(argument.split("=")[1])
	dt = 1.0 / rate
	Engine.physics_ticks_per_second = rate
	world = Node2D.new()
	root.add_child(world)
	make_wall(Vector2(0, 5), Vector2(500, 10))
	actor = Player.instantiate()
	actor.automatic_physics = false
	world.add_child(actor)
	adapter = actor.get_node_or_null("ShieldContactAdapter")
	if adapter == null:
		adapter = Adapter.new()
		actor.add_child(adapter)
	await setup(Emitter, Vector2(48, 0))
	var bullet = fixture.fire_projectile()
	await frames(19, true)
	check("bullet_actual_sweep_parry", fixture.last_result.get("outcome") == &"parried", fixture.last_result)
	check("bullet_actual_velocity_owner_reflection", is_instance_valid(bullet) and bullet.reflected and bullet.reflection_count == 1 and bullet.velocity.x > 0 and bullet.attack_owner.get_ref() == actor)
	await frames(35)
	check("bullet_returns_to_real_receiver", fixture.returned == 1, {"returned": fixture.returned})
	check("reflection_confirmed_once", adapter.confirmed_reflections == 1)
	await setup(Emitter, Vector2(48, 0))
	wall = make_wall(Vector2(20, -20), Vector2(2, 40))
	fixture.projectile_speed = 4000
	fixture.fire_projectile()
	await frames(8, true)
	check("high_speed_bullet_thin_wall_occlusion", fixture.contacts == 0 and adapter.confirmed_reflections == 0)
	await setup(Emitter, Vector2(90, 0))
	var remote := Node.new()
	world.add_child(remote)
	var orphan = Bullet.new()
	orphan.position = Vector2(36, -17)
	world.add_child(orphan)
	orphan.configure(remote, Vector2(-230, 0))
	remote.free()
	await frames(15, true)
	check("live_carrier_survives_freed_remote_owner", is_instance_valid(orphan) and orphan.reflected and adapter.confirmed_reflections == 1)
	if is_instance_valid(orphan): orphan.retire()
	await setup(Melee, Vector2(40, 0))
	fixture.request_attack()
	await frames(70)
	await frames(22, true)
	check("swept_melee_parry", fixture.last_result.get("outcome") == &"parried", fixture.last_result)
	check("real_melee_counter_receiver", fixture.counters == 1 and adapter.confirmed_counters == 1, {"counters": fixture.counters, "report": adapter.last_report})
	await setup(Melee, Vector2(40, 0))
	fixture.accepts_counter = false
	fixture.request_attack()
	await frames(70)
	await frames(22, true)
	check("counter_rejection_keeps_parry", fixture.last_result.get("outcome") == &"parried" and not fixture.last_result.get("counter_confirmed", true) and fixture.counters == 0)
	await setup(Melee, Vector2(40, 0))
	wall = make_wall(Vector2(20, -20), Vector2(2, 40))
	fixture.request_attack()
	await frames(70)
	await frames(22, true)
	check("melee_wall_stops_actual_tip", fixture.contacts == 0)
	await setup(Prop, Vector2(67, 0))
	var bus = root.get_node("NoiseBus")
	bus.clear_history()
	var prop = fixture.throw_prop()
	var bridge = prop.get_node("GuardPropAdapter")
	await frames(18, true)
	check("rigid_prop_real_solver_contact", fixture.contacts > 0, {"contacts": fixture.contacts, "result": fixture.last_result, "position": prop.position if is_instance_valid(prop) else Vector2.INF})
	check("rigid_prop_actual_reflection", is_instance_valid(prop) and bridge.reflected and bridge.reflection_count == 1 and prop.linear_velocity.x > 0, {"result": fixture.last_result, "report": adapter.last_report})
	var launch_noise := false
	for event in bus.event_history:
		if event.kind == &"prop_launch" and Vector2(event.origin).distance_to(Vector2(44, -18)) < 0.01: launch_noise = true
	check("original_prop_launch_noise_world_origin", launch_noise)
	await frames(45)
	check("rigid_prop_returns_to_real_receiver", fixture.returned == 1, {"returned": fixture.returned})
	await setup(Emitter, Vector2(-48, 0))
	actor.reset_actor(Vector2.ZERO, -1)
	fixture.direction = 1
	fixture.fire_projectile()
	await frames(19, true)
	check("mirrored_bullet_parry", fixture.last_result.get("outcome") == &"parried" and adapter.confirmed_reflections == 1)
	await setup(Melee, Vector2(-40, 0))
	actor.reset_actor(Vector2.ZERO, -1)
	fixture.direction = 1
	fixture.request_attack()
	await frames(70)
	await frames(22, true)
	check("mirrored_melee_counter", fixture.last_result.get("outcome") == &"parried" and fixture.counters == 1)
	await setup(Prop, Vector2(-67, 0))
	actor.reset_actor(Vector2.ZERO, -1)
	fixture.direction = 1
	prop = fixture.throw_prop()
	bridge = prop.get_node("GuardPropAdapter")
	await frames(18, true)
	check("mirrored_rigid_prop_reflection", fixture.last_result.get("outcome") == &"parried" and bridge.reflected and prop.linear_velocity.x < 0, fixture.last_result)
	await setup(Prop, Vector2(150, 0))
	wall = make_wall(Vector2(45, -45), Vector2(2, 90))
	fixture.launch_speed = 4000
	fixture.launch_lift = 0
	fixture.throw_prop()
	await frames(14, true)
	check("high_speed_rigid_prop_thin_wall", fixture.contacts == 0 and adapter.confirmed_reflections == 0, {"contacts": fixture.contacts})
	await setup(Emitter, Vector2(48, 0))
	fixture.request_attack()
	await frames(5)
	fixture.set_simulation_enabled(false)
	fixture.set_simulation_enabled(true)
	await frames(80)
	check("disabled_emitter_retires_pending_windup", fixture.shots == 0)
	await setup(Emitter, Vector2(48, 0))
	fixture.request_attack()
	await frames(9)
	var phase_before_pause: float = fixture.telegraph_elapsed
	fixture.set_fixture_paused(true)
	fixture.set_fixture_paused(true)
	await frames(80)
	check("global_pause_preserves_pending_telegraph", fixture.pending_attack and fixture.telegraph_elapsed == phase_before_pause and fixture.shots == 0)
	fixture.set_fixture_paused(false)
	await frames(70)
	check("global_resume_completes_preserved_attack", fixture.shots == 1)
	await setup(Prop, Vector2(150, -30))
	prop = fixture.throw_prop()
	bridge = prop.get_node("GuardPropAdapter")
	await frames(3)
	fixture.set_fixture_paused(true)
	fixture.set_fixture_paused(true)
	bridge.set_fixture_paused(true)
	var stopped_at: Vector2 = prop.global_position
	var stored_velocity: Vector2 = prop.linear_velocity
	await frames(15)
	check("rigid_pause_freezes_physics", prop.freeze and prop.global_position.distance_to(stopped_at) < 0.001, {"travel": prop.global_position.distance_to(stopped_at)})
	fixture.set_fixture_paused(false)
	bridge.set_fixture_paused(false)
	check("rigid_resume_restores_velocity", not prop.freeze and prop.linear_velocity.distance_to(stored_velocity) < 0.001)
	await frames(3)
	check("rigid_resume_moves_again", prop.global_position.distance_to(stopped_at) > 1)
	fixture.reset_fixture()
	await frames(2)
	check("reset_removes_transient_bodies", fixture.get_node("Props").get_child_count() == 0)
	var failures := checks.filter(func(item): return not item.passed).size()
	var report := {"suite": "M8 production shield-contact component smoke", "physics_hz": rate, "checks": checks, "passed": checks.size() - failures, "failures": failures}
	var output := FileAccess.open("res://combat_pc/components/tests/guard_component_smoke_results_%dhz.json" % rate, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print("COMPONENT_RESULT ", report.passed, "/", checks.size(), " failures=", failures)
	quit(0 if failures == 0 else 1)
