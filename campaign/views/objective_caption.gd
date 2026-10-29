extends Node2D
## Caption-only child above doors/actors, still inside the blind-hidden paint tree.
func _process(_dt: float) -> void:queue_redraw()
static func placement(at: Vector2,width: float,font_size: int,canvas: Transform2D,viewport: Rect2) -> Dictionary:
	if viewport.size.x<=16 or absf(canvas.determinant())<.00001:return {"draw":false}
	# Cull by the real object's anchor BEFORE shifting text. Never pull distant
	# objective labels into the viewport to form a pile at either edge.
	if not viewport.grow(16).has_point(canvas*Vector2.ZERO):return {"draw":false}
	var local_box:=Rect2(at+Vector2(-3,-font_size),Vector2(width+6,font_size+4))
	var screen_box:Rect2=canvas*local_box
	var left:=viewport.position.x+8.0
	var right:=viewport.end.x-8.0
	var shift:=0.0
	if screen_box.size.x>right-left:shift=left-screen_box.position.x
	elif screen_box.position.x<left:shift=left-screen_box.position.x
	elif screen_box.end.x>right:shift=right-screen_box.end.x
	var baseline:Vector2=canvas.affine_inverse()*(canvas*at+Vector2(shift,0))
	return {"draw":true,"at":baseline,"screen_box":Rect2(screen_box.position+Vector2(shift,0),screen_box.size)}
func _draw() -> void:
	var o=get_parent().get_parent()
	var c:=Color("67e0be") if o.completed else Color("ffc278") if o.available else Color("bac7cd")
	var caption:String=o.label+(" ✓" if o.completed else " [LOCKED]" if not o.available else " [PROP]" if o.kind=="plate" else " [J]" if o.kind=="breaker" else " [E]")
	_label(Vector2(-60,-74 if o.kind=="rescue" else -54),caption,10,c)
	if o.kind=="route":_label(Vector2(-50,-66),("UNROUTED / TARGET %d"%o.target) if o.setting<0 else ("CIRCUIT %d / TARGET %d"%[o.setting,o.target]),9,c)
func _label(at: Vector2,text: String,size: int,color: Color) -> void:
	var font:=ThemeDB.fallback_font
	var width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var result:=placement(at,width,size,get_global_transform_with_canvas(),get_viewport_rect())
	if not result.draw:return
	var baseline:Vector2=result.at
	draw_rect(Rect2(baseline+Vector2(-3,-size),Vector2(width+6,size+4)),Color(.035,.065,.08,.92))
	draw_string(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
