extends Node
## A replaceable input adapter. The motor does not depend on Input or this node.
@export var active: bool = true
var _jump_pressed := false
var _jump_released := false
var _dash_pressed := false
@onready var motor: MokshaMovementMotor = get_parent()
func _ready() -> void:
	process_physics_priority = -20
func _unhandled_input(event: InputEvent) -> void:
	if not active: return
	if event.is_action_pressed("jump", false): _jump_pressed = true
	if event.is_action_released("jump"): _jump_released = true
	if event.is_action_pressed("dash", false): _dash_pressed = true
func _physics_process(_dt: float) -> void:
	if active:
		motor.set_intent(Input.get_axis("left", "right"), _jump_pressed, _jump_released, _dash_pressed, Input.is_action_pressed("jump"))
	else: motor.clear_intent()
	clear_pending()

func clear_pending() -> void:
	_jump_pressed = false
	_jump_released = false
	_dash_pressed = false
