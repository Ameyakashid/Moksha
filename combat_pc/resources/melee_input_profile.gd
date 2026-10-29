class_name MokshaMeleeInputProfile
extends Resource
## Optional, original MOKSHA input policy. The reference distinguishes held
## chaining and charge but does not recover these clocks or admission rules.
enum Mode { FRESH_ONLY, HELD_REPEAT, HELD_CHARGE }
@export var mode: Mode = Mode.FRESH_ONLY
@export var repeat_restart_seconds := 0.08
@export_category("Explicit starter then held charge / authored seconds")
@export var charge_starter: MokshaMeleeStepProfile
@export var charge_strike: MokshaMeleeStepProfile
@export var charge_branch_recovery_seconds := 0.06
@export var charge_seconds := 0.45
@export var charge_move_scale := 0.35
@export var charge_allow_turn := true

func snapshot() -> MokshaMeleeInputProfile:
	if mode < Mode.FRESH_ONLY or mode > Mode.HELD_CHARGE: return null
	for value in [repeat_restart_seconds, charge_branch_recovery_seconds, charge_seconds, charge_move_scale]:
		if not is_finite(value) or value < 0: return null
	if mode == Mode.HELD_REPEAT and repeat_restart_seconds < 0.001: return null
	if mode == Mode.HELD_CHARGE:
		if charge_seconds < 0.001 or charge_starter == null or charge_strike == null: return null
		if not charge_starter.is_valid_step(1) or not charge_strike.is_valid_step(1): return null
		if charge_starter.next_step != -1 or charge_strike.next_step != -1: return null
		if charge_branch_recovery_seconds >= charge_starter.recovery_seconds: return null
	return duplicate(true)
