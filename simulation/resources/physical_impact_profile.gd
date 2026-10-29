extends Resource
## Authored response to real rigid contact; not a mass-conserving damage model.
@export var enabled := true
## Mission cargo requires a live launch/chain charge. Passive gym crates opt out.
@export var requires_charge := false
## Accepted defense (including parry/evade) can consume a fragile crate. A
## rejected/retired receiver never grants this break or any legacy damage.
@export var break_on_accepted_impact := false
@export var transfers_charge := true
@export_range(1.0, 2000.0, 1.0) var minimum_normal_speed := 80.0
@export_range(0.0, 1000.0, 0.1) var damage := 3.0
@export_range(0.0, 1000.0, 1.0) var response_speed := 180.0
@export_range(-1000.0, 1000.0, 1.0) var vertical_bias := -80.0
@export_range(0.0, 5.0, 0.01) var stun_seconds := 0.42
@export_range(0.0, 1.0, 0.01) var hitpause_seconds := 0.0
@export var blockable := true
@export var parryable := true
@export var rollable := true

func valid() -> bool:
	return is_finite(minimum_normal_speed) and minimum_normal_speed > 0.0 \
		and is_finite(damage) and damage >= 0.0 and is_finite(response_speed) and response_speed >= 0.0 \
		and is_finite(vertical_bias) and is_finite(stun_seconds) and stun_seconds >= 0.0 \
		and is_finite(hitpause_seconds) and hitpause_seconds >= 0.0
