@tool
class_name MokshaContactTarget
extends Area2D
## Passive contact instrument, not an NPC. No AI, movement or player blocking.
signal struck(payload: Dictionary)
@export var size := Vector2(16,30):
	set(value):
		size=value
		_sync()
@export var label := "CONTACT":
	set(value):
		label=value
		queue_redraw()
var hits := 0
var last_serial := -1
var last_contact := Vector2.ZERO
var flash := 0.0
var recoil := 0.0
var last_impulse := Vector2.ZERO
func _ready() -> void:
	collision_layer=4
	collision_mask=0
	monitoring=false
	monitorable=true
	_sync()
func _sync() -> void:
	var collision:=get_node_or_null("Shape") as CollisionShape2D
	if collision:
		var box:=RectangleShape2D.new()
		box.size=size
		collision.shape=box
		collision.position=Vector2(0,-size.y*0.5)
	queue_redraw()
func receive_strike(payload: Dictionary) -> void:
	hits+=1
	last_serial=int(payload.get("serial",-1))
	last_contact=payload.get("contact_position",global_position)
	last_impulse=payload.get("impulse",Vector2.ZERO)
	flash=0.14
	recoil=float(payload.get("facing",1))*3
	struck.emit(payload)
	queue_redraw()
func reset_target() -> void:
	hits=0
	last_serial=-1
	flash=0
	recoil=0
	queue_redraw()
func _process(dt: float) -> void:
	if Engine.is_editor_hint():return
	flash=maxf(0,flash-dt)
	recoil=move_toward(recoil,0,dt*25)
	queue_redraw()
func _draw() -> void:
	var color:=Color("fff1cf") if flash>0 else Color("bd9469")
	var rect:=Rect2(Vector2(-size.x*0.5+recoil,-size.y),size)
	draw_rect(rect,color,false,1)
	draw_line(rect.position,rect.end,color,0.6)
	draw_line(Vector2(rect.end.x,rect.position.y),Vector2(rect.position.x,rect.end.y),color,0.6)
	draw_string(ThemeDB.fallback_font,Vector2(-size.x*0.5-4,-size.y-7),label,HORIZONTAL_ALIGNMENT_LEFT,-1,7,color)
	if not Engine.is_editor_hint():draw_string(ThemeDB.fallback_font,Vector2(-8,11),str(hits)+" HITS",HORIZONTAL_ALIGNMENT_LEFT,-1,6,color)
