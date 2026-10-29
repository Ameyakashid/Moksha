extends "res://demo/components/sentinel_view.gd"
## Read-only authored preview of the controller's actual committed rectangle.
func _draw() -> void:
	super._draw()
	var actor := get_parent()
	if actor.dead: return
	var alpha := clampf(actor.reveal_remaining / 0.2, 0.0, 1.0) if actor.blind_mode else 1.0
	if alpha <= 0: return
	var gold := Color(1.0, 0.72, 0.38, alpha)
	if actor.pressure_phase:
		draw_line(Vector2(-9, -39), Vector2(-12, -44), gold, 1.8)
		draw_line(Vector2(9, -39), Vector2(12, -44), gold, 1.8)
		draw_circle(Vector2(0, -21), 2.5, gold, false, 1.3)
	if not actor.is_braced(): return
	var brace := Color(1, 0.90, 0.64, alpha) if actor._brace_flash > 0 else gold
	draw_polyline(PackedVector2Array([Vector2(-11, -23), Vector2(-8, -29), Vector2(8, -29), Vector2(11, -23)]), brace, 2.2)
	draw_line(Vector2(-10, -1), Vector2(-3, -1), brace, 2.4)
	draw_line(Vector2(3, -1), Vector2(10, -1), brace, 2.4)
	var plan: Dictionary = actor.attack_plan_snapshot()
	if plan.phase == &"windup":
		var charge := clampf(float(plan.elapsed) / float(plan.windup_seconds), 0, 1)
		draw_rect(plan.rect, Color(1, 0.54, 0.30, alpha * (0.18 + charge * 0.30)), false, 1.0)
		if plan.step_index == 1: draw_line(Vector2(-plan.facing * 9, -30), Vector2(-plan.facing * 24, -39), brace, 1.5)
	else:
		draw_rect(plan.rect, Color(1, 0.72, 0.38, alpha * 0.12), true)
		draw_rect(plan.rect, Color(1, 0.85, 0.57, alpha * 0.90), false, 1.4)
