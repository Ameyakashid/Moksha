extends Node
## Small explicit wiring adapter; receiver owns physical success, shutter owns opening.
@export_node_path("Node2D") var cradle_path:=NodePath("../Cradle")
@export_node_path("Node2D") var receiver_path:=NodePath("../Receiver")
@export_node_path("StaticBody2D") var shutter_path:=NodePath("../Shutter")
func _ready()->void:
	var cradle=get_node_or_null(cradle_path);var receiver=get_node_or_null(receiver_path)
	if not is_instance_valid(cradle) or not is_instance_valid(receiver):return
	cradle.bind_receiver(receiver)
	receiver.latched.connect(_on_latched)
	cradle.replace_cargo()
func _on_latched(_cargo:RigidBody2D)->void:
	var shutter=get_node_or_null(shutter_path)
	if is_instance_valid(shutter):shutter.set_open(true)
