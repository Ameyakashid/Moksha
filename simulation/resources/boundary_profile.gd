class_name MokshaBoundaryProfile
extends Resource
## Authored world constraint response; no role-specific exemptions.
enum Damage { LETHAL_CURRENT_HEALTH, FIXED }
@export var damage_mode: Damage = Damage.LETHAL_CURRENT_HEALTH:
	set(value):
		if damage_mode != value: damage_mode = value; emit_changed()
@export var damage := 10.0:
	set(value):
		if damage != value: damage = value; emit_changed()
@export var stun_seconds := 0.0:
	set(value):
		if stun_seconds != value: stun_seconds = value; emit_changed()
func valid() -> bool:
	return damage_mode in [Damage.LETHAL_CURRENT_HEALTH, Damage.FIXED] and is_finite(damage) and damage >= 0.0 and is_finite(stun_seconds) and stun_seconds >= 0.0
