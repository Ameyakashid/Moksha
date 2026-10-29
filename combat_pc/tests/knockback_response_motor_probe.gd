extends "res://combat_pc/fixtures/knockback_target.gd"
## Explicit integration hook probe; calls stock motor once, then test callback.
var impulse_hook: Callable
var observed_impulses := 0

func apply_impulse(impulse: Vector2, seconds: float = 0.14) -> void:
	super.apply_impulse(impulse, seconds)
	observed_impulses += 1
	if impulse_hook.is_valid(): impulse_hook.call()
