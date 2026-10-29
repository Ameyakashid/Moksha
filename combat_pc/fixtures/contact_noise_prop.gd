extends "res://prop.gd"
## Uses the existing physical prop/launch implementation with a wireframe view.
## This inspection instance delegates noise exclusively to its optional child.
@export var wire_color := Color("e6c69a")

func _ready() -> void:
	super._ready()
	sprite.visible = false
	queue_redraw()

func _emit_noise(_at: Vector2, _kind: StringName, _loudness: float = 1.0) -> void:
	# Avoid a second legacy autoload route on this explicitly composed instance.
	pass

func _draw() -> void:
	draw_rect(Rect2(-14,-14,28,28),wire_color,false,1.2)
	draw_line(Vector2(-14,-14),Vector2(14,14),wire_color,0.8)
	draw_line(Vector2(-14,14),Vector2(14,-14),wire_color,0.8)
