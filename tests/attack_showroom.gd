extends Node2D
## Editor F6 visual fixture: four frozen contact phases and one real timed combo.
## This inspection scene is not a third playable level or part of progression.
const PLAYER = preload("res://scenes/actors/player.tscn")
const FONT = preload("res://fonts/DejaVuSansMono.ttf")
var actor: CharacterBody2D
var loop_clock := 0.0
var small_actor: CharacterBody2D
func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("10191e"))
	for i in range(4):
		var sample = PLAYER.instantiate()
		add_child(sample)
		sample.position = Vector2(84+i*154,170)
		sample.scale = Vector2.ONE*1.75
		sample.input_enabled = false
		sample.set_physics_process(false)
		sample.graphics.set_process(false)
		var duration: float = sample.tuning.attack_seconds
		var contact: float = 1.0-sample.tuning.attack_hit_remaining/duration
		var active_end: float = contact+sample.tuning.attack_active_seconds/duration
		var progress: float = [contact*0.15,contact,active_end-0.02,0.86][i]
		sample.graphics.present(&"attack_1",1)
		sample.graphics.present_combat(progress,1,false,Vector2.ZERO,false)
	var floor_body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(640,20)
	collider.shape = shape
	floor_body.add_child(collider)
	floor_body.position = Vector2(320,314)
	add_child(floor_body)
	actor = PLAYER.instantiate()
	add_child(actor)
	actor.position = Vector2(163,304)
	actor.input_enabled = false
	small_actor = PLAYER.instantiate()
	add_child(small_actor)
	small_actor.position = Vector2(476,304)
	small_actor.facing = -1
	small_actor.input_enabled = false
	loop_clock = 0.8
func _physics_process(dt: float) -> void:
	loop_clock += dt
	if loop_clock >= 0.75:
		loop_clock = 0.0
		actor.position.x = 163
		small_actor.position.x = 476
		actor._start_attack()
		small_actor._start_attack()
	queue_redraw()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		get_viewport().get_texture().get_image().save_png("res://delivery/MOKSHA-Attack-Study.png")
func _draw() -> void:
	draw_string(FONT,Vector2(22,25),"MOKSHA / DRAWN ATTACK STUDY",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e4e4da"))
	draw_string(FONT,Vector2(22,45),"SEPARATE BODY FRAMES / SEPARATE BATON / ORIGINAL HIT TIMING",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("94b9ba"))
	for i in 4:
		var x := 14+i*154
		draw_line(Vector2(x,171),Vector2(x+148,171),Color("507074"),1)
		draw_string(FONT,Vector2(x+17,194),["ANTICIPATION","CONTACT","FOLLOW-THROUGH","RECOVERY"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("c0cccc"))
	draw_string(FONT,Vector2(22,228),"LIVE THREE-STRIKE LOOP / GAME SCALE",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("94b9ba"))
	draw_line(Vector2(22,305),Vector2(618,305),Color("507074"),1)
	draw_string(FONT,Vector2(22,339),"F12 CAPTURE / OPEN THE PLAYER PREFAB TO SWAP THE ATTACK PROFILE",HORIZONTAL_ALIGNMENT_LEFT,-1,8,Color("94b9ba"))
