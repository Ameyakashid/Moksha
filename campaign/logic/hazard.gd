extends Node2D
## Deterministic telegraphed environmental danger, never an elapsed-time exit gate.
@export var hazard_size:=Vector2(100,12)
@export var period:=3.6
@export var duty:=0.5
@export var phase:=0.0
@export var damage:=8.0
var host:Node
var clock:=0.0
var cooldown:=0.0
var active:=false
var warning:=false
var noise_cooldown:=0.0
func _physics_process(dt:float)->void:
	if not is_instance_valid(host) or host.state!="playing":return
	clock+=dt;cooldown=maxf(0,cooldown-dt)
	var cycle:=fposmod(clock+phase,period)
	var old_active:=active
	var old_warning:=warning
	active=cycle<period*duty
	warning=not active and cycle>period-0.5
	noise_cooldown=maxf(0,noise_cooldown-dt)
	if (active and not old_active) or (warning and not old_warning) or ((active or warning) and noise_cooldown<=0):
		host.bus.emit_noise(global_position,&"enemy_windup" if warning else &"prop_impact",1.4,self)
		noise_cooldown=0.35
	if active and cooldown<=0 and Rect2(global_position-hazard_size/2,hazard_size).grow(10).has_point(host.player.global_position-Vector2(0,12)):
		# The actor's ordinary damage admission owns dodge/guard/health semantics.
		host.player.receive_hit({"amount":damage,"impulse":Vector2(0,-100),"source_position":global_position,"source_id":get_instance_id()}) if host.player.has_method("receive_hit") else null
		cooldown=0.8
	queue_redraw()
func _draw()->void:
	var c:=Color("ff7168") if active else Color("f0bb67") if warning else Color("304953")
	draw_rect(Rect2(-hazard_size/2,hazard_size),c)
	if active:
		for i in range(0,int(hazard_size.x),12):draw_line(Vector2(i-hazard_size.x/2,-hazard_size.y/2),Vector2(i-hazard_size.x/2+5,-hazard_size.y/2-12),c,2)

func _ready()->void:
	var body:=StaticBody2D.new();body.collision_layer=0;body.collision_mask=0
	var collider:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=hazard_size
	collider.shape=shape;body.add_child(collider);add_child(body)
