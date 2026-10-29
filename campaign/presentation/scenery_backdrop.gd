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
		# Large architectural bays. The irregular panel rhythm is deterministic.
		for x in range(0,int(bounds.size.x),160):
			var shade: float = .65 + float(posmod(x+seed_value,7))*.025
			draw_rect(Rect2(x+3,top+20,154,bottom-top-20),theme.panel*Color(shade,shade,shade,1))
			draw_rect(Rect2(x+12,top+32,136,bottom-top-52),theme.background.darkened(.1),false,2)
			for y in range(int(top)+48,250,96):
				draw_texture_rect(wall,Rect2(x+14,y,42,64),false,Color(.4,.47,.5,1))
			if theme.motif == "memory":
				for row in 7:
					draw_rect(Rect2(x+75,top+64+row*18,54,12),Color("121826"))
					draw_rect(Rect2(x+79,top+67+row*18,3,2),theme.accent.darkened(.4))
			if theme.motif == "water":
				draw_rect(Rect2(x+68,top+42,70,116),Color("12343d"))
				for row in 5:
					draw_line(Vector2(x+71,top+55+row*22),Vector2(x+134,top+55+row*22),theme.accent*Color(1,1,1,.13),1)
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
