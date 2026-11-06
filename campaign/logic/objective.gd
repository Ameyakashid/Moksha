extends Node2D
## Placeable objective state. Presentation lives in an independent child scene.
signal changed
@export var objective_id := "terminal"
@export var label := "Control terminal"
@export_enum("recover", "install", "route", "rescue", "terminal", "plate", "breaker") var kind := "terminal"
@export var required_ids: Array[String] = []
@export var optional := false
@export_range(0,2) var target := 1
var completed := false
var setting := -1
var available := true
var host: Node
var specification: Dictionary = {}
var settle := 0.0
var breaker_health:Node
func configure(spec: Dictionary, owner_host: Node) -> void:
	specification = spec
	objective_id = spec.id
	label = spec.label
	kind = spec.kind
	position = spec.at
	optional = spec.get("optional",false)
	target = int(spec.get("target",1))
	required_ids.assign(spec.get("requires",[]))
	host = owner_host
func _physics_process(dt: float) -> void:
	if not is_instance_valid(host) or host.state != "playing": return
	available = required_ids.all(func(id): return host.goal_done(id))
	if is_instance_valid(breaker_health):breaker_health.enabled=available and not completed
	if kind == "plate" and not completed and available:
		var loaded := false
		for body in host.room.find_children("*","RigidBody2D",true,false):
			if body.global_position.distance_to(global_position-Vector2(0,14)) < 48 and body.linear_velocity.length() < 35:
				loaded = true
		settle = settle+dt if loaded else 0.0
		if settle >= 0.3:
			completed = true
			changed.emit()
func interact() -> bool:
	available = required_ids.all(func(id): return host.goal_done(id)) if is_instance_valid(host) else required_ids.is_empty()
	if not available or kind in ["plate","breaker"] or (completed and kind != "route"): return false
	if kind == "route":
		setting = (setting+1)%3
		completed = setting == target
	else: completed = true
	changed.emit()
	return true

func _ready()->void:
	# Real stationary collision contour, not a permanent blind-map label.
	var body:=StaticBody2D.new();body.collision_layer=0;body.collision_mask=0
	body.position=Vector2(0,-20)
	var collider:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(34,40)
	collider.shape=shape;body.add_child(collider);add_child(body)
	if kind=="breaker":
		var contact:=Area2D.new();contact.set_script(preload("res://campaign/logic/breaker_contact.gd"));contact.name="StrikeContact"
		contact.objective=self
		contact.collision_layer=4;contact.collision_mask=0;contact.monitoring=false
		var hit_shape:=CollisionShape2D.new();hit_shape.shape=shape;hit_shape.position=Vector2(0,-20)
		contact.add_child(hit_shape);add_child(contact)
		breaker_health=preload("res://combat_pc/components/strike_health.tscn").instantiate()
		breaker_health.receiver_path=NodePath("../StrikeContact")
		breaker_health.get_node("Health").maximum_health=2.0
		add_child(breaker_health)
		breaker_health.get_node("Health").depleted.connect(_breaker_opened)
		breaker_health.enabled=required_ids.is_empty()
func _breaker_opened()->void:
	if completed:return
	completed=true
	changed.emit()


func physical_available()->bool:
	# Contact-time check: a route can be changed by E before this node's next
	# physics update. A cached enabled flag is not the current prerequisite.
	return not completed and is_instance_valid(host) and host.state=="playing" and required_ids.all(func(id):return host.goal_done(id))
