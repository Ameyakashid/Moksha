extends "res://demo/views/hud_view.gd"
## Paint-only campaign panel. Wrap measured glyph widths rather than clipping lore/UI.
func panel_lines(text:String,size:int,width:=528.0)->Array[String]:
	var result:Array[String]=[]
	for paragraph in text.split("\n"):
		var line:=""
		for word in paragraph.split(" "):
			var next:=word if line.is_empty() else line+" "+word
			if not line.is_empty() and ThemeDB.fallback_font.get_string_size(next,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
				result.append(line);line=word
			else:line=next
		result.append(line)
	return result
func _panel(c:Node2D,title:String,body:String,footer:String)->void:
	c.draw_rect(Rect2(0,0,640,360),Color(0.015,0.03,0.045,0.96))
	c.draw_line(Vector2(54,77),Vector2(586,77),Color("567e85"),1)
	_text(c,title,Vector2(54,62),23,Color("e8d8bb"))
	var size:=12
	var lines:=panel_lines(body,size)
	while lines.size()*(size+3)>174 and size>9:
		size-=1;lines=panel_lines(body,size)
	var y:=100.0
	for line in lines:
		c.draw_string(ThemeDB.fallback_font,Vector2(54,y),line,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color("d8e7e6"));y+=size+3
	c.draw_line(Vector2(54,283),Vector2(586,283),Color("354e58"),1)
	_text(c,footer,Vector2(54,307),11,Color("b6d6d2"))
func _text(c:Node2D,text:String,p:Vector2,size:=10,color:=Color("d8e7e6"))->void:
	if text=="J combo   K guard/parry   Shift roll   Q tap   E use   R retry   Esc pause":
		text="J strike  K shield  Shift roll  Q tap  E use  TAB journal  R reset district  ESC pause"
	if p==Vector2(23,62) and size==10:
		var prose_size:=size
		var prose_lines:=panel_lines(text.replace("\n"," "),prose_size,594)
		while prose_lines.size()>3 and prose_size>8:
			prose_size-=1;prose_lines=panel_lines(text.replace("\n"," "),prose_size,594)
		for line in prose_lines:
			c.draw_string(ThemeDB.fallback_font,p,line,HORIZONTAL_ALIGNMENT_LEFT,-1,prose_size,color);p.y+=prose_size+5
		return
	for source_line in text.split("\n"):
		var line:String=source_line
		var width:=626.0-p.x
		while line.length()>1 and ThemeDB.fallback_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			line=line.left(line.length()-2)+"…"
		c.draw_string(ThemeDB.fallback_font,p,line,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
		p.y+=size+5
