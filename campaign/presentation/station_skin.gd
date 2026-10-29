extends Node2D
## Exact32x42 sight-exchange terminal. Original interaction/contour stays intact.
const Cabinet=preload("res://assets/props/utility_cabinet.tres")
var station: Node2D
func _draw() -> void:
	if not is_instance_valid(station) or station.appearance==null:return
	var appearance: Resource=station.appearance
	draw_texture_rect(Cabinet,Rect2(-16,-42,32,42),false,Color(.85,.92,.93,1))
	draw_rect(Rect2(-10,-34,20,11),Color("172d34"))
	draw_rect(Rect2(-9,-33,18,9),Color("385e63"),false,.7)
	draw_circle(Vector2(0,-28),3,appearance.ink,false,.8,true)
	draw_line(Vector2(-5,-28),Vector2(5,-28),appearance.ink,.8,true)
	var face: Font=appearance.font if appearance.font!=null else ThemeDB.fallback_font
	draw_string(face,Vector2(-39,-54),appearance.label,HORIZONTAL_ALIGNMENT_LEFT,-1,appearance.font_size,appearance.ink)
