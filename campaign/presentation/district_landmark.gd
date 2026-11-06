extends RefCounted
## Recessed, bolted environmental placards, never objective markers or supports.
## Drawing helpers only: no nodes, collisions, timers, input or simulation access.
const FontFace = preload("res://fonts/DejaVuSansMono.ttf")

static func paint(canvas: Node2D, at: Vector2, profile: Dictionary, palette: Resource, compact := false) -> void:
	if str(profile.get("label", "")).is_empty(): return
	canvas.draw_set_transform(at, 0, Vector2.ONE * .65)
	var size := Vector2(224, 104) if not compact else Vector2(92, 104)
	var dark: Color = palette.background.darkened(.38)
	var metal: Color = palette.panel.lerp(palette.edge, .16)
	var ink: Color = palette.edge.lerp(palette.practical, .18).darkened(.14)
	# Narrow wall cleats and visible corner bolts make this a flat attached sign.
	for x in [12.0, size.x - 16.0]:
		canvas.draw_rect(Rect2(x, -15, 4, 127), dark)
		canvas.draw_line(Vector2(x + 1, -15), Vector2(x + 1, 111), metal, 1)
	canvas.draw_rect(Rect2(Vector2(-3, -3), size + Vector2(6, 6)), dark)
	canvas.draw_rect(Rect2(Vector2.ZERO, size), metal)
	canvas.draw_rect(Rect2(Vector2(5, 5), size - Vector2(10, 10)), palette.background.lerp(palette.panel, .18))
	for x in [8.0, size.x - 8.0]:
		for y in [8.0, size.y - 8.0]:
			canvas.draw_circle(Vector2(x, y), 1.3, palette.edge.darkened(.3), true, -1, true)
	# Faded stencil: much dimmer than live objectives, enemies or hazard warnings.
	mark(canvas, Vector2(44, 51), str(profile.get("mark", "service")), ink)
	if not compact:
		canvas.draw_line(Vector2(83, 24), Vector2(83, 78), metal, 1)
		var label := str(profile.label)
		var font_size := 12
		while font_size > 8 and FontFace.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > 126:
			font_size -= 1
		canvas.draw_string(FontFace, Vector2(94, 56), label, HORIZONTAL_ALIGNMENT_LEFT, 126, font_size, ink)
		# Short engraved bars, not instructions, status indicators or route arrows.
		canvas.draw_rect(Rect2(95, 65, 44, 2), metal)
		canvas.draw_rect(Rect2(143, 65, 18, 2), metal)
	# A few fixed scratches add material, not per-frame noise or flicker.
	for i in 4:
		var x := 12.0 + float(posmod(int(profile.get("seed", 0)) + i * 47, int(size.x) - 29))
		canvas.draw_line(Vector2(x, 86 + i % 3), Vector2(x + 8, 85 + i % 3), Color(metal, .6), .6)
	canvas.draw_set_transform(Vector2.ZERO)

static func mark(c: Node2D, at: Vector2, kind: String, ink: Color) -> void:
	var line := 2.5
	match kind:
		"clinic":
			c.draw_rect(Rect2(at + Vector2(-6, -22), Vector2(12, 44)), ink)
			c.draw_rect(Rect2(at + Vector2(-22, -6), Vector2(44, 12)), ink)
			c.draw_rect(Rect2(at + Vector2(-3, -19), Vector2(6, 38)), ink.darkened(.14))
		"transit", "freight":
			c.draw_rect(Rect2(at + Vector2(-25, -17), Vector2(50, 30)), ink, false, line)
			for i in 3: c.draw_rect(Rect2(at + Vector2(-18 + i * 13, -11), Vector2(9, 11)), ink)
			c.draw_line(at + Vector2(-22, 20), at + Vector2(22, 20), ink, line)
			c.draw_line(at + Vector2(-22, 25), at + Vector2(22, 25), ink, 1)
		"records", "dispatch", "threshold":
			for i in 3:
				var p := at + Vector2(-19 + i * 6, -23 + i * 6)
				c.draw_rect(Rect2(p, Vector2(28, 35)), ink, false, line)
			for i in 3: c.draw_line(at + Vector2(-1, -3 + i * 6), at + Vector2(15, -3 + i * 6), ink, 1.4)
		"refuge", "home":
			c.draw_polyline(PackedVector2Array([at + Vector2(-25, -1), at + Vector2(0, -24), at + Vector2(25, -1)]), ink, line, true)
			c.draw_polyline(PackedVector2Array([at + Vector2(-18, -3), at + Vector2(-18, 24), at + Vector2(18, 24), at + Vector2(18, -3)]), ink, line, true)
			c.draw_rect(Rect2(at + Vector2(-5, 6), Vector2(10, 18)), ink)
		"heat", "press":
			c.draw_rect(Rect2(at + Vector2(-24, -23), Vector2(48, 46)), ink, false, line)
			for i in 5: c.draw_line(at + Vector2(-15 + i * 7, -15), at + Vector2(-15 + i * 7, 14), ink, 3)
		"water":
			for row in 3:
				var points := PackedVector2Array()
				for i in 7: points.append(at + Vector2(-25 + i * 8, -13 + row * 14 + (3 if i % 2 == 0 else -3)))
				c.draw_polyline(points, ink, line, true)
		"power", "governor", "network":
			c.draw_rect(Rect2(at + Vector2(-23, -17), Vector2(46, 34)), ink, false, 1.5)
			for i in 4:
				c.draw_line(at + Vector2(-13 + i * 9, -23), at + Vector2(-13 + i * 9, 23), ink, 2)
			c.draw_line(at + Vector2(-30, 0), at + Vector2(30, 0), ink, 3)
		"baffle", "loom":
			for i in 7:
				var h: float = 12.0 + (3 - absi(3 - i)) * 8
				c.draw_line(at + Vector2(-24 + i * 8, -h * .5), at + Vector2(-24 + i * 8, h * .5), ink, 3)
		"weather", "authority":
			c.draw_line(at + Vector2(0, -24), at + Vector2(0, 24), ink, 3)
			for i in 3:
				var w := 24.0 - i * 6.0
				c.draw_line(at + Vector2(-w, -14 + i * 12), at + Vector2(w, -14 + i * 12), ink, 2)
		"market", "exchange":
			c.draw_polyline(PackedVector2Array([at + Vector2(-25, -8), at + Vector2(-17, -23), at + Vector2(17, -23), at + Vector2(25, -8)]), ink, line, true)
			for i in 5: c.draw_rect(Rect2(at + Vector2(-25 + i * 10, -7), Vector2(7, 6)), ink)
			c.draw_rect(Rect2(at + Vector2(-20, 3), Vector2(40, 21)), ink, false, line)
		_:
			c.draw_rect(Rect2(at + Vector2(-22, -23), Vector2(44, 46)), ink, false, line)
			for i in 4: c.draw_line(at + Vector2(-14, -14 + i * 9), at + Vector2(14, -14 + i * 9), ink, 2)
