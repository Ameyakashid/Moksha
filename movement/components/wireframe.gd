@tool
extends Node2D
## Deliberately unflipped coordinates: face is drawn directly from motor.facing.
@export var tint: Color = Color("69e2e8")
@export var actor_label: String = "PC"
@onready var motor: CharacterBody2D = get_parent()
func _process(_dt: float) -> void: queue_redraw()
func _draw() -> void:
	if not is_instance_valid(motor): return
	var face_value: Variant = motor.get("facing")
	var f := float(face_value) if face_value != null else 1.0
	var motion := Vector2.ZERO if Engine.is_editor_hint() else motor.velocity
	var state_name: String = "IDLE" if Engine.is_editor_hint() else String(motor.get("state"))
	var c := tint
	var lean := clampf(motion.x / 260.0, -1.0, 1.0) * 3.0
	var lower := 10.0 if state_name == "DASH" else 0.0
	# Collider outline is stationary; joint movement never changes collision.
	draw_rect(Rect2(-8,-36,16,36), Color(c,0.25), false, 1.0)
	draw_circle(Vector2(lean,-30+lower),5,c,false,1.4)
	draw_line(Vector2(lean,-25+lower),Vector2(0,-12),c,1.4)
	draw_line(Vector2(0,-12),Vector2(-6,0),c,1.4)
	draw_line(Vector2(0,-12),Vector2(6,0),c,1.4)
	draw_line(Vector2(lean,-23+lower),Vector2(f*11,-17+lower),c,1.4)
	# Face nose and heading chevron both follow authoritative input-facing.
	draw_line(Vector2(lean+f*3,-31+lower),Vector2(lean+f*8,-30+lower),Color.WHITE,2.0)
	draw_line(Vector2(f*14,-29),Vector2(f*21,-29),Color.WHITE,1.4)
	draw_polyline(PackedVector2Array([Vector2(f*18,-32),Vector2(f*21,-29),Vector2(f*18,-26)]),Color.WHITE,1.4)
	draw_line(Vector2.ZERO,Vector2(motion.x*0.07,0),Color("e6b75e"),1.5)
	draw_string(ThemeDB.fallback_font,Vector2(-8,-43),actor_label,HORIZONTAL_ALIGNMENT_LEFT,-1,9,c)
