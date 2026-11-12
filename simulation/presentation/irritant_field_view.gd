extends Node2D
## Original geometry; reads the field only. No immunity or timing authority.
var source: Node
func _draw() -> void:
	if not is_instance_valid(source): return
	var state: Dictionary = source.presentation()
	var size: Vector2 = state.size
	var box := Rect2(-size / 2, size)
	var color := Color("70b6bb")
	if state.live and state.phase == &"warning": color = Color("ffc66d")
	elif state.live and state.phase == &"active": color = Color("e9a4e8")
	# Solid base and labelled clear extent distinguish hardware from the aerosol.
	draw_rect(Rect2(Vector2(-12,size.y/2-14),Vector2(24,14)),Color("263c4b"))
	draw_rect(Rect2(Vector2(-12,size.y/2-14),Vector2(24,14)),color,false,2)
	if not state.live: return
	if state.phase == &"warning":
		draw_rect(box,color,false,1)
		for x in range(-int(size.x/2),int(size.x/2),16): draw_line(Vector2(x,size.y/2),Vector2(x+7,size.y/2-6),color,1)
		draw_line(Vector2(-size.x/2,size.y/2+4),Vector2(-size.x/2+size.x*state.fraction,size.y/2+4),color,3)
	elif state.phase == &"active":
		draw_rect(box,Color(color,0.12))
		draw_rect(box,color,false,2)
		for row in range(3):
			for col in range(5):
				var p := Vector2(-size.x/2+12+col*(size.x-24)/4,-size.y/2+10+row*(size.y-20)/2)
				draw_arc(p,6,0,PI*1.6,8,Color(color,0.65),1)
