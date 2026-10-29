extends Node2D
## Code-native metal baton, independent of the approved operative pose sheet.
## The body uses the real ready pose while this visible weapon swings and taps.

@export var length: float = 31.0
@export_range(0.0, 1.0, 0.05) var sweep_opacity: float = 0.2
var _sweep := 0.0
var tip: Vector2:
	get: return to_global(Vector2(length, 0))

func present_sweep(value: float) -> void:
	value = clampf(value, -1.0, 1.0)
	if is_equal_approx(value, _sweep): return
	_sweep = value
	queue_redraw()

func _draw() -> void:
	# A short, quiet metal glint follows only the moving part of a swing. It is
	# local to this visual weapon, so interruption/turning cannot leave a ghost.
	if absf(_sweep) > 0.01:
		var arc := -signf(_sweep) * 0.38
		var color := Color(0.75, 0.85, 0.88, absf(_sweep) * sweep_opacity)
		draw_arc(Vector2.ZERO, length - 2.0, minf(arc, 0.0), maxf(arc, 0.0), 10, color, 2.0, true)
	draw_line(Vector2(-5, 1), Vector2(length, 1), Color("111b25"), 5.0)
	draw_line(Vector2(-5, 0), Vector2(length, 0), Color("9dafba"), 3.0)
	draw_line(Vector2(4, -1), Vector2(length - 1, -1), Color("d9e3df"), 1.0)
	draw_line(Vector2(-5, 0), Vector2(4, 0), Color("29343b"), 4.0)
	for x in range(-4, 5, 3):
		draw_line(Vector2(x, -2), Vector2(x, 2), Color("56606a"), 1.0)
	draw_line(Vector2(length - 3, -1), Vector2(length - 3, 1), Color("d99a56"), 3.0)
