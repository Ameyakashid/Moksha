extends Node2D
## Caption-only child above doors/actors, still inside the blind-hidden paint tree.
func _process(_dt: float) -> void:queue_redraw()
static func placement(at: Vector2,width: float,font_size: int,canvas: Transform2D,viewport: Rect2) -> Dictionary:
	return place_block(at,Vector2(width+6,font_size+4),font_size,canvas,viewport)

static func place_block(at:Vector2,size:Vector2,font_size:int,canvas:Transform2D,viewport:Rect2,safe_rect:Variant=null)->Dictionary:
	if viewport.size.x<=16 or absf(canvas.determinant())<.00001:return {"draw":false}
	# Cull the actual object BEFORE moving its caption. Never drag distant labels
	# into view, and move all caption lines together so edge clamping cannot stack them.
	if not viewport.grow(16).has_point(canvas*Vector2.ZERO):return {"draw":false}
	var bounds:Rect2=viewport if safe_rect==null else viewport.intersection(safe_rect)
	if bounds.size.x<=16 or bounds.size.y<=16:return {"draw":false}
	var local_box:=Rect2(at+Vector2(-3,-font_size),size)
	var screen_box:Rect2=canvas*local_box
	var left:=bounds.position.x+8.0
	var right:=bounds.end.x-8.0
	if safe_rect!=null and (screen_box.size.x>bounds.size.x-16 or screen_box.size.y>bounds.size.y-16):return {"draw":false}
	var shift:=Vector2.ZERO
	if screen_box.size.x>right-left:shift.x=left-screen_box.position.x
	elif screen_box.position.x<left:shift.x=left-screen_box.position.x
	elif screen_box.end.x>right:shift.x=right-screen_box.end.x
	if screen_box.position.y<bounds.position.y+8:shift.y=bounds.position.y+8-screen_box.position.y
	elif screen_box.end.y>bounds.end.y-8:shift.y=bounds.end.y-8-screen_box.end.y
	var baseline:Vector2=canvas.affine_inverse()*(canvas*at+shift)
	return {"draw":true,"at":baseline,"screen_box":Rect2(screen_box.position+shift,screen_box.size)}
static func describe(kind:String,label:String,completed:bool,available:bool,setting:int,target:int,optional:=false,controller:=false)->Dictionary:
	var detail:=""
	var color:=Color("67e0be") if completed else Color("ffc278") if available else Color("bac7cd")
	if completed:
		detail="COMPLETE" if kind!="route" else "MATCHED %d · "%setting+("E CHANGES ROUTE" if available else "INPUT LOCKED")
	elif not available:detail="LOCKED · COMPLETE PREREQUISITES"
	elif kind=="breaker":detail="J · STRIKE THE HOUSING"
	elif kind=="plate":detail="CARGO · SETTLE ON THE PLATE"
	elif kind=="route":detail=("UNROUTED" if setting<0 else "CIRCUIT %d"%setting)+" · E → %d · TARGET %d"%[(setting+1)%3,target]
	else:detail="E · "+{"rescue":"RELEASE","recover":"RECOVER","install":"INSTALL"}.get(kind,"ACTIVATE")
	if optional:detail="OPTIONAL · "+detail
	if controller:
		detail=detail.replace("E CHANGES","Y CHANGES").replace("E →","Y →").replace("E ·","Y ·").replace("J ·","X ·")
		label=label.replace(" / J"," / X")
	return {"title":label,"detail":detail,"color":color,"completed":completed,"locked":not available and not completed}

func _draw() -> void:
	var o=get_parent().get_parent()
	var host:Variant=o.get("host")
	var navigation:Variant=host.get("gamepad_navigation") if is_instance_valid(host) else null
	var controller:bool=is_instance_valid(navigation) and navigation.get("input_device")=="controller"
	var description:=describe(o.kind,o.label,o.completed,o.available,o.setting,o.target,o.get("optional")==true,controller)
	var zoom:=maxf(.1,get_global_transform_with_canvas().x.length())
	# Keep text legible at gameplay zoom and bound captions in narrow viewports.
	var size:=clampi(roundi(10.0/zoom),7,18)
	var detail_size:=maxi(7,size-1)
	var width:=minf(300.0,(get_viewport_rect().size.x-24)/zoom)
	var lines:=_wrap(description.title,size,width)
	var detail_lines:=_wrap(description.detail,detail_size,width)
	var line_height:=size+3
	var total_height:=lines.size()*line_height+detail_lines.size()*(detail_size+3)
	var at:=Vector2(-60,(-78 if o.kind=="rescue" else -55)-total_height+line_height)
	var actual_width:=0.0
	for line in lines:actual_width=maxf(actual_width,ThemeDB.fallback_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x)
	for line in detail_lines:actual_width=maxf(actual_width,ThemeDB.fallback_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,detail_size).x)
	var safe:Variant=null
	var hud:Variant=host.get("hud") if is_instance_valid(host) else null
	if is_instance_valid(hud) and hud.has_method("caption_safe_rect"):safe=hud.caption_safe_rect()
	var placed:=place_block(at,Vector2(actual_width+6,total_height+4),size,get_global_transform_with_canvas(),get_viewport_rect(),safe)
	if not placed.draw:return
	at=placed.at
	for line in lines:
		_label(at,line,size,description.color);at.y+=line_height
	for line in detail_lines:
		_label(at,line,detail_size,description.color);at.y+=detail_size+3

static func _wrap(text:String,size:int,width:float)->Array[String]:
	var font:=ThemeDB.fallback_font
	var lines:Array[String]=[]
	var line:=""
	for word in text.split(" ",false):
		var next:=word if line.is_empty() else line+" "+word
		if font.get_string_size(next,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=width:line=next;continue
		if not line.is_empty():lines.append(line);line=""
		for letter in word:
			if not line.is_empty() and font.get_string_size(line+letter,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:lines.append(line);line=""
			line+=letter
	lines.append(line)
	return lines

func _label(at: Vector2,text: String,size: int,color: Color) -> void:
	var font:=ThemeDB.fallback_font
	var width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	var baseline:=at
	var box:=Rect2(baseline+Vector2(-3,-size),Vector2(width+6,size+4))
	draw_rect(box,Color(.018,.035,.048,.96))
	draw_line(box.position,box.position+Vector2(0,box.size.y),color,1)
	draw_string(font,baseline,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
