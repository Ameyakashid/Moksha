extends Node2D
## Exact nonblocking ladder wardrobe. Original sensor and SonarRails stay intact.
var ladder: Node2D
func _process(_dt: float) -> void:queue_redraw()
func paint_geometry() -> Dictionary:
	if not is_instance_valid(ladder):return {}
	var rails := PackedVector2Array([Vector2(-ladder.width*.3,0),Vector2(-ladder.width*.3,-ladder.height),Vector2(ladder.width*.3,0),Vector2(ladder.width*.3,-ladder.height)])
	var rungs := PackedVector2Array()
	for y in range(4,ceili(ladder.height),12):
		rungs.append(Vector2(-ladder.width*.3,-y));rungs.append(Vector2(ladder.width*.3,-y))
	return {"rails":rails,"rungs":rungs}
func _draw() -> void:
	var geometry := paint_geometry()
	if geometry.is_empty():return
	var alpha := 1.0 if ladder.enabled else .35
	var shadow := Color("15252c");shadow.a=alpha
	var steel := Color("778d8c");steel.a=alpha
	var copper := Color("a5815e");copper.a=alpha
	for i in [0,2]:
		var a: Vector2=geometry.rails[i];var b: Vector2=geometry.rails[i+1]
		draw_line(a,b,shadow,3.2,true)
		draw_line(a,b,steel,1.8,true)
		draw_line(a+Vector2(.45,0),b+Vector2(.45,0),copper,.6,true)
	for i in range(0,geometry.rungs.size(),2):
		var a: Vector2=geometry.rungs[i];var b: Vector2=geometry.rungs[i+1]
		draw_line(a,b,shadow,3,true)
		draw_line(a,b,steel,1.8,true)
		# Restrained worn cap; no glowing blueprint lines or decorative fake rungs.
		draw_line(a+Vector2(1,-.4),b-Vector2(1,.4),copper,.55,true)
