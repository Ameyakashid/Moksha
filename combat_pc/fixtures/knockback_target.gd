extends "res://movement/components/movement_motor.gd"
## Passive review composition around the unchanged NPC/test motor. No AI.
## The optional receiver changes velocity; stock motor owns all movement.

func _ready() -> void:
	super._ready()
	# Step before the PC's priority-0 strike dispatch so both existing pause
	# clocks start decrementing on the callback AFTER contact.
	process_physics_priority=-10
	clear_intent()

func reset_at(at: Vector2) -> void:
	var response := get_node_or_null("Knockback")
	if is_instance_valid(response): response.reset_history()
	super.reset_at(at)
	var hurtbox := get_node_or_null("Hurtbox")
	if is_instance_valid(hurtbox): hurtbox.reset_target()

func _process(_dt: float) -> void:
	var hurtbox := get_node_or_null("Hurtbox")
	var visual := get_node_or_null("Visual")
	if is_instance_valid(hurtbox) and is_instance_valid(visual):
		# Reuse the original receiver's confirmed-contact flash clock.
		visual.tint=Color("fff1cf") if hurtbox.flash>0 else Color("e6b47e")
