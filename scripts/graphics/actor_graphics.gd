extends Node2D
## Presentation only: approved atlas poses keep their foot origin. Body motion
## shears/compresses about that origin; it never moves the actor or its collider.

@export_category("Procedural pose")
@export_range(0.0, 1.0, 0.05) var motion_amount: float = 1.0
@export_range(0.0, 0.4, 0.01) var roll_compression: float = 0.26
@export_range(0.0, 0.2, 0.01) var landing_compression: float = 0.085
@export_range(0.08, 0.4, 0.01) var landing_seconds: float = 0.18
@export_category("Pose cycle speed")
@export var run_reference_speed: float = 218.0
@export var walk_reference_speed: float = 42.0
@export_category("Optional drawn attack")
@export var attack_pose: MokshaAttackPoseProfile

# Forward-hand positions in the approved operative's virtual 640 x 384 canvas,
# relative to its (320, 352) foot origin. Guards carry their weapon in their art.
const HAND_ANCHORS := {
	&"idle": [Vector2(42, -126), Vector2(45, -126)],
	&"run": [Vector2(92, -165), Vector2(61, -160), Vector2(87, -196), Vector2(80, -174), Vector2(64, -164), Vector2(76, -192)],
	&"jump": [Vector2(98, -228)],
	&"fall": [Vector2(86, -154)],
	&"hurt": [Vector2(21, -149)],
	&"ready": [Vector2(84, -172)]
}
const REST_ANGLE := 0.85

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var health_bar: ProgressBar = get_node_or_null("HealthBar")
@onready var telegraph: Label = get_node_or_null("Telegraph")
@onready var weapon: Node2D = get_node_or_null("Weapon")
var _sprite_scale := Vector2.ONE
var _sprite_position := Vector2.ZERO
var _base_frames: SpriteFrames
var _base_sprite_offset := Vector2.ZERO
var _drawn_attack := false
var _actor: CharacterBody2D
var _tuning: Resource
var _direction := 1
var _state_name: StringName = &"idle"
var _state_seconds := 0.0
var _enabled := true
var _was_grounded := false
var _last_fall_speed := 0.0
var _landing_remaining := 0.0
var _landing_strength := 0.0
var _attack_progress := -1.0
var _combo := 0
var _dashing := false
var _tap_target := Vector2.ZERO
var _tapping := false

func _ready() -> void:
	_sprite_scale = sprite.scale.abs()
	_sprite_position = sprite.position
	_base_frames = sprite.sprite_frames
	_base_sprite_offset = sprite.offset
	_actor = get_parent() as CharacterBody2D
	if is_instance_valid(_actor): _tuning = _actor.get("tuning") as Resource

func _process(dt: float) -> void:
	if not _enabled: return
	_state_seconds += dt
	_landing_remaining = maxf(0.0, _landing_remaining - dt)
	_apply_body_pose()
	_apply_weapon_pose()

func present(state_name: StringName, direction: int, enabled: bool = true, shown: bool = true, highlight: bool = false) -> void:
	if not is_instance_valid(sprite): return
	_direction = -1 if direction < 0 else 1
	_enabled = enabled
	if _state_name != state_name:
		_state_name = state_name
		_state_seconds = 0.0
	var requested := state_name
	_drawn_attack = String(state_name).begins_with("attack_") and attack_pose != null and attack_pose.is_usable()
	var desired_frames: SpriteFrames = attack_pose.frames if _drawn_attack else _base_frames
	if sprite.sprite_frames != desired_frames: sprite.sprite_frames = desired_frames
	sprite.offset = -attack_pose.foot_origin if _drawn_attack else _base_sprite_offset
	if requested == &"attack": requested = &"thrust"
	elif requested == &"dash": requested = &"fall"
	elif String(requested).begins_with("attack_") or requested == &"tap": requested = &"ready"
	elif requested == &"death": requested = &"hurt"
	if _drawn_attack: requested = attack_pose.animation
	if not sprite.sprite_frames.has_animation(requested): requested = &"idle"
	if sprite.animation != requested: sprite.play(requested)
	var cycle_speed := 1.0
	if is_instance_valid(_actor):
		if enabled: _sample_landing()
		if requested == &"run" or requested == &"walk":
			var reference := run_reference_speed if requested == &"run" else walk_reference_speed
			cycle_speed = clampf(absf(_actor.velocity.x) / maxf(reference, 1.0), 0.2, 2.0)
	sprite.speed_scale = cycle_speed if enabled and not _drawn_attack else 0.0
	sprite.visible = shown
	sprite.self_modulate = Color(1.8, 1.6, 1.3) if highlight else Color.WHITE
	if is_instance_valid(weapon): weapon.visible = shown and state_name != &"death"
	_apply_body_pose()

func present_combat(attack_progress: float, combo: int, dashing: bool, tap_target: Vector2, tapping: bool) -> void:
	_attack_progress = attack_progress
	_combo = combo
	_dashing = dashing
	_tap_target = tap_target
	_tapping = tapping
	if _drawn_attack and _attack_progress >= 0.0:
		var timing := _attack_timing()
		sprite.set_frame_and_progress(attack_pose.frame_at(_attack_progress,timing.x,timing.y),0.0)
	_apply_body_pose()
	_apply_weapon_pose()

func _sample_landing() -> void:
	var grounded := _actor.is_on_floor()
	if grounded and not _was_grounded and _last_fall_speed > 90.0:
		_landing_remaining = landing_seconds
		_landing_strength = clampf(_last_fall_speed / 400.0, 0.3, 1.0)
	_was_grounded = grounded
	_last_fall_speed = maxf(0.0, _actor.velocity.y)

func _apply_body_pose() -> void:
	if not is_instance_valid(sprite): return
	var width := 1.0
	var height := 1.0
	var lean := 0.0
	if _state_name == &"dash":
		# A compact travelling tuck uses the existing bent-knee fall drawing.
		# One compression/release replaces an upright sliding ready silhouette.
		var tuck := sin(clampf(_state_seconds / _tuning_number(&"dash_seconds", 0.17), 0.0, 1.0) * PI)
		height -= roll_compression * tuck
		width += 0.06 * tuck
		lean = 0.18 * tuck
	elif _state_name == &"jump":
		height = 1.025
		lean = 0.025
	elif _state_name == &"fall":
		height = 0.985
	elif _state_name == &"windup":
		var anticipation := smoothstep(0.0, 0.18, _state_seconds)
		height -= 0.04 * anticipation
		lean = -0.07 * anticipation
	elif _state_name == &"attack":
		var recovery := 1.0 - smoothstep(0.0, _tuning_number(&"hit_remaining", 0.14), _state_seconds)
		lean = 0.085 * recovery
		height -= 0.025 * recovery
	elif _state_name == &"hurt":
		var recoil := 1.0 - smoothstep(0.0, 0.22, _state_seconds)
		lean = -0.08 * recoil
		height -= 0.04 * recoil
	elif String(_state_name).begins_with("attack_") and _attack_progress >= 0.0:
		var timing := _attack_timing()
		if _attack_progress < timing.x:
			var prepare := sin(clampf(_attack_progress / timing.x, 0.0, 1.0) * PI)
			lean = -0.075 * prepare
			height -= 0.035 * prepare
		else:
			var recovery := 1.0 - smoothstep(timing.x, 1.0, _attack_progress)
			lean = (0.11 if _combo == 3 else 0.075) * recovery
			height -= 0.02 * recovery
	if _landing_remaining > 0.0 and _was_grounded and _state_name != &"dash":
		var settle := _landing_remaining / maxf(landing_seconds, 0.01)
		var compression := landing_compression * _landing_strength * settle * settle
		height -= compression
		width += compression * 0.35
	width = lerpf(1.0, width, motion_amount)
	height = lerpf(1.0, height, motion_amount)
	lean *= motion_amount
	var drawing_scale: float = attack_pose.source_scale if _drawn_attack else 1.0
	# Explicit basis keeps every point on the y=0 foot line on that line even
	# while leaning, flipping, or compressing. Health/telegraph UI stays upright.
	sprite.transform = Transform2D(
		Vector2(_sprite_scale.x * width * _direction, 0.0) * drawing_scale,
		Vector2(-_sprite_scale.y * lean * _direction, _sprite_scale.y * height) * drawing_scale,
		_sprite_position)

func _attack_timing() -> Vector2:
	var duration := _tuning_number(&"finisher_seconds", 0.26) if _combo == 3 else _tuning_number(&"attack_seconds", 0.19)
	var hit_remaining := _tuning_number(&"finisher_hit_remaining", 0.22) if _combo == 3 else _tuning_number(&"attack_hit_remaining", 0.15)
	var contact := clampf(1.0 - hit_remaining / maxf(duration, 0.01), 0.04, 0.8)
	var end := minf(0.94, contact + _tuning_number(&"attack_active_seconds", 0.055) / maxf(duration, 0.01))
	return Vector2(contact, maxf(contact + 0.02, end))

func _apply_weapon_pose() -> void:
	if not is_instance_valid(weapon): return
	var anchors: Array = HAND_ANCHORS.get(sprite.animation, [Vector2(72, -170)])
	var hand: Vector2 = anchors[mini(sprite.frame, anchors.size() - 1)]
	if _drawn_attack: hand = attack_pose.hand_anchors[mini(sprite.frame,attack_pose.hand_anchors.size()-1)]
	weapon.position = sprite.transform * hand
	weapon.scale = Vector2(_direction, 1)
	var angle := REST_ANGLE
	var sweep := 0.0
	if _tapping:
		var difference := to_local(_tap_target) - weapon.position
		angle = Vector2(difference.x * _direction, difference.y).angle()
	elif _attack_progress >= 0.0:
		var timing := _attack_timing()
		var prepare_end := timing.x * 0.45
		var start := 1.35 if _combo == 2 else (-1.6 if _combo == 3 else -1.2)
		var finish := -1.1 if _combo == 2 else (1.35 if _combo == 3 else 1.05)
		if _attack_progress < prepare_end:
			angle = lerpf(REST_ANGLE, start, smoothstep(0.0, prepare_end, _attack_progress))
		elif _attack_progress < timing.x:
			angle = lerpf(start, 0.0, smoothstep(prepare_end, timing.x, _attack_progress))
		elif _attack_progress < timing.y:
			angle = lerpf(0.0, finish, smoothstep(timing.x, timing.y, _attack_progress))
		else:
			angle = lerpf(finish, REST_ANGLE, smoothstep(timing.y, 1.0, _attack_progress))
		if _attack_progress >= prepare_end and _attack_progress < timing.y:
			sweep = sin(inverse_lerp(prepare_end, timing.y, _attack_progress) * PI) * (-1.0 if _combo == 2 else 1.0)
	elif _dashing:
		angle = -0.3
	elif _state_name == &"jump":
		angle = 0.35
	elif _state_name == &"fall":
		angle = 0.65
	weapon.rotation = angle * _direction
	if weapon.has_method("present_sweep"): weapon.present_sweep(sweep * motion_amount)

func _tuning_number(property: StringName, fallback: float) -> float:
	if not is_instance_valid(_tuning): return fallback
	var value: Variant = _tuning.get(property)
	return float(value) if value != null else fallback

func weapon_tip() -> Vector2:
	if is_instance_valid(weapon): return weapon.to_global(Vector2(weapon.length, 0))
	return global_position + Vector2(_direction * 38, -26)

func present_status(hp: int, max_hp: int, force_health: bool, winding_up: bool) -> void:
	if is_instance_valid(health_bar):
		health_bar.max_value = max_hp
		health_bar.value = hp
		health_bar.visible = force_health or hp < max_hp
	if is_instance_valid(telegraph): telegraph.visible = winding_up
