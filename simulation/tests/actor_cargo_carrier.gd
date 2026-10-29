extends AnimatableBody2D
## Authored moving-surface fixture, using the same early planned-pose schedule
## as the existing controller fixtures. Only this support's transform moves.
var travel := Vector2.ZERO
var spin := 0.0
var origin := Vector2.ZERO
var travelled := Vector2.ZERO
var turn := 0.0
func _ready() -> void:
	origin=position; sync_to_physics=false; collision_mask=0; process_physics_priority=-20
func _physics_process(dt: float) -> void:
	travelled+=travel*dt; turn+=spin*dt
	position=origin+travelled; rotation=turn
