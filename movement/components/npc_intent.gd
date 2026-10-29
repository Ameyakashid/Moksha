extends Node
const TerrainProfile = preload("res://simulation/resources/terrain_probe_profile.gd")
@export var terrain_probe_profile: TerrainProfile = preload("res://simulation/resources/terrain_probe_default.tres")
const TerrainProbe = preload("res://simulation/components/terrain_probe.gd")
## World-aware intent adapter. The shared motor alone moves the NPC.
## Patrol limits are world X coordinates; target_path is relative to this node.
@export var active: bool = true
@export var chase_enabled: bool = true
@export var target_path: NodePath
@export var patrol_left: float = 180.0
@export var patrol_right: float = 560.0
@export var detection_distance: float = 220.0
@export var loss_distance: float = 300.0
@export var stop_distance: float = 38.0
@export var resume_margin: float = 12.0
@export var same_lane_height: float = 60.0
@export var turn_pause: float = 0.20
@export_flags_2d_physics var world_mask: int = 1

var brain_state: String = "PATROL"
var reason: String = "Looking for floor"
var _target: Node2D
var _patrol_direction: int = 1
var _tracking: bool = false
var _holding: bool = false
var _turn_left: float = 0.0
var _lost_sight_left: float = 0.0
@onready var motor: MokshaMovementMotor = get_parent()

func _ready() -> void:
	terrain_probe_profile = terrain_probe_profile.duplicate(true) if terrain_probe_profile != null else TerrainProfile.new()
	process_physics_priority = -20
	_find_target()

func reset(direction: int = 1) -> void:
	_patrol_direction = -1 if direction < 0 else 1
	_tracking = false
	_holding = false
	_turn_left = 0.0
	_lost_sight_left = 0.0
	brain_state = "PATROL"
	reason = "Reset"
	if is_instance_valid(motor): motor.clear_intent()
	_find_target()

func _physics_process(dt: float) -> void:
	if not active or not motor.enabled:
		motor.clear_intent()
		_set_state("DISABLED", "AI paused")
		return
	if not is_instance_valid(_target): _find_target()
	_update_tracking(dt)
	if not motor.is_on_floor():
		motor.set_intent(0.0)
		_set_state("FALL", "Waiting for stable footing")
		return
	if _turn_left > 0.0:
		_turn_left = maxf(0.0, _turn_left - dt)
		motor.set_intent(0.0)
		return
	if _tracking:
		_chase(dt)
	else:
		_patrol(dt)

func _find_target() -> void:
	_target = get_node_or_null(target_path) as Node2D if not target_path.is_empty() else null
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("movement_players") as Node2D

func _update_tracking(dt: float) -> void:
	if not chase_enabled or not is_instance_valid(_target):
		_tracking = false
		_holding = false
		return
	var offset := _target.global_position - motor.global_position
	var in_lane := absf(offset.y) <= same_lane_height
	var in_range := offset.length() <= (loss_distance if _tracking else detection_distance)
	var visible := in_lane and in_range and _has_line_of_sight()
	if visible:
		_tracking = true
		_lost_sight_left = 0.18
	elif _tracking:
		_lost_sight_left = maxf(0.0, _lost_sight_left - dt)
		if not in_range or not in_lane or _lost_sight_left <= 0.0:
			_tracking = false
			_holding = false

func _chase(dt: float) -> void:
	var dx := _target.global_position.x - motor.global_position.x
	var direction := -1 if dx < 0.0 else 1
	# Separate entry/exit radii stop tiny target movements from switching modes.
	if _holding:
		_holding = absf(dx) < stop_distance + resume_margin
	else:
		_holding = absf(dx) <= stop_distance
	if _holding:
		motor.set_intent(0.0)
		if absf(dx) > 1.0: motor.facing = direction
		_set_state("HOLD", "Within %.0f px stopping distance" % stop_distance)
		return
	var obstacle := _obstacle_reason(direction, dt)
	if not obstacle.is_empty():
		# Keep watching a target across a gap without repeatedly turning into it.
		motor.set_intent(0.0)
		motor.facing = direction
		_set_state("BLOCKED", "%s between NPC and target" % obstacle)
		return
	_patrol_direction = direction
	motor.set_intent(float(direction))
	_set_state("CHASE", "Target visible in same lane")

func _patrol(dt: float) -> void:
	var low := minf(patrol_left, patrol_right)
	var high := maxf(patrol_left, patrol_right)
	var travel := maxf(2.0, absf(motor.velocity.x) * dt)
	var at_limit := (_patrol_direction < 0 and motor.global_position.x - travel <= low) or (_patrol_direction > 0 and motor.global_position.x + travel >= high)
	var obstacle := "Patrol limit" if at_limit else _obstacle_reason(_patrol_direction, dt)
	if not obstacle.is_empty():
		var reverse := -_patrol_direction
		if _obstacle_reason(reverse, dt).is_empty():
			_patrol_direction = reverse
			motor.facing = reverse
			_set_state("TURN", "%s; turn and settle" % obstacle)
		else:
			_set_state("BLOCKED", "%s; no safe direction" % obstacle)
		_turn_left = turn_pause
		motor.set_intent(0.0)
		return
	motor.set_intent(float(_patrol_direction))
	_set_state("PATROL", "World X %.0f to %.0f" % [low, high])

func _obstacle_reason(direction: int, dt: float) -> String:
	var speed := maxf(0.0, motor.velocity.x * direction)
	var ahead := TerrainProbe.stopping_lookahead(speed, motor.tuning.braking, dt, terrain_probe_profile.body_margin, terrain_probe_profile.minimum_lookahead)
	return TerrainProbe.obstacle(motor, direction, ahead, deg_to_rad(motor.tuning.max_slope_degrees), world_mask, terrain_probe_profile)

func _has_line_of_sight() -> bool:
	return _ray(motor.global_position + Vector2(0.0, -22.0), _target.global_position + Vector2(0.0, -22.0)).is_empty()

func _ray(from: Vector2, to: Vector2) -> Dictionary:
	return TerrainProbe.ray(motor, from, to, world_mask)

func _set_state(value: String, explanation: String) -> void:
	brain_state = value
	reason = explanation
