extends "res://demo/components/enemy.gd"
## Integrating-host callback probe; real source contact still initiates motion.
var after_impulse: Callable
func apply_impulse(impulse: Vector2, seconds: float = 0.14) -> void:
	super.apply_impulse(impulse, seconds)
	if after_impulse.is_valid(): after_impulse.call()
