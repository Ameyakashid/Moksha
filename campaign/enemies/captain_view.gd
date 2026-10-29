extends "res://demo/components/sentinel_view.gd"
## Presentation only; real event relay supplies both sight states' sound origins.
func _draw() -> void:
	super._draw()
	var actor := get_parent()
	if actor.dead: return
	var alpha := clampf(actor.reveal_remaining / 0.2, 0, 1) if actor.blind_mode else 1.0
	if alpha <= 0: return
	var f := float(actor.facing)
	var color := Color(actor.archetype_profile.tint, alpha)
	var length := 36.0 if actor.kind == "captain_lancer" else 51.0
	draw_line(Vector2(-f*12,-23),Vector2(f*length,-23),color,2)
	draw_colored_polygon(PackedVector2Array([Vector2(f*length,-27),Vector2(f*(length+8),-23),Vector2(f*length,-19)]),color)
	if actor.kind == "captain_keeper":
		draw_arc(Vector2(0,-31),9,PI,TAU,10,color,2)
	if actor.weapon_phase == &"windup":
		# Ground chevrons distinguish traveling charge from stationary thrust.
		var extent := 85.0 if actor.kind == "captain_lancer" else 40.0
		for i in 3:
			var x := f * (18 + extent * float(i)/3.0)
			draw_polyline(PackedVector2Array([Vector2(x-f*5,-5),Vector2(x,-2),Vector2(x-f*5,1)]),Color(1,0.65,0.3,alpha),1.5)
