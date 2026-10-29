extends "res://simulation/components/patrol_intent_policy.gd"
## World observations request ordinary attack input. Physical contact and the
## shared controller decide the outcome; this policy never calls a receiver.
@export var attack_range := 42.0
@export var attack_interval := 0.65
var _attack_wait := 0.0
func reset_intent() -> void:
	super.reset_intent()
	_attack_wait = 0.0
func sample_intent(actor: Node2D, dt: float) -> Dictionary:
	_attack_wait = maxf(0, _attack_wait - dt)
	var intention := super.sample_intent(actor, dt)
	if not sees_target or not actor.grounded or actor.is_defeated(): return intention
	var target := get_node_or_null(target_path) as Node2D
	if not is_instance_valid(target): return intention
	var offset := target.global_position - actor.global_position
	if absf(offset.x) > attack_range: return intention
	var direction := -1 if offset.x < 0 else 1
	if actor.facing != direction:
		state = &"facing"
		reason = "Turn toward observed target through movement input"
		return {"move":Vector2(direction * 0.1,0)}
	if actor.weapon_phase == &"idle" and _attack_wait <= 0:
		_attack_wait = maxf(0.1,attack_interval)
		state = &"attacking"
		reason = "Visible target in configured request range"
		return {"attack":true}
	return {}
