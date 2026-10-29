extends "res://demo/components/shared_sentinel.gd"
## Ranged presentation/host facade. All physical authority stays in components.
signal projectile_launched(enemy: Node2D, projectile: Node2D)
@export var projectile_speed := 245.0
@export var preferred_distance := 170.0
@export var minimum_distance := 115.0
@export var projectile_lifetime := 2.2
@export var reflected_damage := 2.0
var shots_fired := 0
var projectile_epoch: int:
	get: return get_node("ProjectileEmitter")._binding
var _aim_point: Vector2:
	get: return get_node("ProjectileEmitter").pending_aim_snapshot().get("aim",global_position + Vector2(facing * 400,-20))
var _shot_views: Array[WeakRef] = []
var _observed_emission_serial := -1
func _ready() -> void:
	super._ready()
	var emitter := get_node("ProjectileEmitter")
	emitter.profile.speed = projectile_speed
	emitter.profile.lifetime_seconds = projectile_lifetime
	emitter.profile.return_minimum_damage = reflected_damage
	emitter.projectile_emitted.connect(_on_projectile_emitted)
func _on_projectile_emitted(receipt: Dictionary) -> void:
	var emitter := get_node("ProjectileEmitter")
	if receipt != emitter.last_receipt or receipt.get("source_id") != get_instance_id() or receipt.get("source_epoch") != damage_generation() or int(receipt.get("serial",-1)) <= _observed_emission_serial: return
	var carrier := instance_from_id(int(receipt.get("carrier_id",0))) as Node2D
	if not is_instance_valid(carrier) or carrier.is_queued_for_deletion(): return
	_observed_emission_serial = receipt.serial
	shots_fired += 1
	carrier.visible = not blind_mode
	_shot_views.append(weakref(carrier))
	carrier.resolved.connect(_on_projectile_resolved.bind(damage_generation()))
	carrier.retired.connect(_on_projectile_retired)
	projectile_launched.emit(self,carrier)
func _on_projectile_resolved(_carrier: Node2D, result: Dictionary, generation: int) -> void:
	# A completed lethal return is still true after same-life source defeat.
	# Reset cannot leak that observation into the new life.
	if generation != damage_generation(): return
	last_attack_result = result.duplicate(true)
	attack_resolved.emit(self,last_attack_result.duplicate(true))
func _on_projectile_retired(carrier: Node2D, _reason: StringName) -> void:
	for index in range(_shot_views.size()-1,-1,-1):
		var existing: Variant = _shot_views[index].get_ref()
		if not is_instance_valid(existing) or existing == carrier: _shot_views.remove_at(index)
func set_blind_mode(value: bool) -> void:
	super.set_blind_mode(value)
	for reference in _shot_views:
		var carrier: Variant = reference.get_ref()
		if is_instance_valid(carrier): carrier.visible = not value
