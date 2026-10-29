extends "res://combat_pc/tests/health_regression.gd"
## Targeted reproduction; the same case is included in the full health suite.
func _run() -> void:
	await _queued_component_lifetime()
	print("HEALTH_QUEUE_FREE %dHz: %d checks, %d failures" % [hz, checks.size(), failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
