extends Node2D
## Optional view only: no world, host, sensory, collider or gameplay dependency.
const Profile = preload("res://demo/views/room_backdrop_profile.gd")
@export var profile: Profile:
	set(value):
		if profile != null and profile.changed.is_connected(queue_redraw):
			profile.changed.disconnect(queue_redraw)
		profile = value
		if profile != null and not profile.changed.is_connected(queue_redraw):
			profile.changed.connect(queue_redraw)
		queue_redraw()
@export var automatic_animation := true:
	set(value):
		automatic_animation = value
		set_process(value)
var animation_time := 0.0

func _ready() -> void:
	set_process(automatic_animation)

func set_animation_time(seconds: float) -> void:
	if not is_finite(seconds): return
	animation_time = seconds
	queue_redraw()

func _process(dt: float) -> void:
	if automatic_animation and is_finite(dt) and dt > 0.0:
		set_animation_time(animation_time + dt)

func _draw() -> void:
	if profile == null or not profile.has_valid_bounds(): return
	var bounds: Rect2 = profile.room_bounds
	var offset := Vector2(bounds.position.x, bounds.end.y - 300.0)
	var top := bounds.position.y - offset.y
	if offset != Vector2.ZERO: draw_set_transform(offset)
	var city: bool = profile.theme == "city"
	var width := bounds.size.x
	var faint := Color("182c35") if not city else Color("28303a")
	# Zero is the original authored phase. No global/random mutable state is used.
	var phase := posmod(profile.visual_seed, 160)
	draw_rect(Rect2(-40,top-100,width+80,600-top),Color("071119") if not city else Color("111821"))
	for i in range(int(width/90)+2):
		var h := 80.0+float((i*73+31+phase)%160)
		var r := Rect2(i*90-25,280-h,66,h)
		draw_rect(r,Color("13212b") if city else Color("0b1c25"))
		draw_line(r.position,Vector2(r.end.x,r.position.y),faint,1)
		if city:
			for row in range(3):
				for col in range(3):
					draw_rect(Rect2(r.position+Vector2(10+col*17,12+row*21),Vector2(3,7)),Color("3a3936"))
		else:
			draw_line(Vector2(i*90,top),Vector2(i*90,280),faint,1)
			draw_circle(Vector2(i*90,75),3,faint,false,1)
	if city:
		for i in range(45):
			var x := fmod(float(i*73+phase)+animation_time*38,width)
			var y := fmod(float(i*47+phase)+animation_time*125,285)
			draw_line(Vector2(x,y),Vector2(x-3,y+9),Color(0.35,0.5,0.6,0.2),0.65)
	else:
		for y in [45,52,269]: draw_line(Vector2(0,y),Vector2(width,y),faint,1)
