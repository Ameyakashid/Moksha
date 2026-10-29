extends "res://demo/components/shared_sentinel.gd"
## Authored encounter configuration and receipt-driven presentation only.
## The inherited controller, Health, contacts and intent scheduler own outcomes.
signal phase_changed(warden: Node2D, phase: int)
var pressure_phase := false
var braced_contacts := 0
var _brace_flash := 0.0
var _last_health_receipt: Dictionary = {}
var _authored_chain: MokshaMeleeChainProfile
var committed_attacks: int:
	get: return int(attack_plan_snapshot().fresh_chain_commits)
var attack_style: StringName:
	get: return &"sweep" if int(attack_plan_snapshot().step_index) == 1 else &"cut"
var _active_duration: float:
	get: return float(attack_plan_snapshot().active_seconds)
var _recovery: float:
	get: return float(attack_plan_snapshot().recovery_seconds)
var _attack_facing: int:
	get: return int(attack_plan_snapshot().facing)
func _configure_melee_tuning() -> void:
	super._configure_melee_tuning()
	if melee_chain == null or melee_chain.steps.size() != 2 or melee_chain.steps.any(func(step): return step == null): return
	_authored_chain = melee_chain
	# Both source steps are private, authored configuration for future actions.
	melee_chain.steps[1].windup_seconds = (windup_override if windup_override > 0 else archetype_profile.windup_seconds) * 1.30
	if attack_damage_override > 0: melee_chain.steps[1].damage = attack_damage_override
	_set_future_recoveries(false)
func _set_future_recoveries(pressure: bool) -> void:
	if not _authored_configuration_live(): return
	melee_chain.steps[0].recovery_seconds = 0.64 if pressure else 0.90
	melee_chain.steps[1].recovery_seconds = 0.80 if pressure else 1.10
func _authored_configuration_live() -> bool:
	return melee_chain != null and melee_chain == _authored_chain and melee_chain.steps.size() == 2 and melee_chain.is_valid_chain()
func is_braced() -> bool:
	return not dead and enabled and bool(hurt_response_snapshot().protected)
func attack_rect_local() -> Rect2:
	return attack_plan_snapshot().rect
func _health_receipt_current(store: Node, receipt: Dictionary) -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and can_process() and not get_tree().paused and enabled \
		and is_instance_valid(store) and store == _health and store == get_node_or_null("Health") and store.get_bound_actor() == self \
		and receipt.get("actor_id") == get_instance_id() and receipt.get("generation") == damage_generation() and store.damage_receipt_is_current(receipt)
func _on_health_receipt(receipt: Dictionary) -> void:
	var store: Node = _health
	if not _health_receipt_current(store, receipt) or is_same(receipt, _last_health_receipt): return
	var observation_binding := _hearing_binding
	var configuration_epoch: int = attack_plan_snapshot().configuration_epoch
	# Reserve exact real delivery before semantic noise can synchronously reenter.
	_last_health_receipt = receipt
	super._on_health_receipt(receipt)
	if observation_binding != _hearing_binding or configuration_epoch != int(attack_plan_snapshot().configuration_epoch) or not _authored_configuration_live() or not _health_receipt_current(store, receipt) or float(receipt.get("applied", 0)) <= 0: return
	if bool(receipt.get("braced", false)):
		braced_contacts += 1
		_brace_flash = 0.16
	if dead or pressure_phase or float(receipt.after) <= 0 or float(receipt.after) >= float(receipt.maximum) * 0.5: return
	pressure_phase = true
	var plan := attack_plan_snapshot()
	_set_future_recoveries(true)
	if bool(plan.committed):
		set_pending_recovery_duration(int(plan.serial), int(plan.configuration_epoch), 0.80 if int(plan.step_index) == 1 else 0.64)
	# No old-life work follows this externally observable callback.
	phase_changed.emit(self, 2)
func _on_mission_event(event: StringName, payload: Dictionary) -> void:
	if event == &"reset":
		pressure_phase = false
		braced_contacts = 0
		_brace_flash = 0.0
		_last_health_receipt = {}
		_set_future_recoveries(false)
	super._on_mission_event(event, payload)
func _process(dt: float) -> void:
	_brace_flash = maxf(0.0, _brace_flash - dt)
	super._process(dt)
