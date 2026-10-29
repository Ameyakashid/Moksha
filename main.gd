extends Node2D
## Session orchestration only: two scenes, sensory choice, camera and presentation.
@export var starting_level: PackedScene
@export_file("*.tscn") var run_entry_path := "res://scenes/levels/city_prologue.tscn"
@export_range(1.0, 2.0, 0.05) var sight_speed_multiplier := 1.25
@export_range(0.0, 0.08, 0.005) var impact_pause_seconds := 0.035
var current_level: Node2D
var current_scene: PackedScene
var player: CharacterBody2D
var level_title := "CITY PROLOGUE"
var level_number := 1
var sight_sacrificed := false
var first_ascent_landed := false
var shrine_used := false
var kills := 0
var total := 0
var prop_hits := 0
var prop_kills := 0
var run_time := 0.0
var room_time := 0.0
var t := 0.0
var shake := 0.0
var flash := 0.0
var intro_time := 7.0
var notice := ""
var notice_time := 0.0
var interaction_cooldown := 0.0
var state := "playing":
	set(value):
		state = value
		_apply_simulation_state()
var camera_target := Vector2(320,180)
@onready var level_host: Node2D = $LevelHost
@onready var camera: Camera2D = $Camera2D
@onready var effects: Node2D = $VisualEffects
@onready var audio: Node = $AudioDirector
@onready var sonar: Node = $SonarView
@onready var hud: Node2D = $HUD/Overlay

func _ready() -> void:
	add_to_group("run_controllers")
	hud.game = self
	var bus = get_node_or_null("/root/NoiseBus")
	if bus: bus.noise_emitted.connect(_on_noise)
	if starting_level: load_level(starting_level)

func load_level(scene: PackedScene) -> void:
	state = "transition"
	sonar.clear_pulses()
	sonar.set_blind(false)
	if is_instance_valid(current_level): current_level.free()
	effects.clear_effects()
	var bus = get_node_or_null("/root/NoiseBus")
	if bus and bus.has_method("clear_history"): bus.clear_history()
	current_scene = scene
	current_level = scene.instantiate()
	level_host.add_child(current_level)
	player = current_level.get_node("Actors/Player")
	level_title = current_level.level_title
	level_number = 2 if current_level.sensory_required else 1
	sight_sacrificed = false
	first_ascent_landed = false
	shrine_used = false
	kills = 0; total = 0; prop_hits = 0; prop_kills = 0
	room_time = 0.0; intro_time = 7.0; shake = 0.0; flash = 0.0
	interaction_cooldown = 0.35
	for actor in get_tree().get_nodes_in_group("actors"):
		if current_level.is_ancestor_of(actor): register_actor(actor)
	player.died.connect(_on_player_died)
	player.damaged.connect(_on_player_damaged)
	player.attack_requested.connect(effects.slash)
	player.ghost_requested.connect(effects.ghost)
	player.flash_requested.connect(_on_flash)
	player.speed_multiplier = 1.0
	player.world_limits_enabled = true
	player.horizontal_limits = Vector2(current_level.camera_bounds.position.x+12,current_level.camera_bounds.end.x-12)
	player.fall_death_y = current_level.camera_bounds.end.y+90
	sonar.bind_level(current_level,player)
	sonar.preview_when_sighted = false
	state = "playing"
	camera_target = _clamped_camera(player.global_position+Vector2(50,-70))
	camera.position = camera_target
	_update_landmarks()
	show_notice("NO POWERS. MAKE YOUR WAY TO THE ARCOLOGY." if level_number==1 else "THE FIRST TRADE: REACH THE SENSORY STATION.",4.5)

func register_actor(actor: Node) -> void:
	if actor.get_meta("moksha_session",0)==get_instance_id(): return
	actor.set_meta("moksha_session",get_instance_id())
	if actor.has_signal("sound_requested"): actor.sound_requested.connect(audio.play_sound)
	if actor.has_signal("burst_requested"): actor.burst_requested.connect(effects.burst)
	if actor.has_signal("text_requested"): actor.text_requested.connect(effects.float_text)
	if actor.has_signal("shake_requested"): actor.shake_requested.connect(_on_shake)
	if actor.is_in_group("enemies"):
		total += 1
		actor.died.connect(_on_enemy_died)
		actor.damaged.connect(_on_enemy_damaged)
	if actor.is_in_group("props"): actor.impacted.connect(_on_prop_impacted)
	actor.simulation_enabled = state=="playing"

func _apply_simulation_state() -> void:
	if not is_instance_valid(current_level): return
	var active := state=="playing"
	for actor in get_tree().get_nodes_in_group("actors"):
		if current_level.is_ancestor_of(actor): actor.simulation_enabled = active
	if is_instance_valid(effects): effects.simulation_enabled = active
	if is_instance_valid(sonar): sonar.simulation_enabled = active

func _on_enemy_died(_actor: Node2D, by_prop: bool) -> void:
	kills += 1
	if by_prop: prop_kills += 1
func _on_enemy_damaged(_actor: Node2D, _damage: int, _direction: float, _by_prop: bool) -> void:
	if is_instance_valid(player): player.apply_hitpause(impact_pause_seconds)
func _on_prop_impacted(_prop: Node, _target: Node, _damage: int, _direction: float) -> void: prop_hits += 1
func _on_player_died(_actor: Node2D) -> void: state = "dead"
func _on_player_damaged(_actor: Node2D, _amount: int, _direction: float) -> void:
	if is_instance_valid(player): player.apply_hitpause(impact_pause_seconds)
func _on_shake(amount: float) -> void: shake = maxf(shake,minf(amount,4.0))
func _on_flash(seconds: float) -> void: flash = maxf(flash,seconds)
func _on_noise(origin: Vector2, kind: StringName, _loudness: float, source: Node) -> void:
	if state != "playing" or not is_instance_valid(current_level) or not is_instance_valid(source): return
	if source != current_level and not current_level.is_ancestor_of(source): return
	if kind==&"weapon_tap": audio.play_at("tap",origin,-13.0,1.0)
	elif kind in [&"enemy_step",&"player_step"]: audio.play_at("step",origin,-25.0,0.9 if kind==&"enemy_step" else 1.15)
	elif kind==&"enemy_windup": audio.play_at("guard_draw",origin,-9.0,1.0)
	elif kind==&"enemy_attack": audio.play_at("swing",origin,-11.0,0.8)

func show_notice(text: String, duration := 3.0) -> void:
	notice = text
	notice_time = duration

func _update_landmarks() -> void:
	var gate = current_level.get_node_or_null("GateVisual")
	if gate and gate.has_method("set_unlocked"): gate.set_unlocked(not current_level.sensory_required or sight_sacrificed)
	var station = current_level.get_node_or_null("SacrificeVisual")
	if station and station.has_method("set_spent"): station.set_spent(sight_sacrificed)
	var barrier = current_level.get_node_or_null("GateBarrier")
	if barrier:
		if barrier.has_method("set_open"): barrier.set_open(sight_sacrificed)
		elif barrier is CollisionObject2D: barrier.collision_layer = 0 if sight_sacrificed else 1

func sacrifice_sight() -> bool:
	if state!="playing" or sight_sacrificed or not current_level.sensory_required: return false
	var station = current_level.get_node_or_null("SacrificeAnchor")
	if station==null or player.global_position.distance_to(station.global_position)>65: return false
	sight_sacrificed = true
	player.speed_multiplier = sight_speed_multiplier
	player.heal_to_full()
	sonar.set_blind(true)
	_update_landmarks()
	var bus = get_node_or_null("/root/NoiseBus")
	if bus: bus.emit_noise(station.global_position,&"sacrifice",1.35,station)
	audio.play_sound("win",-16.0,0.8)
	show_notice("SIGHT TRADED / +%d%% SPEED. HOLD Q TO TAP. FOLLOW WHITE ECHOES." % roundi((sight_speed_multiplier-1.0)*100),7.0)
	return true

func interaction_prompt() -> String:
	if state!="playing" or not is_instance_valid(player): return ""
	var station = current_level.get_node_or_null("SacrificeAnchor")
	if station and player.global_position.distance_to(station.global_position)<65 and not sight_sacrificed:
		return "E  TRADE SIGHT / GAIN +%d%% SPEED" % roundi((sight_speed_multiplier-1.0)*100)
	var gate = current_level.get_node_or_null("GateAnchor")
	if gate and player.global_position.distance_to(gate.global_position)<65:
		if current_level.sensory_required and not sight_sacrificed: return "THE ASCENT REQUIRES THE SIGHT TRADE"
		return "E  ENTER THE ARCOLOGY" if has_next_level() else "E  COMPLETE THE FIRST ASCENT"
	return ""

func navigation_hint() -> String:
	if not sight_sacrificed: return ""
	if not first_ascent_landed: return "HOLD SPACE, PRESS AGAIN NEAR THE TOP / HOLD Q TO MAP"
	return "HOLD Q: TAP / DRAW > WARNS OF A GUARD STRIKE"

func interact() -> bool:
	if state!="playing" or interaction_cooldown>0: return false
	interaction_cooldown = 0.3
	if sacrifice_sight(): return true
	var gate = current_level.get_node_or_null("GateAnchor")
	if gate==null or player.global_position.distance_to(gate.global_position)>65: return false
	if current_level.sensory_required and not sight_sacrificed: return false
	if has_next_level():
		load_level(load(current_level.next_level_path))
	else:
		state = "won"
		audio.play_sound("win",-8.0,1.0)
	return true

func has_next_level() -> bool:
	return is_instance_valid(current_level) and not current_level.next_level_path.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F12:
		get_viewport().get_texture().get_image().save_png("res://delivery/MOKSHA-gameplay.png")
	if event.is_action_pressed("new_run"):
		run_time = 0.0
		load_level(load(run_entry_path))
	elif event.is_action_pressed("restart") and current_scene:
		load_level(current_scene)
	elif event.is_action_pressed("interact") or event.is_action_pressed("next_level"):
		interact()
	elif event.is_action_pressed("pause") and state in ["playing","paused"]:
		state = "playing" if state=="paused" else "paused"
	elif event.is_action_pressed("mute"): audio.toggle_mute()

func _clamped_camera(at: Vector2) -> Vector2:
	var bounds: Rect2 = current_level.camera_bounds
	return Vector2(clampf(at.x,bounds.position.x+320,bounds.end.x-320),clampf(at.y,bounds.position.y+180,bounds.end.y-180))

func _physics_process(dt: float) -> void:
	if not is_instance_valid(player): return
	t += dt
	if state=="playing":
		run_time += dt; room_time += dt
		interaction_cooldown = maxf(0,interaction_cooldown-dt)
		notice_time = maxf(0,notice_time-dt)
		intro_time = maxf(0,intro_time-dt)
		if sight_sacrificed and player.is_on_floor() and player.global_position.y <= current_level.first_ascent_landing_y + 2.0:
			first_ascent_landed = true
		camera_target = camera_target.lerp(_clamped_camera(player.global_position+Vector2(player.facing*55,-65)),minf(1.0,dt*8.0))
		var shrine = current_level.get_node_or_null("ShrineAnchor")
		if shrine and not shrine_used and player.global_position.distance_to(shrine.global_position)<35:
			shrine_used = true
			player.heal_to_full()
			show_notice("FIELD KIT / HEALTH RESTORED",2.0)
	if state!="paused":
		shake = move_toward(shake,0,dt*30)
		flash = maxf(0,flash-dt)
	camera.position = camera_target.round()+Vector2(randf_range(-shake,shake),randf_range(-shake,shake))
