@tool
class_name MokshaGuardPropFixture
extends StaticBody2D
## Original RigidBody2D crate with an instance-only defense bridge and wire view.
const Crate = preload("res://scenes/props/crate.tscn")
const Bridge = preload("res://combat_pc/components/guard_prop_adapter.gd")
signal attack_resolved(result: Dictionary)
@export_range(-1, 1, 2) var direction := -1:
	set(value):
		direction = -1 if value < 0 else 1
		queue_redraw()
@export var auto_attack := false
@export var simulation_enabled := true
@export var interval_seconds := 2.8
@export var telegraph_seconds := 0.65
@export var launch_speed := 230.0
@export var launch_lift := -35.0
@export var body_gravity_scale := 0.4
@export var spawn_height := 18.0
@export var maximum_props := 2
@export var prop_lifetime := 5.0
var fixture_paused := false
var elapsed := 0.0
var pending_attack := false
var telegraph_elapsed := 0.0
var launches := 0
var contacts := 0
var returned := 0
var last_result: Dictionary = {}

func _ready() -> void:
	process_physics_priority = 100
	collision_layer = 4
	collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 30)
	$Shape.shape = shape
	$Shape.position = Vector2(0, -15)

func _physics_process(dt: float) -> void:
	if Engine.is_editor_hint(): return
	if not simulation_enabled or fixture_paused: return
	elapsed += dt
	if pending_attack:
		telegraph_elapsed += dt
		if telegraph_elapsed >= telegraph_seconds:
			pending_attack = false
			elapsed = 0
			throw_prop()
	elif auto_attack and elapsed >= interval_seconds:
		request_attack()
	queue_redraw()

func request_attack() -> bool:
	if Engine.is_editor_hint(): return false
	if not simulation_enabled or fixture_paused or pending_attack or $Props.get_child_count() >= maximum_props: return false
	pending_attack = true
	telegraph_elapsed = 0
	queue_redraw()
	return true

func throw_prop() -> RigidBody2D:
	if Engine.is_editor_hint(): return null
	if not simulation_enabled or fixture_paused or $Props.get_child_count() >= maximum_props: return null
	var body := Crate.instantiate() as RigidBody2D
	body.tuning = body.tuning.duplicate(true)
	body.tuning.launch_speed = launch_speed
	body.tuning.launch_lift = launch_lift
	body.tuning.launch_spin_range = Vector2.ZERO
	body.tuning.body_gravity_scale = body_gravity_scale
	body.tuning.hard_impacts_to_break = 6
	body.get_node("Sprite").visible = false
	body.position = Vector2((-1 if direction < 0 else 1) * 23, -spawn_height)
	var bridge := Bridge.new()
	bridge.name = "GuardPropAdapter"
	bridge.lifetime_seconds = prop_lifetime
	body.add_child(bridge)
	$Props.add_child(body)
	bridge.configure(self)
	bridge.resolved.connect(_on_resolved)
	body.add_collision_exception_with(self)
	body.launch(-1 if direction < 0 else 1)
	launches += 1
	return body

func _on_resolved(result: Dictionary) -> void:
	contacts += 1
	last_result = result.duplicate(true)
	attack_resolved.emit(last_result.duplicate(true))

func receive_guard_projectile(payload: Dictionary) -> Dictionary:
	if not simulation_enabled or fixture_paused: return {"accepted": false}
	returned += 1
	return {"accepted": true, "damage_applied": float(payload.get("damage", 0)), "returned": returned}

func receive_strike(_payload: Dictionary) -> void:
	pass

func set_fixture_paused(paused: bool) -> void:
	if fixture_paused == paused: return
	fixture_paused = paused
	for body in $Props.get_children():
		var bridge := body.get_node_or_null("GuardPropAdapter")
		if bridge != null: bridge.set_fixture_paused(paused)

func set_simulation_enabled(enabled: bool) -> void:
	simulation_enabled = enabled
	if not enabled: pending_attack = false
	for body in $Props.get_children():
		var bridge := body.get_node_or_null("GuardPropAdapter")
		if bridge != null: bridge.set_simulation_enabled(enabled)

func reset_fixture() -> void:
	pending_attack = false
	telegraph_elapsed = 0
	for body in $Props.get_children():
		var bridge := body.get_node_or_null("GuardPropAdapter")
		if bridge != null: bridge.retire()
	elapsed = 0
	launches = 0
	contacts = 0
	returned = 0
	last_result.clear()
	queue_redraw()

func _draw() -> void:
	var color := Color("cbb18c")
	draw_rect(Rect2(-6, -30, 12, 30), color, false, 1)
	if pending_attack: draw_circle(Vector2(0, -34), 2, Color("e5b566"))
	draw_line(Vector2(-10, 0), Vector2(10, 0), color)
	draw_string(ThemeDB.fallback_font, Vector2(-31, -41), "RIGID PROP", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, color)
	draw_string(ThemeDB.fallback_font, Vector2(-24, 13), "L %d  R %d" % [launches, returned], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, color)
