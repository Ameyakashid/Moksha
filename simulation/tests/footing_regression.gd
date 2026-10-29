extends SceneTree
const ProbeProfile = preload("res://simulation/resources/terrain_probe_profile.gd")
const Probe = preload("res://simulation/components/terrain_probe.gd")
const Enemy = preload("res://demo/components/enemy.tscn")
const Player = preload("res://combat_pc/player.tscn")
const Motor = preload("res://movement/actors/player.tscn")
var world: Node2D
var checks := 0
var failures: Array[String] = []
var hz := 120
class Driver extends Node:
	var actor: Node
	var frame := {}
	func _physics_process(dt: float) -> void: actor.physics_tick(dt, frame)
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz = int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second = hz
	_run.call_deferred()
func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame
func _surface(at: Vector2, size: Vector2, layer := 1) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = at
	body.collision_layer = layer
	var collider := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = size
	collider.shape = box
	body.add_child(collider)
	world.add_child(body)
	return body
func _begin() -> void:
	world = Node2D.new()
	root.add_child(world)
func _end() -> void:
	world.queue_free()
	await _frames(2)
func _run() -> void:
	# API-boundary impulse probe: no transform writes after initial placement.
	# Matched capsule/rectangle shapes are not assumed identical solvers.
	_begin()
	_surface(Vector2(100, 220), Vector2(200, 40))
	var enemy = Enemy.instantiate()
	enemy.position = Vector2(180, 200)
	enemy.ai_enabled = false
	world.add_child(enemy)
	await _frames(5)
	_check(enemy.is_on_floor(), "NPC actually settles on support")
	_check(Probe.obstacle(enemy, 1, 30, deg_to_rad(46)) == "Edge", "prospective gap is observed")
	var before: Vector2 = enemy.position
	var speed: Vector2 = enemy.velocity
	Probe.obstacle(enemy, 1, 30, deg_to_rad(46))
	_check(enemy.position == before and enemy.velocity == speed, "query cannot mutate physical state")
	enemy.apply_impulse(Vector2(300, 0), 0.5)
	await _frames(ceili(0.4 * hz))
	_check(enemy.position.x > 208 and enemy.position.y > 205, "horizontal impulse carries NPC off support; AI cannot cancel it")
	await _end()
	# Existing autonomous policy must still brake before a ledge under locomotion.
	_begin()
	_surface(Vector2(100, 220), Vector2(200, 40))
	enemy = Enemy.instantiate()
	enemy.position = Vector2(100, 200)
	enemy.patrol_radius = 400
	world.add_child(enemy)
	await _frames(hz * 3)
	_check(enemy.position.x < 195 and enemy.position.y < 201, "intent-only patrol avoids gap without a clamp")
	await _end()
	# Real production contact: raw attack input, no injected strike/health packet.
	_begin()
	_surface(Vector2(100, 220), Vector2(200, 40))
	_surface(Vector2(280, 340), Vector2(400, 40))
	var pc = Player.instantiate()
	pc.position = Vector2(169, 200)
	pc.automatic_physics = false
	world.add_child(pc)
	var driver := Driver.new()
	driver.actor = pc
	world.add_child(driver)
	enemy = Enemy.instantiate()
	enemy.position = Vector2(198, 200)
	enemy.ai_enabled = false
	world.add_child(enemy)
	enemy.configure(pc, root.get_node("NoiseBus"))
	await _frames(6)
	_check(Probe.obstacle(pc, 1, 50, deg_to_rad(46)) == "Edge", "same query accepts actual combat PC")
	driver.frame = {"attack": true}
	await _frames(ceili(hz * 0.14))
	driver.frame = {}
	await _frames(hz)
	_check(enemy.health < 3.0, "ordinary PC strike produces physical contact and damage")
	_check(enemy.get_node("Knockback").applied_count > 0, "ordinary PC strike produces accepted knockback")
	_check(enemy.position.y > 260, "struck NPC lands on lower support without scripted fall")
	await _end()
	# The same query accepts a physical object, obeys masks, and observes removed support.
	_begin()
	var floor_body := _surface(Vector2(100, 220), Vector2(200, 40), 8)
	var object := RigidBody2D.new()
	object.position = Vector2(100, 200)
	object.freeze = true
	world.add_child(object)
	await _frames(3)
	_check(Probe.obstacle(object, 1, 24, deg_to_rad(46), 8) == "", "same query accepts rigid object and configured surface layer")
	_check(Probe.obstacle(object, 1, 24, deg_to_rad(46), 1) == "Edge", "query respects collision mask")
	floor_body.queue_free()
	await _frames(3)
	_check(Probe.obstacle(object, 1, 24, deg_to_rad(46), 8) == "Edge", "removed support is observed without cached fiction")
	await _end()
	# Removal of real support exercises both different production solvers.
	_begin()
	floor_body = _surface(Vector2(200, 220), Vector2(400, 40))
	pc = Player.instantiate()
	pc.position = Vector2(100, 200)
	pc.automatic_physics = false
	world.add_child(pc)
	driver = Driver.new()
	driver.actor = pc
	world.add_child(driver)
	enemy = Enemy.instantiate()
	enemy.position = Vector2(300, 200)
	enemy.ai_enabled = false
	world.add_child(enemy)
	await _frames(8)
	_check(pc.grounded and enemy.is_on_floor(), "PC and NPC both settle on real support")
	floor_body.queue_free()
	await _frames(ceili(hz * 0.3))
	_check(not pc.grounded and pc.position.y > 210, "PC loses removed support and falls")
	_check(not enemy.is_on_floor() and enemy.position.y > 210, "NPC loses removed support and falls")
	await _end()
	# Geometry is explicit configuration for differently sized/origin bodies.
	_begin()
	_surface(Vector2(100,220),Vector2(200,40))
	object = RigidBody2D.new()
	object.position = Vector2(100,180)
	object.freeze = true
	world.add_child(object)
	await _frames(3)
	var geometry := ProbeProfile.new()
	geometry.floor_probe_above = 4
	geometry.floor_probe_below = 10
	_check(Probe.obstacle(object,1,40,deg_to_rad(46),1,geometry) == "Edge", "short-bodied probe respects configured depth")
	geometry.floor_probe_below = 24
	_check(Probe.obstacle(object,1,40,deg_to_rad(46),1,geometry) == "", "center-origin probe finds support with configured reach")
	_surface(Vector2(120,140),Vector2(8,20))
	await _frames(3)
	_check(Probe.obstacle(object,1,40,deg_to_rad(46),1,geometry) == "", "default lower samples do not invent overhead collision")
	geometry.wall_sample_heights = PackedFloat32Array([-40])
	_check(Probe.obstacle(object,1,40,deg_to_rad(46),1,geometry) == "Wall", "taller configured sample observes actual obstruction")
	geometry.floor_probe_below = NAN
	_check(Probe.obstacle(object,1,40,deg_to_rad(46),1,geometry) == "Invalid probe", "invalid geometry cannot be reported clear")
	_check(is_equal_approx(Probe.stopping_lookahead(10,0.5,0.01,14,24),114.1), "positive fractional braking uses actual stopping distance")
	_check(is_nan(Probe.stopping_lookahead(10,100,0.01,NAN,24)), "nonfinite margin fails closed")
	_check(is_nan(Probe.stopping_lookahead(10,100,0.01,14,-1)), "negative lookahead fails closed")
	_check(is_nan(Probe.stopping_lookahead(10,0,0.01)), "invalid braking rate fails closed")
	_check(Probe.obstacle(null,1,40,deg_to_rad(46)) == "Invalid probe", "detached null host safely rejected")
	await _end()
	print("SHARED FOOTING %d Hz: %d checks, %d failures" % [hz, checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
