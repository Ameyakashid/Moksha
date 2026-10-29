@tool
class_name MokshaGuardMeleeFixture
extends Area2D
## Stationary telescoping contact instrument, not an enemy or AI.
signal attack_resolved(result: Dictionary)
signal counter_received(payload: Dictionary)
@export_range(-1, 1, 2) var direction := -1:
	set(value):
		direction = -1 if value < 0 else 1
		queue_redraw()
@export var auto_attack := false
@export var simulation_enabled := true
@export var telegraph_seconds := 0.65
@export var active_seconds := 0.14
@export var cooldown_seconds := 1.4
@export var reach := 58.0
@export var contact_height := 17.0
@export var attack_damage := 10.0
@export var attack_impulse := Vector2(155, -105)
@export var blockable := true
@export var parryable := true
@export var counterable := true
@export var rollable := true
@export var accepts_counter := true
@export_flags_2d_physics var actor_mask := 2
@export_flags_2d_physics var terrain_mask := 1
var phase: StringName = &"cooldown"
var fixture_paused := false
var elapsed := 0.0
var attack_id := 0
var contacts := 0
var counters := 0
var damage_received := 0.0
var last_result: Dictionary = {}
var _tip := 8.0
var _retired := false
var _flash := 0.0
var _visited: Dictionary = {}

func _ready() -> void:
	process_physics_priority = 100
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 30)
	$Shape.shape = shape
	$Shape.position = Vector2(0, -15)
	elapsed = cooldown_seconds * 0.6

func request_attack() -> bool:
	if Engine.is_editor_hint(): return false
	return trigger_attack()

func trigger_attack() -> bool:
	if Engine.is_editor_hint(): return false
	if not simulation_enabled or fixture_paused or phase != &"cooldown": return false
	attack_id += 1
	phase = &"telegraph"
	elapsed = 0
	_tip = 8
	_retired = false
	_visited.clear()
	queue_redraw()
	return true

func _physics_process(dt: float) -> void:
	if Engine.is_editor_hint(): return
	if not simulation_enabled or fixture_paused: return
	_flash = maxf(0, _flash - dt)
	elapsed += dt
	if phase == &"cooldown":
		if auto_attack and elapsed >= cooldown_seconds: trigger_attack()
	elif phase == &"telegraph":
		if elapsed >= telegraph_seconds:
			phase = &"active"
			elapsed = 0
	elif phase == &"active":
		var next_tip := lerpf(8, maxf(8, reach), clampf(elapsed / maxf(0.001, active_seconds), 0, 1))
		_sweep_blade(_tip, next_tip, dt)
		_tip = next_tip
		if elapsed >= active_seconds:
			phase = &"cooldown"
			elapsed = 0
	queue_redraw()

func _sweep_blade(previous: float, current: float, dt: float) -> void:
	if _retired or current <= previous: return
	var facing := -1 if direction < 0 else 1
	var start := global_position + Vector2(facing * previous, -contact_height)
	var end := global_position + Vector2(facing * current, -contact_height)
	var query := PhysicsRayQueryParameters2D.create(start, end, actor_mask | terrain_mask, [get_rid()])
	query.hit_from_inside = true
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	_retired = true
	var target: Variant = hit.collider
	if not is_instance_valid(target) or not target.has_method("receive_attack"): return
	var identifier: int = target.get_instance_id()
	if _visited.has(identifier): return
	_visited[identifier] = true
	var payload := {"attack_id": attack_id, "source": self, "origin": start, "source_position": start, "contact_position": hit.position,
		"incoming_velocity": (end - start) / maxf(dt, 0.000001), "kind": &"melee", "amount": attack_damage,
		"impulse": Vector2(attack_impulse.x * facing, attack_impulse.y), "blockable": blockable, "parryable": parryable,
		"reflectable": false, "counterable": counterable, "rollable": rollable}
	last_result = target.receive_attack(payload)
	contacts += 1
	_flash = 0.25
	attack_resolved.emit(last_result.duplicate(true))

func get_shield_counter_hurtbox() -> CollisionObject2D:
	return self

func receive_shield_counter(payload: Dictionary) -> Dictionary:
	if not simulation_enabled or fixture_paused or not accepts_counter or is_queued_for_deletion(): return {"accepted": false, "reason": &"counter_receiver_disabled"}
	counters += 1
	damage_received += maxf(0, float(payload.get("damage", 0)))
	_flash = 0.3
	counter_received.emit(payload)
	queue_redraw()
	return {"accepted": true, "damage_applied": float(payload.get("damage", 0)), "contact_position": payload.get("counter_contact_position", global_position)}

func receive_strike(_payload: Dictionary) -> void:
	_flash = 0.2

func reset_fixture() -> void:
	phase = &"cooldown"
	elapsed = 0
	_tip = 8
	_retired = true
	_visited.clear()
	contacts = 0
	counters = 0
	damage_received = 0
	last_result.clear()
	queue_redraw()

func set_fixture_paused(paused: bool) -> void:
	if fixture_paused == paused: return
	fixture_paused = paused

func set_simulation_enabled(enabled: bool) -> void:
	if simulation_enabled == enabled: return
	simulation_enabled = enabled
	# Retire a windup/live strike on disable; resuming requires a fresh identity.
	if not enabled:
		phase = &"cooldown"
		elapsed = 0
		_retired = true
	queue_redraw()

func _draw() -> void:
	var color := Color("d6a956") if phase == &"telegraph" else Color("f0766d") if phase == &"active" else Color("738b99")
	if _flash > 0:
		color = Color("83e5be") if last_result.get("outcome") == &"parried" else Color("efc779") if last_result.get("outcome") == &"guarded" else Color("ef827f")
	draw_rect(Rect2(-6, -30, 12, 30), color, false, 1)
	draw_line(Vector2(-9, 0), Vector2(9, 0), color)
	var facing := -1 if direction < 0 else 1
	var length := _tip if phase == &"active" else 8.0
	draw_line(Vector2(0, -contact_height), Vector2(facing * length, -contact_height), color, 2)
	if phase == &"telegraph": draw_arc(Vector2(0, -17), 11, -PI * 0.5, -PI * 0.5 + TAU * clampf(elapsed / maxf(0.001, telegraph_seconds), 0, 1), 20, color, 1)
	draw_string(ThemeDB.fallback_font, Vector2(-26, -39), "MELEE  " + String(phase).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, color)
	draw_string(ThemeDB.fallback_font, Vector2(-23, 13), "H %d  C %d" % [contacts, counters], HORIZONTAL_ALIGNMENT_LEFT, -1, 7, color)
