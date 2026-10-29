@tool
class_name MokshaPracticePulse
extends Node2D
## Stationary diagnostic strike. It has no AI or tracking: the marked strip is
## tested only during its visible active phase and can be rolled through.
@export var width := 32.0
@export var height := 32.0
@export var cycle_seconds := 1.8
@export var warning_seconds := 0.45
@export var active_seconds := 0.12
@export var enabled := true
var elapsed := 0.0
var phase := "rest"
var cycle_hits: Dictionary = {}
var accepted_hits := 0
var avoided_samples := 0
func _physics_process(dt: float) -> void:
	if Engine.is_editor_hint() or not enabled:return
	elapsed+=dt
	if elapsed>=cycle_seconds:
		elapsed=fmod(elapsed,cycle_seconds)
		cycle_hits.clear()
	phase="active" if elapsed>=cycle_seconds-active_seconds else ("warning" if elapsed>=cycle_seconds-active_seconds-warning_seconds else "rest")
	if phase=="active":
		var shape:=RectangleShape2D.new()
		shape.size=Vector2(width,height)
		var query:=PhysicsShapeQueryParameters2D.new()
		query.shape=shape
		query.transform=Transform2D(0,global_position+Vector2(0,-height*0.5))
		query.collision_mask=2
		for hit in get_world_2d().direct_space_state.intersect_shape(query,8):
			var actor:=hit.collider as Node2D
			if not is_instance_valid(actor) or not actor.has_method("receive_hit") or cycle_hits.has(actor.get_instance_id()):continue
			if actor.receive_hit({"rollable":true,"source_position":global_position,"amount":1.0}):
				cycle_hits[actor.get_instance_id()]=true
				accepted_hits+=1
			else:avoided_samples+=1
	queue_redraw()
func reset_fixture() -> void:
	elapsed=0
	phase="rest"
	cycle_hits.clear()
	accepted_hits=0
	avoided_samples=0
	queue_redraw()
func _draw() -> void:
	var color:=Color("a05955") if phase=="active" else (Color("bfa269") if phase=="warning" else Color("5b6a76"))
	var rect:=Rect2(Vector2(-width*0.5,-height),Vector2(width,height))
	draw_rect(rect,Color(color,0.15 if phase=="active" else 0.035))
	draw_rect(rect,color,false,0.7)
	if phase=="warning":draw_line(Vector2(-width*0.5,-height-3),Vector2(width*0.5,-height-3),color,1.5)
	if phase=="active":draw_line(Vector2(-width*0.5,-height),Vector2(width*0.5,0),color,1.5)
	draw_string(ThemeDB.fallback_font,Vector2(-25,-height-10),"ROLL / PULSE",HORIZONTAL_ALIGNMENT_LEFT,-1,7,color)
