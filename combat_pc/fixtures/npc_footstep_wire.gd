@tool
extends Node2D
## Passive inspection pose. The motor and contact source remain authoritative.
@export var tint := Color("e8bc86")
@export var actor_label := "NPC"
@onready var motor: CharacterBody2D = get_parent()
var _gait_phase := 0.0

func _process(dt: float) -> void:
	# Visual rhythm follows the motor independently of the removable sound
	# child. Muting/removing that child must not stop the NPC's leg animation.
	if not Engine.is_editor_hint() and is_instance_valid(motor) and motor.is_on_floor():
		if motor.get("enabled") != false and float(motor.get("pause_left"))<=0 and float(motor.get("stun_left"))<=0:
			_gait_phase += absf(motor.velocity.x)*dt/28.0*PI
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(motor): return
	var face: Variant = motor.get("facing")
	var f := float(face) if face != null else 1.0
	var motion := Vector2.ZERO if Engine.is_editor_hint() else motor.velocity
	var grounded := true if Engine.is_editor_hint() else motor.is_on_floor()
	var phase := _gait_phase
	var moving := grounded and absf(motion.x)>3.0
	var stride := sin(phase)*5.5 if moving else 0.0
	var lean := clampf(motion.x/160.0,-1,1)*2.5
	var hip := Vector2(0,-13)
	var left := Vector2(-5+stride,-maxf(0,sin(phase))*4 if moving else 0)
	var right := Vector2(5-stride,-maxf(0,-sin(phase))*4 if moving else 0)
	if not grounded:
		left=Vector2(-7*f,-8);right=Vector2(5*f,-4)
	var shoulder := Vector2(lean,-25)
	draw_circle(Vector2(lean,-31),4.3,tint,false,1.1)
	draw_line(shoulder,hip,tint,1.2)
	draw_polyline(PackedVector2Array([left,(left+hip)*0.5+Vector2(-2,-1),hip,(right+hip)*0.5+Vector2(2,-1),right]),tint,1.1)
	draw_polyline(PackedVector2Array([shoulder+Vector2(-f*7,6),shoulder,shoulder+Vector2(f*9,8)]),tint,1.1)
	draw_line(Vector2(lean+f*3,-32),Vector2(lean+f*7,-31),Color.WHITE,1.3)
	draw_string(ThemeDB.fallback_font,Vector2(-9,-43),actor_label,HORIZONTAL_ALIGNMENT_LEFT,-1,8,tint)
