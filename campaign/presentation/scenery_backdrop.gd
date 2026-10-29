extends Node2D
## Background-only modular dressing. Nothing drawn here represents a support.
var bounds := Rect2(0,-100,1600,480)
var theme: Resource
var seed_value := 0
var skyline := preload("res://assets/environment/city-background-v1.png")
var wall := preload("res://assets/environment/wall_panel.tres")
var pipe := preload("res://assets/decor/exposed_pipe.tres")
var cable := preload("res://assets/decor/cable_bundle.tres")
var sign_texture := preload("res://assets/decor/service_sign.tres")
func _draw() -> void:
	if theme == null: return
	draw_rect(bounds,theme.background)
	var top: float = bounds.position.y
	var bottom: float = 300.0
	var city: bool = theme.motif in ["city","crown"]
	if city:
		for x in range(0,int(bounds.size.x)+960,960):
			draw_texture_rect(skyline,Rect2(x,top,960,bottom-top),false,Color(.54,.62,.68,1))
	else:
		_draw_industrial_bays()
		return
	# Painted steel ribs, suspended conduits and restrained practical lighting.
	for x in range(0,int(bounds.size.x)+240,240):
		draw_rect(Rect2(x,top,10,bottom-top),theme.panel.darkened(.4))
		draw_line(Vector2(x+10,top),Vector2(x+10,bottom),theme.edge.darkened(.55),1)
		draw_texture_rect(cable,Rect2(x+18,top+18,205,35),false,Color(.6,.65,.67,1))
		draw_texture_rect(pipe,Rect2(x+28,top+68,96,37),false,Color(.5,.56,.58,1))
		draw_rect(Rect2(x+157,top+51,40,5),theme.practical.darkened(.15))
		# Light stays high and behind silhouettes: no full-screen bloom or washout.
		draw_colored_polygon(PackedVector2Array([Vector2(x+154,top+59),Vector2(x+200,top+59),Vector2(x+228,top+164),Vector2(x+127,top+164)]),theme.practical*Color(1,1,1,.035))
		if posmod(x/240,3)==1:
			draw_texture_rect(sign_texture,Rect2(x+144,top+95,76,38),false,Color(.7,.75,.75,1))
	if theme.motif == "foundry":
		for x in range(70,int(bounds.size.x),480):
			draw_rect(Rect2(x,top+125,96,110),Color("241c1c"))
			for slot in 6:
				draw_rect(Rect2(x+8+slot*14,top+139,5,70),theme.practical*Color(.6,.3,.15,1))
	if theme.motif == "water":
		# Background waterline below walkable floor; never suggests a new hazard.
		draw_rect(Rect2(0,315,bounds.size.x,65),theme.haze)
		for x in range(0,int(bounds.size.x),38):
			draw_line(Vector2(x,333+posmod(x,13)),Vector2(x+22,333+posmod(x,13)),theme.accent*Color(1,1,1,.15),1)

func _pipe(a: Vector2,b: Vector2,width: float,color: Color) -> void:
	draw_line(a,b,theme.background.darkened(.35),width+3,true)
	draw_line(a,b,color,width,true)
	draw_line(a+Vector2(-width*.18,0),b+Vector2(-width*.18,0),color.lightened(.1),maxf(1,width*.14),true)
func _draw_industrial_bays() -> void:
	# Motifs are floor-relative, not attached to an off-screen ceiling. Repeat
	# only large structural bays; each bay changes its equipment/negative space.
	for bottom in range(300,int(bounds.position.y)-1,-260):
		var roof:=float(bottom-252)
		for index in range(ceili(bounds.size.x/360.0)):
			var x:=float(index*360)
			var variant:=posmod(index+seed_value+int((300-bottom)/260),3)
			var back:=Rect2(x+14,roof+14,330,232)
			draw_rect(back,theme.panel.darkened(.43))
			draw_rect(Rect2(x+28,roof+24,302,210),theme.background.lightened(.025))
			# Layered steel framing; wide dark beams separate bays from gameplay.
			draw_rect(Rect2(x,roof,13,260),theme.background.darkened(.35))
			draw_rect(Rect2(x+13,roof,3,260),theme.edge.darkened(.62))
			draw_rect(Rect2(x,roof+8,360,9),theme.panel.darkened(.1))
			for bolt_y in [roof+34,roof+218]:
				draw_circle(Vector2(x+7,bolt_y),1.3,theme.edge.darkened(.35),true,-1,true)
			_pipe(Vector2(x+18,roof+34),Vector2(x+345,roof+34),7,theme.panel.lightened(.025))
			# A single original wall appliance per large bay, not tiled wallpaper.
			var appliance_x:=x+274 if variant!=1 else x+24
			draw_texture_rect(wall,Rect2(appliance_x,roof+128,42,65),false,Color(.48,.54,.57,1))
			if theme.motif=="foundry":_foundry_bay(x,roof,variant)
			elif theme.motif=="water":_cistern_bay(x,roof,variant)
			else:_memory_bay(x,roof,variant)
			# Practical warm strip: restrained spill is behind all gameplay paint.
			var light_x:=x+70+float(variant)*62
			draw_rect(Rect2(light_x,roof+46,54,3),theme.practical.darkened(.22))
			draw_colored_polygon(PackedVector2Array([Vector2(light_x,roof+50),Vector2(light_x+54,roof+50),Vector2(light_x+73,roof+114),Vector2(light_x-19,roof+114)]),Color(theme.practical,.025))
func _foundry_bay(x: float,y: float,variant: int) -> void:
	var furnace_x:=x+35+float(variant%2)*94
	draw_rect(Rect2(furnace_x,y+83,116,137),Color("15191d"))
	draw_rect(Rect2(furnace_x+5,y+88,106,126),Color("3c3030"),false,3)
	draw_rect(Rect2(furnace_x+15,y+102,86,82),Color("281c1b"))
	for slot in 7:
		draw_rect(Rect2(furnace_x+20+slot*11,y+112,4,60),Color("8b532e"))
		draw_rect(Rect2(furnace_x+21+slot*11,y+116,1,51),Color("c47f42"))
	draw_rect(Rect2(furnace_x+18,y+194,80,10),theme.panel.darkened(.12))
	var pipe_x:=x+226 if variant!=1 else x+233
	_pipe(Vector2(pipe_x,y+40),Vector2(pipe_x,y+216),13,Color("4a3c35"))
	_pipe(Vector2(pipe_x,y+216),Vector2(x+340,y+216),13,Color("4a3c35"))
	for clamp_y in [y+78,y+150,y+205]:draw_rect(Rect2(pipe_x-10,clamp_y,20,5),Color("243238"))
	# Broad diagonal chassis makes a different silhouette from a flat wall.
	draw_line(Vector2(x+24,y+232),Vector2(x+88,y+196),theme.panel.lightened(.03),5,true)
func _cistern_bay(x: float,y: float,variant: int) -> void:
	var window_x:=x+28 if variant!=1 else x+145
	var window:=Rect2(window_x,y+67,132,125)
	draw_rect(window.grow(5),Color("101d25"))
	draw_texture_rect_region(skyline,window,Rect2(300+variant*190,180,450,430),Color(.19,.36,.40,1))
	for mullion in [44,88]:draw_rect(Rect2(window_x+mullion,y+67,3,125),Color("213d43"))
	draw_rect(Rect2(window_x,y+127,132,4),Color("213d43"))
	draw_rect(Rect2(window_x,y+192,132,4),theme.edge.darkened(.35))
	var tank_x:=x+208 if variant!=1 else x+57
	draw_rect(Rect2(tank_x,y+66,52,150),Color("173037"))
	draw_rect(Rect2(tank_x+5,y+70,40,143),Color("2a4549"))
	for strap_y in [y+82,y+144,y+200]:draw_rect(Rect2(tank_x-3,strap_y,58,6),Color("41565a"))
	_pipe(Vector2(tank_x+26,y+38),Vector2(tank_x+26,y+66),10,Color("3b5558"))
	_pipe(Vector2(tank_x+26,y+218),Vector2(tank_x+26,y+240),10,Color("3b5558"))
	for gauge in 3:draw_rect(Rect2(tank_x+16,y+104+gauge*9,4,3),theme.accent.darkened(.45))
func _memory_bay(x: float,y: float,variant: int) -> void:
	var rack_x:=x+42+float(variant%2)*64
	for rack in 2:
		var at:=Vector2(rack_x+rack*87,y+68)
		draw_rect(Rect2(at-Vector2(5,5),Vector2(83,160)),Color("101720"))
		draw_rect(Rect2(at,Vector2(73,150)),Color("29313e"))
		for row in 8:
			var row_y:=at.y+8+row*17
			draw_rect(Rect2(at.x+5,row_y,63,12),Color("17212d"))
			draw_line(Vector2(at.x+13,row_y+7),Vector2(at.x+48,row_y+7),Color("3b4858"),1)
			draw_rect(Rect2(at.x+56,row_y+4,3,2),theme.accent.darkened(.35 if (row+rack+variant)%3==0 else .65))
	# Cable trunk and a blank access aisle vary the cabinet rhythm.
	_pipe(Vector2(x+25,y+51),Vector2(x+25,y+224),7,Color("3b3c4b"))
	draw_texture_rect(cable,Rect2(rack_x,y+219,166,24),false,Color(.45,.46,.54,1))
