@tool
class_name MokshaGuardProjectileFixture
extends StaticBody2D
## Stationary emitter/return receiver. Carriers live beneath this fixture.
const Carrier = preload("res://combat_pc/fixtures/guard_projectile.gd")
signal attack_resolved(result: Dictionary)
signal projectile_received(payload: Dictionary)
@export_range(-1, 1, 2) var direction := -1:
	set(value):
		direction = -1 if value < 0 else 1
		queue_redraw()
@export var auto_attack := false
@export var simulation_enabled := true
@export var interval_seconds := 1.65
@export var telegraph_seconds := 0.5
@export var projectile_speed := 230.0
@export var projectile_lifetime := 3.5
@export var attack_damage := 10.0
@export var blockable := true
@export var parryable := true
@export var reflectable := true
@export var rollable := true
@export var maximum_carriers := 4
@export var muzzle_height := 17.0
var fixture_paused := false
var elapsed := 0.0
var pending_attack := false
var telegraph_elapsed := 0.0
var shots := 0
var returned := 0
var contacts := 0
var last_result: Dictionary = {}
var _serial := 0
var _flash := 0.0

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
	_flash = maxf(0, _flash - dt)
	if pending_attack:
		telegraph_elapsed += dt
		if telegraph_elapsed >= telegraph_seconds:
			pending_attack = false
			elapsed = 0
			fire_projectile()
	elif auto_attack and elapsed >= interval_seconds:
		request_attack()
	queue_redraw()

func request_attack() -> bool:
	if Engine.is_editor_hint(): return false
	if not simulation_enabled or fixture_paused or pending_attack or $Carriers.get_child_count() >= maximum_carriers: return false
	pending_attack = true
	telegraph_elapsed = 0
	queue_redraw()
	return true

func fire_projectile() -> CharacterBody2D:
	if Engine.is_editor_hint(): return null
	if not simulation_enabled or fixture_paused or $Carriers.get_child_count() >= maximum_carriers: return null
	_serial += 1
	var carrier := Carrier.new()
	carrier.position = Vector2((-1 if direction < 0 else 1) * 13, -muzzle_height)
	carrier.attack_damage = attack_damage
	carrier.lifetime_seconds = projectile_lifetime
	carrier.blockable = blockable
	carrier.parryable = parryable
	carrier.reflectable = reflectable
	carrier.rollable = rollable
	$Carriers.add_child(carrier)
	carrier.configure(self, Vector2((-1 if direction < 0 else 1) * projectile_speed, 0), _serial)
	carrier.resolved.connect(_on_resolved)
	shots += 1
	return carrier

func _on_resolved(_carrier: Node2D, result: Dictionary) -> void:
	contacts += 1
	last_result = result.duplicate(true)
	attack_resolved.emit(last_result.duplicate(true))

func receive_guard_projectile(payload: Dictionary) -> Dictionary:
	if not simulation_enabled or fixture_paused: return {"accepted": false, "reason": &"receiver_paused"}
	returned += 1
	_flash = 0.3
	projectile_received.emit(payload)
	return {"accepted": true, "damage_applied": float(payload.get("damage", 0)), "returned": returned}

func receive_strike(_payload: Dictionary) -> void:
	_flash = 0.15

func set_fixture_paused(paused: bool) -> void:
	if fixture_paused == paused: return
	fixture_paused = paused
	for carrier in $Carriers.get_children():
		if carrier.has_method("set_fixture_paused"): carrier.set_fixture_paused(paused)

func set_simulation_enabled(enabled: bool) -> void:
	simulation_enabled = enabled
	if not enabled: pending_attack = false
	for carrier in $Carriers.get_children():
		if carrier.has_method("set_simulation_enabled"): carrier.set_simulation_enabled(enabled)

func reset_fixture() -> void:
	pending_attack = false
	telegraph_elapsed = 0
	for carrier in $Carriers.get_children(): carrier.retire(&"fixture_reset")
	elapsed = 0
	shots = 0
	returned = 0
	contacts = 0
	last_result.clear()
	queue_redraw()

func _draw() -> void:
	var color := Color("80dbc7") if _flash > 0 else Color("8e9dad")
	var facing := -1 if direction < 0 else 1
	draw_rect(Rect2(-6, -30, 12, 30), color, false, 1)
	draw_line(Vector2(0, -muzzle_height), Vector2(facing * 12, -muzzle_height), color, 2)
	if pending_attack: draw_circle(Vector2(0, -38), 2, Color("e5b566"))
	draw_string(ThemeDB.fallback_font, Vector2(-29, -45), "BULLET / RETURN", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, color)
	draw_string(ThemeDB.fallback_font, Vector2(-23, 13), "S %d  R %d" % [shots, returned], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, color)
