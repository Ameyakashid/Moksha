extends "res://demo/views/hud_view.gd"
## Campaign-only read-only HUD. No input, simulation, sonar or checkpoint writes.
## Every prose block is measured before drawing, including long unbroken tokens.
const INK := Color("e5efee")
const QUIET := Color("a7bec5")
const ACCENT := Color("88d4cf")
const GOLD := Color("f2c68c")
const SURFACE := Color(.018,.035,.048,.96)
const LINE := Color("38535e")

func panel_lines(text:String,size:int,width:=528.0)->Array[String]:
	var result:Array[String]=[]
	var font:=ThemeDB.fallback_font
	for paragraph in text.split("\n"):
		var line:=""
		for word in paragraph.split(" ",false):
			var next:=word if line.is_empty() else line+" "+word
			if font.get_string_size(next,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=width:
				line=next
				continue
			if not line.is_empty():result.append(line);line=""
			# Authored IDs and unusually long words must never escape the panel.
			for letter in word:
				if not line.is_empty() and font.get_string_size(line+letter,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
					result.append(line);line=""
				line+=letter
		result.append(line)
	return result

func fit_text(text:String,size:int,width:float)->String:
	var font:=ThemeDB.fallback_font
	if font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=width:return text
	var shortened:=text
	while not shortened.is_empty() and font.get_string_size(shortened+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
		shortened=shortened.left(shortened.length()-1)
	return shortened+"…" if not shortened.is_empty() else ""

func panel_layout(title:String,body:String,footer:String)->Dictionary:
	var title_size:=23
	while title_size>16 and ThemeDB.fallback_font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x>532:
		title_size-=1
	var title_lines:=panel_lines(title,title_size,532)
	var body_top:=100.0+maxi(0,title_lines.size()-1)*(title_size+3)
	var body_size:=12
	var lines:=panel_lines(body,body_size)
	while lines.size()*(body_size+3)>276-body_top and body_size>9:
		body_size-=1;lines=panel_lines(body,body_size)
	return {"title_size":title_size,"title_lines":title_lines,"body_top":body_top,"body_size":body_size,"body_lines":lines,"footer_lines":panel_lines(footer_groups(footer),11,532)}

static func footer_groups(text:String)->String:
	# Repeated spaces mark separate command groups in authored footers. Only
	# separate a following key binding, not padding inside "J  PUBLIC RECORD".
	# Literal spaces cannot consume a line break or alter single-space prose.
	var separator:=RegEx.new()
	separator.compile("(?<=\\S) {2,}(?=(?:A|B|C|D|E|J|K|L|M|N|Q|R|S|W|X|Y|TAB|ESC|Enter|Esc|ENTER|SPACE|START|BACK|D-pad)(?:\\s|$))")
	return separator.sub(text," · ",true)

func _panel(c:Node2D,title:String,body:String,footer:String)->void:
	var controller:bool=data.get("input_device","keyboard")=="controller"
	body=device_text(body,controller)
	if controller:
		footer=controller_footer(str(data.get("state","")),footer)
	var layout:=panel_layout(title,body,footer)
	c.draw_rect(Rect2(0,0,640,360),SURFACE)
	c.draw_rect(Rect2(32,24,3,312),ACCENT)
	_text(c,_panel_eyebrow(),Vector2(54,34),9,QUIET)
	var title_y:=62.0
	for line in layout.title_lines:
		_text(c,line,Vector2(54,title_y),layout.title_size,GOLD);title_y+=layout.title_size+3
	c.draw_line(Vector2(54,layout.body_top-23),Vector2(586,layout.body_top-23),LINE,1)
	var y:float=layout.body_top
	for line in layout.body_lines:
		var color:=INK
		if line.begins_with("✓"):color=ACCENT
		elif line.begins_with("Next:") or line.begins_with("J  ") or line.begins_with("K  ") or line.begins_with("L  "):color=GOLD
		elif line.begins_with("Build:"):color=QUIET
		_text(c,line,Vector2(54,y),layout.body_size,color);y+=layout.body_size+3
	c.draw_line(Vector2(54,287),Vector2(586,287),LINE,1)
	y=309
	for line in layout.footer_lines:
		_text(c,line,Vector2(54,y),11,ACCENT);y+=15

func _panel_eyebrow()->String:
	match str(data.get("state","")):
		"journal":return "FIELD RECORDS / TIME PAUSED"
		"paused":return "TAKE A BREATH / TIME PAUSED"
		"upgrade":return "BUILD YOUR ASCENT / CHOICE PERSISTS"
		"choice":return "OPTIONAL EXCHANGE / TIME PAUSED"
		"final_choice":return "THE CROWN / YOUR DECISION"
		"dead":return "CHECKPOINT READY"
		"complete":return "CAMPAIGN COMPLETE"
	return "MOKSHA / FIVE ASCENTS"

func render_snapshot(c:Node2D)->void:
	if bool(data.get("panel_override",false)):
		if data.get("state","")=="title" and data.get("panel_title","")=="MOKSHA / FIVE ASCENTS":_title(c)
		elif data.get("state","")=="paused":_pause(c)
		else:_panel(c,str(data.panel_title),str(data.panel_body),str(data.panel_footer))
		return
	if data.get("state","") in ["title","intro"] or not bool(data.get("player_present",false)):
		super.render_snapshot(c);return
	if data.get("state","")!="playing":
		super.render_snapshot(c);return
	var layout:=playing_layout(data)
	_draw_header(c,layout)
	if bool(data.get("chapter_visible",false)) and not layout.context_notice:_draw_chapter(c,layout.header_height+7)
	_draw_context(c,layout)
	_draw_controls(c)

func playing_layout(snapshot:Dictionary)->Dictionary:
	var guidance:=device_text(str(snapshot.get("guidance",snapshot.get("objective","Reach the onward door [E]"))),snapshot.get("input_device","keyboard")=="controller")
	var guide_lines:=panel_lines(guidance,11,563)
	var header_height:=43.0+guide_lines.size()*14
	var context:=context_layout(snapshot,header_height)
	var current:=maxf(0,float(snapshot.get("health_current",0)))
	var capacity:=maxf(1,float(snapshot.get("health_capacity",60)))
	context.merge({"guidance":guide_lines,"header_height":header_height,"health_ratio":clampf(current/capacity,0,1),"health_current":ceili(current),"health_capacity":roundi(capacity),"low_health":current>0 and current/capacity<=.3})
	return context

func context_layout(snapshot:Dictionary,header_height:float)->Dictionary:
	var notice:=bool(snapshot.get("notice_visible",false)) and not str(snapshot.get("notice","")).is_empty()
	var text:String=str(snapshot.get("notice","")) if notice else str(snapshot.get("prompt",""))
	text=device_text(text,snapshot.get("input_device","keyboard")=="controller")
	var size:=11 if notice else 10
	var width:=300.0 if notice else 616.0
	var lines:Array[String]=[]
	if not text.is_empty():lines=panel_lines(text,size,width-28)
	# Short notices live in the upper right. Grow only enough to retain the full
	# authored prose in two lines, never across the operator's feet at y300.
	while notice and lines.size()>2 and width<616:
		width=minf(616,width+16);lines=panel_lines(text,size,width-28)
	var truncated:=lines.size()>2
	if truncated:
		var remainder:=" ".join(lines.slice(1))
		lines.resize(2);lines[1]=fit_text(remainder,size,width-28)
	var line_height:=size+3
	var height:=float(lines.size()*line_height+(12 if notice else 6)) if not lines.is_empty() else 0.0
	return {"context":lines,"context_notice":notice,"context_size":size,"context_x":628.0-width,"context_width":width,"context_height":height,"context_top":header_height+7 if notice else 337.0-height,"context_truncated":truncated}

func pause_controls(controller:=false)->Array[Dictionary]:
	# Explicit coordinates, not spacing inside prose. Labels cannot fuse when a
	# font changes, and each action has its own unambiguous keyboard key group.
	var columns:=[
		[["A/D · arrows","Move"],["Space / C","Jump, then air jump"],["W / S","Climb ladders"],["S + Space","Drop / dive"],["Shift","Roll"]],
		[["J","Fresh-tap strike combo"],["K","Raise / hold shield"],["Q","Sound tap"],["E","Use / interact"],["TAB","Field journal"],["M","Mute"]]
	]
	if controller:
		columns=[
			[["Stick / D-pad","Move"],["A","Jump, then air jump"],["Up / down","Climb ladders"],["Down + A","Drop / dive"],["RB","Roll"]],
			[["X","Fresh-tap strike combo"],["LB","Raise / hold shield"],["B","Sound tap"],["Y","Use / interact"],["BACK","Field journal"]]
		]
	var result:Array[Dictionary]=[]
	for column in columns.size():
		for row in columns[column].size():
			var x:=54.0 if column==0 else 334.0
			var key_width:=82.0 if column==0 else 42.0
			result.append({"key":columns[column][row][0],"action":columns[column][row][1],"key_box":Rect2(x,108+row*21, key_width,17),"action_at":Vector2(x+key_width+10,120+row*21),"action_width":166.0 if column==0 else 200.0})
	return result

func _pause(c:Node2D)->void:
	_panel(c,"PAUSED","","")
	_text(c,"MOVEMENT",Vector2(54,97),10,ACCENT)
	_text(c,"COMBAT / FIELD TOOLS",Vector2(334,97),10,ACCENT)
	c.draw_line(Vector2(320,90),Vector2(320,233),LINE,1)
	var controller:bool=data.get("input_device","keyboard")=="controller"
	for row in pause_controls(controller):
		var box:Rect2=row.key_box
		c.draw_rect(box,Color("152e39"))
		c.draw_rect(box,LINE,false,1)
		_text(c,row.key,box.position+Vector2(6,12),9,GOLD)
		_text(c,row.action,row.action_at,11,INK)
	_text(c,("X" if controller else "R")+" resets this district's objectives, guards and cargo.",Vector2(54,257),11,QUIET)
	_text(c,"Your build, sight choice and archives are kept.",Vector2(54,274),11,QUIET)
	_text(c,"START / B  Resume" if controller else "ESC  Resume",Vector2(54,309),11,ACCENT)
	_text(c,"X  Reset district" if controller else "R  Reset district",Vector2(250,309),11,GOLD)
	_text(c,"Y  Title" if controller else "N  Title",Vector2(490,309),11,QUIET)

func _draw_header(c:Node2D,layout:Dictionary)->void:
	c.draw_rect(Rect2(0,0,640,layout.header_height),SURFACE)
	c.draw_line(Vector2(0,layout.header_height),Vector2(640,layout.header_height),LINE,1)
	_text(c,fit_text(str(data.get("sector_title","")),11,398),Vector2(14,16),11,GOLD)
	var detail:=("SIGHT TRADED · B TAP" if data.get("input_device","")=="controller" else "SIGHT TRADED · Q TAP") if bool(data.get("blind",false)) else "SIGHT INTACT"
	if data.has("lens"):detail+=" · "+str(data.lens).to_upper()
	if data.has("district_index"):detail+=" · DISTRICT %d/%d"%[int(data.district_index),int(data.get("district_count",32))]
	if int(data.get("required_total",0))>0:detail+=" · GOALS %d/%d"%[int(data.get("required_done",0)),int(data.required_total)]
	_text(c,fit_text(detail,9,400),Vector2(14,30),9,QUIET)
	var health_color:=GOLD if layout.low_health else ACCENT
	_text(c,("LOW " if layout.low_health else "HP ")+"%d/%d"%[layout.health_current,layout.health_capacity],Vector2(438,16),10,health_color)
	c.draw_rect(Rect2(438,23,113,6),Color("263b45"))
	c.draw_rect(Rect2(438,23,113*layout.health_ratio,6),health_color)
	for tick in range(1,5):c.draw_line(Vector2(438+113*tick/5.0,23),Vector2(438+113*tick/5.0,29),SURFACE,1)
	var elapsed:=maxi(0,int(data.get("elapsed",0)))
	_text(c,"%02d:%02d"%[elapsed/60,elapsed%60],Vector2(575,16),10,INK)
	_text(c,"ACTIVE",Vector2(575,29),8,QUIET)
	_text(c,"NEXT",Vector2(14,47),9,ACCENT)
	var y:=47.0
	for line in layout.guidance:
		_text(c,line,Vector2(63,y),11,INK);y+=14

func _draw_chapter(c:Node2D,top:float)->void:
	var prose:=panel_lines(device_text(str(data.get("sector_text","")).replace("\n"," "),data.get("input_device","")=="controller"),11,584)
	var hints:=panel_lines(device_text(str(data.get("sector_hint","")),data.get("input_device","")=="controller"),10,584)
	var height:=float(prose.size()*14+hints.size()*13+24)
	c.draw_rect(Rect2(12,top,616,height),Color(.018,.035,.048,.91))
	c.draw_rect(Rect2(12,top,2,height),ACCENT)
	var y:=top+16
	for line in prose:_text(c,line,Vector2(26,y),11,INK);y+=14
	y+=7
	for line in hints:_text(c,line,Vector2(26,y),10,GOLD);y+=13

func _draw_context(c:Node2D,layout:Dictionary)->void:
	if layout.context.is_empty():return
	var color:=ACCENT if layout.context_notice and "COMPLETE" in str(data.get("notice","")) else GOLD
	c.draw_rect(Rect2(layout.context_x,layout.context_top,layout.context_width,layout.context_height),SURFACE)
	c.draw_rect(Rect2(layout.context_x,layout.context_top,3,layout.context_height),color)
	var y:float=layout.context_top+(15 if layout.context_notice else 12)
	for line in layout.context:
		_text(c,line,Vector2(layout.context_x+14,y),layout.context_size,color);y+=layout.context_size+3

func _draw_controls(c:Node2D)->void:
	c.draw_rect(Rect2(0,339,640,21),SURFACE)
	c.draw_line(Vector2(0,339),Vector2(640,339),LINE,1)
	if data.get("input_device","keyboard")=="controller":
		_text(c,"Stick / D-pad move   A jump   X strike   LB guard   RB roll   B sonar   Y use",Vector2(14,353),9,QUIET)
		_text(c,"BACK journal   START pause",Vector2(478,353),9,ACCENT)
	else:
		_text(c,"A/D move   Space jump   J strike   K guard   Shift roll   Q tap   E use",Vector2(14,353),9,QUIET)
		_text(c,"TAB journal   ESC pause",Vector2(503,353),9,ACCENT)

func _title(c:Node2D)->void:
	c.draw_rect(Rect2(0,0,640,360),SURFACE)
	for i in range(5):
		var x:=456+i*28
		c.draw_rect(Rect2(x,34+i*8,18,284-i*16),Color(.08,.16,.19,.4))
		c.draw_line(Vector2(x,34+i*8),Vector2(x,318-i*8),LINE,1)
	_text(c,"A CITY. FOUR FLOORS. YOUR WAY UP.",Vector2(42,33),10,ACCENT)
	_text(c,"MOKSHA",Vector2(40,81),42,GOLD)
	_text(c,"FIVE ASCENTS",Vector2(43,106),16,INK)
	_text(c,"Open civilian routes. Reach the Crown. Decide who holds its keys.",Vector2(43,134),11,QUIET)
	var controller:bool=data.get("input_device","keyboard")=="controller"
	_text(c,"D-PAD LEFT / RIGHT · CHOOSE LENS" if controller else "CHOOSE YOUR STARTING LENS",Vector2(43,165),10,ACCENT)
	var selected:=str(data.get("lens",""))
	if selected.is_empty():
		for value in ["neutral","strength","agility"]:
			if "CURRENT: "+value.to_upper() in str(data.get("panel_body","")):selected=value
	var cards:=[{"id":"neutral","key":"1","title":"NEUTRAL","stats":"60 HP · balanced","detail":"Standard strikes and speed"},{"id":"strength","key":"2","title":"STRENGTH","stats":"75 HP · +40% strike","detail":"Run speed -6%"},{"id":"agility","key":"3","title":"AGILITY","stats":"50 HP · +12% run","detail":"Standard strike damage"}]
	for i in cards.size():
		var card:Dictionary=cards[i]
		var box:=Rect2(42+i*189,176,178,83)
		var chosen:bool=selected==card.id
		c.draw_rect(box,Color("18333d") if chosen else Color("10212a"))
		c.draw_rect(box,ACCENT if chosen else LINE,false,1)
		_text(c,card.title if controller else card.key+"  "+card.title,box.position+Vector2(10,21),12,GOLD if chosen else INK)
		_text(c,card.stats,box.position+Vector2(10,41),10,INK)
		_text(c,card.detail,box.position+Vector2(10,58),9,QUIET)
		if chosen:_text(c,"SELECTED",box.position+Vector2(10,74),8,ACCENT)
	_text(c,controller_footer("title","") if controller else str(data.get("panel_footer","ENTER New campaign")),Vector2(43,291),13,ACCENT)
	_text(c,"Stick / D-pad move · A jump · X strike · LB guard · RB roll" if controller else "A/D move · Space jump · J strike · K guard · Shift roll",Vector2(43,319),10,QUIET)
	_text(c,"BACK journal · START pause · Xbox-style button names" if controller else "TAB field journal · ESC controls / pause",Vector2(43,337),10,QUIET)

static func normalize_command_suffix(text:String)->String:
	# Some authored breaker names already end in / J. The host appends [J] as
	# its actionable binding; retain that explicit binding without repeating it.
	return text.replace(" / J [J]"," [J]")

static func device_text(text:String,controller:bool)->String:
	text=normalize_command_suffix(text)
	if not controller:return text
	# Translate explicit control phrases only, never individual letters in prose.
	for pair in [["[E]","[Y]"],["[J]","[X]"],["[Q]","[B]"],["J  FORCE:","X  FORCE:"],["K  AGILITY:","Y  AGILITY:"],["L  VITALITY:","B  VITALITY:"],["J  Publish","X  Publish"],["K  Transfer","Y  Transfer"],["Q taps","B taps"],["E at ","Y at "],["J launch","X launch"],["TAB journal","BACK journal"],["TAB Field journal","BACK Field journal"],["Q sound tap","B sound tap"],["Q tap","B tap"],["W/S climbs","Up/down climbs"],["TAB opens","BACK opens"],["E recovers","Y recovers"],["J moves","X moves"],["Cycle E","Cycle Y"],["with J","with X"],["with E","with Y"],[" / J"," / X"],["A/D move","Stick / D-pad move"],["Space jump","A jump"],["W/S ladders","Up/down ladders"],["J fresh-tap combo","X fresh-tap combo"],["K guard","LB guard"],["E interact","Y interact"],["E activates","Y activates"],["E restores","Y restores"],["E cycles","Y cycles"],["J strikes","X strikes"],["E replaces","Y replaces"],["Q reveals","B reveals"],["Q sounds","B sounds"]]:
		text=text.replace(pair[0],pair[1])
	return text

func controller_footer(state:String,fallback:String)->String:
	match state:
		"title":return "A / START New campaign"+("   X Continue" if bool(data.get("continue_available",false)) else "")
		"intro":return "A / START Skip opening"
		"journal":return "D-pad left / right Pages · BACK / B Return"
		"choice":return "X Trade sight · B Keep sight"
		"archive":return "Y / A / B Return to the mission"
		"upgrade":return "X Force · Y Agility · B Vitality"
		"final_choice":return "X Public record · Y Local custody"
		"dead":return "A Retry checkpoint · Y Title"
		"complete":return "A / START / Y Title · new run keeps this result"
	return device_text(fallback,true)

func _text(c:Node2D,text:String,p:Vector2,size:=10,color:=INK)->void:
	for line in text.split("\n"):
		c.draw_string(ThemeDB.fallback_font,p,line,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)
		p.y+=size+5

func caption_safe_rect()->Rect2:
	# Read the same snapshot/layout used by HUD paint; never query gameplay here.
	var layout:=playing_layout(data)
	var bottom:=339.0
	if not layout.context_notice and layout.context_height>0:bottom=minf(bottom,layout.context_top)
	var local:=Rect2(0,layout.header_height,640,maxf(0,bottom-layout.header_height))
	return get_global_transform_with_canvas()*local
