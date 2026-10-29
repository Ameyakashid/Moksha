extends Node2D
## Authored mission view observes the shared controller; it never drives it.
func _draw() -> void:
	var actor := get_parent()
	var alpha := 1.0
	if actor.blind_mode: alpha = clampf(actor.reveal_remaining / 0.2, 0.0, 1.0)
	if alpha <= 0.0: return
	var color := Color(actor.archetype_profile.tint, alpha)
	if actor.dead:
		color.a *= clampf(1.0 - actor._death_elapsed / 0.9, 0.0, 1.0)
		draw_line(Vector2(-12, -3), Vector2(10, -3), color, 1.5)
		draw_circle(Vector2(13, -5), 4, color, false, 1.3)
		return
	if actor._damage_flash > 0: color = Color(1.0, 0.97, 0.86, alpha)
	var f := float(actor.facing)
	var sway := sin(float(Time.get_ticks_msec()) * 0.018) * minf(absf(actor.velocity.x) * 0.025, 2.0)
	var lean := clampf(actor.velocity.x / 95.0, -1.0, 1.0) * 2.0
	var head := Vector2(lean, -31)
	draw_circle(head, 4.8, color, false, 1.3)
	draw_line(head + Vector2(f * 2, -1), head + Vector2(f * 6, -1), color, 1.4)
	draw_polyline(PackedVector2Array([Vector2(-5, -25), Vector2(5, -25), Vector2(4, -13), Vector2(-4, -13), Vector2(-5, -25)]), color, 1.2)
	draw_line(Vector2(-3, -13), Vector2(-5 - sway, 0), color, 1.4)
	draw_line(Vector2(3, -13), Vector2(5 + sway, 0), color, 1.4)
	var hand := Vector2(f * 10, -20)
	if actor.ai_state == &"windup": hand = Vector2(-f * 9, -27)
	if actor.ai_state == &"active": hand = Vector2(f * 18, -22)
	draw_line(Vector2(f * 4, -24), hand, color, 1.5)
	draw_line(hand + Vector2(-f * 5, 6), hand + Vector2(f * (22 if actor.kind == "warden" else 15), -4), color, 1.5)
	if actor.archetype_profile.ear_marker:
		draw_arc(head, 8.0, -0.8, 0.8, 8, color, 1.2)
	elif actor.kind == "warden":
		draw_polyline(PackedVector2Array([Vector2(-6, -35), Vector2(-5, -42), Vector2(0, -38), Vector2(5, -42), Vector2(6, -35)]), color, 1.5)
		draw_line(Vector2(-8, -26), Vector2(8, -26), color, 2.8)
	if actor.ai_state == &"windup":
		var charge := clampf(actor._phase_elapsed / actor._windup, 0.0, 1.0)
		draw_arc(Vector2(0, -22), 21, -PI * 0.5, -PI * 0.5 + TAU * charge, 28, Color(1, 0.48, 0.32, alpha), 1.6)
		draw_string(ThemeDB.fallback_font, Vector2(-2, -48), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.72, 0.42, alpha))
	elif actor.ai_state == &"active":
		draw_line(Vector2(f * 9, -22), Vector2(f * (actor._reach + 4), -22), Color(1, 0.83, 0.6, alpha), 2.0)
	if actor.health < actor.get_node("Health").capacity:
		draw_line(Vector2(-12, -48), Vector2(12, -48), Color(color, alpha * 0.2), 2.0)
		draw_line(Vector2(-12, -48), Vector2(-12 + 24 * actor.health / actor.get_node("Health").capacity, -48), color, 2.0)
