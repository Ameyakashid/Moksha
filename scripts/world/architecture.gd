@tool
extends Node2D
## Non-solid industrial wall dressing. Gameplay surfaces live in Terrain.
@export var dimensions: Vector2 = Vector2(180, 300):
	set(value):
		dimensions = value
		queue_redraw()
@export_enum("Street facade", "Service shaft", "Machine wall") var style: int = 0:
	set(value):
		style = value
		queue_redraw()
@export var seed_offset: int = 0:
	set(value):
		seed_offset = value
		queue_redraw()

func _draw() -> void:
	var w := dimensions.x
	var h := dimensions.y
	var base := Color("10242e") if style == 0 else Color("0b1821")
	draw_rect(Rect2(Vector2.ZERO, dimensions), base)
	draw_rect(Rect2(3, 3, w - 6, h - 6), Color("243842"), false, 2)
	for yy in range(12, int(h), 72):
		draw_rect(Rect2(6, yy, w - 12, 2), Color("31414a"))
		for xx in range(12, int(w - 12), 36):
			var warm := (xx / 36 + yy / 72 + seed_offset) as int % 5 == 0
			if style == 0:
				draw_rect(Rect2(xx, yy + 8, 22, 37), Color("07161f"))
				draw_rect(Rect2(xx + 2, yy + 10, 8, 32), Color("855c36") if warm else Color("19343e"))
				draw_rect(Rect2(xx + 12, yy + 10, 8, 32), Color("b78b56") if warm else Color("29434a"))
				draw_line(Vector2(xx, yy + 27), Vector2(xx + 22, yy + 27), Color("0d1f29"), 2)
			else:
				draw_rect(Rect2(xx, yy + 8, 23, 46), Color("152932"))
				draw_rect(Rect2(xx + 2, yy + 10, 19, 1), Color("31434c"))
				if warm: draw_rect(Rect2(xx + 9, yy + 18, 3, 10), Color("425f65"))
	for px in [w * 0.15, w * 0.81]:
		draw_line(Vector2(px + 2, 0), Vector2(px + 2, h), Color("050c13"), 7)
		draw_line(Vector2(px, 0), Vector2(px, h), Color("2d444b"), 4)
		for yy in range(24, int(h), 64):
			draw_rect(Rect2(px - 4, yy, 9, 3), Color("53626a"))
	if style == 1:
		draw_rect(Rect2(w * 0.45, 0, w * 0.1, h), Color("070f16"))
		for yy in range(18, int(h), 46):
			draw_rect(Rect2(w * 0.46, yy, w * 0.08, 8), Color("253942"))
			draw_rect(Rect2(w * 0.465, yy + 1, 2, 6), Color("438085"))
