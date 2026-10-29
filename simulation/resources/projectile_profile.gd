extends Resource
## Role-neutral authored carrier/aim/response configuration. No action clock.
@export var muzzle_offset := Vector2(15,-22):
	set(value):
		if muzzle_offset == value: return
		muzzle_offset = value
		emit_changed()
@export var speed := 245.0:
	set(value):
		if speed == value: return
		speed = value
		emit_changed()
@export var radius := 3.0:
	set(value):
		if radius == value: return
		radius = value
		emit_changed()
@export var lifetime_seconds := 2.2:
	set(value):
		if lifetime_seconds == value: return
		lifetime_seconds = value
		emit_changed()
@export_flags_2d_physics var outbound_mask := 41:
	set(value):
		if outbound_mask == value: return
		outbound_mask = value
		emit_changed()
@export_flags_2d_physics var reflected_mask := 41:
	set(value):
		if reflected_mask == value: return
		reflected_mask = value
		emit_changed()
@export_flags_2d_physics var obstruction_mask := 9:
	set(value):
		if obstruction_mask == value: return
		obstruction_mask = value
		emit_changed()
## Optional authored release gate; the physical carrier still owns all flight.
@export var require_clear_aim_on_release := false:
	set(value):
		if require_clear_aim_on_release == value: return
		require_clear_aim_on_release = value
		emit_changed()
@export var return_minimum_damage := 2.0:
	set(value):
		if return_minimum_damage == value: return
		return_minimum_damage = value
		emit_changed()
@export var outbound_impulse := Vector2(135,-65):
	set(value):
		if outbound_impulse == value: return
		outbound_impulse = value
		emit_changed()
@export var return_impulse := Vector2(100,-45):
	set(value):
		if return_impulse == value: return
		return_impulse = value
		emit_changed()
@export var return_stun_seconds := 0.5:
	set(value):
		if return_stun_seconds == value: return
		return_stun_seconds = value
		emit_changed()
@export var outbound_blockable := true:
	set(value):
		if outbound_blockable == value: return
		outbound_blockable = value
		emit_changed()
@export var outbound_parryable := true:
	set(value):
		if outbound_parryable == value: return
		outbound_parryable = value
		emit_changed()
@export var outbound_rollable := true:
	set(value):
		if outbound_rollable == value: return
		outbound_rollable = value
		emit_changed()
@export var reflectable := true:
	set(value):
		if reflectable == value: return
		reflectable = value
		emit_changed()
@export var return_blockable := false:
	set(value):
		if return_blockable == value: return
		return_blockable = value
		emit_changed()
@export var return_parryable := false:
	set(value):
		if return_parryable == value: return
		return_parryable = value
		emit_changed()
@export var return_rollable := false:
	set(value):
		if return_rollable == value: return
		return_rollable = value
		emit_changed()
@export var release_pose: StringName = &"projectile":
	set(value):
		if release_pose == value: return
		release_pose = value
		emit_changed()
@export var release_charge_role: StringName = &"":
	set(value):
		if release_charge_role == value: return
		release_charge_role = value
		emit_changed()
@export var warning_kind: StringName = &"projectile_warning":
	set(value):
		if warning_kind == value: return
		warning_kind = value
		emit_changed()
@export var warning_loudness := 0.8:
	set(value):
		if warning_loudness == value: return
		warning_loudness = value
		emit_changed()
@export var release_kind: StringName = &"projectile_release":
	set(value):
		if release_kind == value: return
		release_kind = value
		emit_changed()
@export var release_loudness := 1.0:
	set(value):
		if release_loudness == value: return
		release_loudness = value
		emit_changed()
func snapshot() -> Dictionary:
	var value := {}
	for field in get_property_list():
		if int(field.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: value[field.name] = get(field.name)
	return value
func valid() -> bool:
	for value in [speed, radius, lifetime_seconds]:
		if not is_finite(value) or value <= 0: return false
	for value in [return_minimum_damage, return_stun_seconds, warning_loudness, release_loudness]:
		if not is_finite(value) or value < 0: return false
	return muzzle_offset.is_finite() and outbound_impulse.is_finite() and return_impulse.is_finite() and not release_pose.is_empty()
