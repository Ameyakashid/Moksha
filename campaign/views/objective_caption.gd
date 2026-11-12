extends Node2D
## Caption-only child above doors/actors, still inside the blind-hidden paint tree.
func _process(_dt: float) -> void:queue_redraw()
static func placement(at: Vector2,width: float,font_size: int,canvas: Transform2D,viewport: Rect2) -> Dictionary:
	return place_block(at,Vector2(width+6,font_size+4),font_size,canvas,viewport)

static func place_block(at:Vector2,size:Vector2,font_size:int,canvas:Transform2D,viewport:Rect2,safe_rect:Variant=null,painted_rect:Variant=null,caption_side:Variant=null,avoid_rects:Array=[])->Dictionary:
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
	# First preserve the preferred above-object placement, unless HUD clamping
	# puts it over its own paint. Try whole-block alternatives, never line shifts.
	var placed_box:=Rect2(screen_box.position+shift,screen_box.size)
	if painted_rect!=null:
		var exclusion:Rect2=painted_rect.grow(4.0)
		# Optional authored presentation preference, never moving-player tracking.
		# Invalid hints or insufficient room preserve the existing default algorithm.
		if caption_side is String and caption_side=="left":
			var preferred:=Rect2(Vector2(exclusion.position.x-placed_box.size.x,placed_box.position.y),placed_box.size)
			if bounds.grow(-8).encloses(preferred) and not preferred.intersects(exclusion):
				placed_box=preferred;shift=preferred.position-screen_box.position
		if placed_box.intersects(exclusion):
			var inner:=bounds.grow(-8.0)
			var options:Array[Vector2]=[
				Vector2(placed_box.position.x,exclusion.position.y-placed_box.size.y),
				Vector2(exclusion.end.x,placed_box.position.y),
				Vector2(exclusion.position.x-placed_box.size.x,placed_box.position.y),
				Vector2(placed_box.position.x,exclusion.end.y)]
			var found:=false
			for position in options:
				var candidate:=Rect2(position,placed_box.size)
				if inner.encloses(candidate) and not candidate.intersects(exclusion):
					shift=candidate.position-screen_box.position;found=true;break
			if not found:return {"draw":false}
	# Notices are irregular occupied regions, not a taller global header. Keep
	# all lines together and test every candidate against all occupied regions.
	if not avoid_rects.is_empty():
		var occupied:Array[Rect2]=[]
		if painted_rect is Rect2:occupied.append(painted_rect.grow(4.0))
		for rect in avoid_rects:
			if rect is Rect2 and rect.has_area():occupied.append(rect.grow(4.0))
		var resolved:=avoid_occupied(Rect2(screen_box.position+shift,screen_box.size),bounds.grow(-8),occupied)
		if not resolved.draw:return {"draw":false}
		shift=resolved.box.position-screen_box.position
	var baseline:Vector2=canvas.affine_inverse()*(canvas*at+shift)
	return {"draw":true,"at":baseline,"screen_box":Rect2(screen_box.position+shift,screen_box.size)}

static func avoid_occupied(box:Rect2,inner:Rect2,occupied:Array[Rect2])->Dictionary:
	if _clear_box(box,inner,occupied):return {"draw":true,"box":box}
	var candidates:Array[Vector2]=[]
	var xs:Array[float]=[box.position.x,inner.position.x,inner.end.x-box.size.x]
	var ys:Array[float]=[box.position.y,inner.position.y,inner.end.y-box.size.y]
	for rect in occupied:
		candidates.append(Vector2(box.position.x,rect.position.y-box.size.y))
		candidates.append(Vector2(rect.end.x,box.position.y))
		candidates.append(Vector2(rect.position.x-box.size.x,box.position.y))
		candidates.append(Vector2(box.position.x,rect.end.y))
		xs.append(rect.position.x-box.size.x);xs.append(rect.end.x)
		ys.append(rect.position.y-box.size.y);ys.append(rect.end.y)
	# Corners handle simultaneous object + notice obstruction without sliding
	# a caption back through the other exclusion. Deterministic finite search.
	for y in ys:
		for x in xs:candidates.append(Vector2(x,y))
	for position in candidates:
		var candidate:=Rect2(position,box.size)
		if _clear_box(candidate,inner,occupied):return {"draw":true,"box":candidate}
	return {"draw":false}

static func _clear_box(box:Rect2,inner:Rect2,occupied:Array[Rect2])->bool:
	if not inner.encloses(box):return false
	for rect in occupied:
		if box.intersects(rect):return false
	return true

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
	var avoid:Array=[]
	if is_instance_valid(hud) and hud.has_method("caption_exclusion_rects"):avoid=hud.caption_exclusion_rects()
	var spec:Variant=o.get("specification")
	var side:Variant=spec.get("caption_side") if spec is Dictionary else null
	var placed:=place_block(at,Vector2(actual_width+6,total_height+4),size,get_global_transform_with_canvas(),get_viewport_rect(),safe,get_parent().caption_exclusion_rect(),side,avoid)
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
