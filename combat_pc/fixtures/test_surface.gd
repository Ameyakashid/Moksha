@tool
extends AnimatableBody2D
## Original inspection geometry. Its motion is fixture behavior, not game logic.
@export var size := Vector2(64,16):
	set(value):
		size = value
		_sync()
@export var one_way := false:
	set(value):
		one_way = value
		_sync()
@export var label := "":
	set(value):
		label = value
		queue_redraw()
@export var moving := false
@export var travel := Vector2(80,0)
@export var travel_speed := 50.0
var _origin := Vector2.ZERO
var _distance := 0.0
var _direction := 1.0
func _ready() -> void:
	process_physics_priority = -20
	collision_layer=1
	collision_mask=0
	sync_to_physics = false
	_origin=position
	_sync()
func _sync() -> void:
	var shape := get_node_or_null("Shape") as CollisionShape2D
	if shape:
		var box := RectangleShape2D.new()
		box.size=size
		shape.shape=box
		shape.position=size*0.5
		shape.one_way_collision=one_way
		shape.one_way_collision_margin=1.0
	queue_redraw()
func _physics_process(dt: float) -> void:
	if Engine.is_editor_hint() or not moving or travel.length()<0.1: return
	_distance=clampf(_distance+_direction*travel_speed*dt,0,travel.length())
	position=_origin+travel.normalized()*_distance
	if _distance>=travel.length(): _direction=-1
	elif _distance<=0: _direction=1
func _draw() -> void:
	var ink := Color("69cbb2") if one_way else (Color("cca277") if moving else Color("6f899b"))
	draw_rect(Rect2(Vector2.ZERO,size),Color(ink,0.06))
	draw_rect(Rect2(Vector2.ZERO,size),ink,false,0.7)
	if one_way: draw_line(Vector2.ZERO,Vector2(size.x,0),ink,1.1)
	if not label.is_empty(): draw_string(ThemeDB.fallback_font,Vector2(2,-6),label,HORIZONTAL_ALIGNMENT_LEFT,-1,8,ink)

