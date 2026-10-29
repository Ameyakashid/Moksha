extends StaticBody2D
@export var door_size := Vector2(24,180)
@export var required_ids: Array[String] = []
var host: Node
var opened := false
func _ready() -> void:
	collision_layer=1;collision_mask=0
	var shape:=RectangleShape2D.new();shape.size=door_size
	$CollisionShape2D.shape=shape
func _physics_process(_dt:float)->void:
	if not is_instance_valid(host):return
	var next:bool=required_ids.all(func(id):return host.goal_done(id))
	if next!=opened:
		opened=next
		$CollisionShape2D.set_deferred("disabled",opened)
		if opened:add_to_group("sonar_ignore")
		else:remove_from_group("sonar_ignore")
		if is_instance_valid(host.sonar):host.sonar.refresh_geometry()
	queue_redraw()
func _draw()->void:
	if opened:
		draw_rect(Rect2(-door_size.x*0.5,-door_size.y*0.5,door_size.x,8),Color("64dcb5"));return
	draw_rect(Rect2(-door_size*0.5,door_size),Color("1c303c"))
	for y in range(-int(door_size.y/2),int(door_size.y/2),16):draw_line(Vector2(-door_size.x/2,y),Vector2(door_size.x/2,y+8),Color("d18c58"),3)
