@tool
extends Node2D
## Placement-only inspection kit. Actors and attack emitters remain independent.
func _draw() -> void:
	var font:=ThemeDB.fallback_font
	var ink:=Color("a7c6d2")
	for x in [140,520,920]:
		draw_line(Vector2(x-10,1),Vector2(x+10,1),Color("9bddd0"),1.2)
	draw_string(font,Vector2(70,-70),"MELEE / BLOCK > PARRY > COUNTER",HORIZONTAL_ALIGNMENT_LEFT,-1,8,ink)
	draw_string(font,Vector2(445,-70),"PROJECTILE / PHYSICAL RETURN",HORIZONTAL_ALIGNMENT_LEFT,-1,8,ink)
	draw_string(font,Vector2(850,-70),"RIGID PROP / IMPULSE + CONTACT",HORIZONTAL_ALIGNMENT_LEFT,-1,8,ink)
	for x in [70,445,850]:
		draw_string(font,Vector2(x,32),"F SEND   K TAP / HOLD   V NEXT TEST",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("8ea5b5"))
