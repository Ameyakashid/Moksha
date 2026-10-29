extends Node2D
## Presentation only. World effects are occluded by the blind sensory view.
const FONT = preload("res://fonts/DejaVuSansMono.ttf")
const HERO = preload("res://assets/characters/operative_frames.tres")
@export var simulation_enabled := true
@export_range(100,1000) var particle_budget := 350
var particles: Array = []
var texts: Array = []
var trails: Array = []
var slashes: Array = []
func burst(pos: Vector2, count: int, color: Color, speed: float) -> void:
	for i in mini(count,40):
		var a := randf_range(-PI,PI)
		particles.append({"pos":pos,"vel":Vector2.from_angle(a)*randf_range(speed*.2,speed),"life":randf_range(.13,.35),"color":color,"size":randi_range(1,2)})
	if particles.size()>particle_budget: particles=particles.slice(particles.size()-particle_budget)
func float_text(pos: Vector2,value: String,color: Color) -> void:
	texts.append({"pos":pos,"value":value.replace("+ EMBER","NEUTRALIZED"),"color":color,"life":.7})
func ghost(pos: Vector2,facing: int) -> void:
	trails.append({"pos":pos,"facing":facing,"life":.13})
func slash(actor: Node2D,combo: int) -> void:
	slashes.append({"pos":actor.global_position+Vector2(actor.facing*22,-24),"facing":actor.facing,"life":.12,"combo":combo})
func clear_effects() -> void:
	particles.clear();texts.clear();trails.clear();slashes.clear();queue_redraw()
func _process(dt: float) -> void:
	if not simulation_enabled:return
	for i in range(particles.size()-1,-1,-1):
		particles[i].life-=dt;particles[i].pos+=particles[i].vel*dt;particles[i].vel.y+=dt*250
		if particles[i].life<=0:particles.remove_at(i)
	for collection in [texts,trails,slashes]:
		for i in range(collection.size()-1,-1,-1):
			collection[i].life-=dt
			if collection[i].life<=0:collection.remove_at(i)
	queue_redraw()
func _draw() -> void:
	for trail in trails:
		draw_set_transform(trail.pos,0,Vector2(trail.facing*.165,.165))
		draw_texture(HERO.get_frame_texture("run",0),Vector2(-320,-352),Color(.7,.85,.9,trail.life*1.5))
		draw_set_transform(Vector2.ZERO)
	for cut in slashes:
		var a:float=cut.life/.12
		var side:float=cut.facing
		draw_arc(cut.pos,28,-1.15 if side>0 else PI-1.15,1.15 if side>0 else PI+1.15,12,Color(1,.95,.8,a),3,true)
		draw_line(cut.pos-Vector2(side*15,4),cut.pos+Vector2(side*32,-4),Color(1,1,1,a),1,true)
	for p in particles:
		var c:Color=p.color;c.a=minf(1,p.life*5)
		draw_rect(Rect2(p.pos,Vector2(p.size,p.size)),c)
	for note in texts:
		var c:Color=note.color;c.a=minf(1,note.life*4)
		draw_string(FONT,note.pos,note.value,HORIZONTAL_ALIGNMENT_CENTER,-1,8,c)
