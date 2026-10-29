extends Resource
## Per-instance permissions for the existing controller, independent of input source.
## This is not a second motion solver or the transient main-action capability map.
@export var can_move := true
@export var can_turn := true
@export var can_jump := true
@export var can_roll := true
@export var can_attack := true
@export var can_shield := true
@export var can_drop_through := true
@export var can_dive := true
@export var can_climb := true
@export var can_wall_run := false
@export var can_hear := true

func apply_to(actor: Node) -> void:
	actor.allow_shield = can_shield
	actor.allow_drop_through = can_drop_through
	actor.allow_dive = can_dive
	actor.allow_climb = can_climb
	actor.allow_wall_run = can_wall_run
	actor.set_weapon_permissions({"can_move": can_move, "can_turn": can_turn,
		"can_jump": can_jump, "can_roll": can_roll, "can_attack": can_attack,
		"can_shield": can_shield, "can_drop_through": can_drop_through,
		"can_dive": can_dive, "can_climb": can_climb, "can_wall_traverse": can_wall_run})
