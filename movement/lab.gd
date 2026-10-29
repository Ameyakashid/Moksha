extends Node2D
## One test room, one PC, one NPC. No combat/art/sonar dependencies.
@onready var player: MokshaMovementMotor = $Player
@onready var npc: MokshaMovementMotor = $NPC
@onready var camera: Camera2D = $Camera
@onready var ui: Control = $HUD/Panel
var paused := false
var recording: Array[Dictionary] = []
var recording_left := 0.0
var _capture_elapsed := 0.0
var _capture_index := 0
var _player_start := Vector2.ZERO
var _npc_start := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player_start = player.position
	_npc_start = npc.position
	camera.position = Vector2(320,350)
	ui.lab = self

func _process(dt: float) -> void:
	if not paused:
		camera.position.x = clampf(player.position.x,320,1600)
		var screen_y := player.position.y - camera.position.y + 180.0
		if screen_y < 115.0: camera.position.y = player.position.y + 65.0
		elif screen_y > 292.0: camera.position.y = player.position.y - 112.0
		camera.position.y = clampf(camera.position.y,190.0,460.0)
	if recording_left > 0.0:
		recording_left -= dt
		_capture_elapsed += dt
		if _capture_elapsed >= 0.10:
			_capture_elapsed = 0.0
			get_viewport().get_texture().get_image().save_png("res://delivery/movement_capture/frame_%04d.png" % _capture_index)
			_capture_index += 1
		recording.append({"time":Time.get_ticks_msec(),"x":player.position.x,"vx":player.velocity.x,"input":player.axis,"facing":player.facing,"state":player.state,"dash_direction":player.dash_direction})
		if recording_left <= 0.0:
			var file := FileAccess.open("res://delivery/MOKSHA-Movement-Trace.json",FileAccess.WRITE)
			if file: file.store_string(JSON.stringify(recording,"\t"))
	if player.position.y > 680: player.reset_at(_player_start)
	if npc.position.y > 680: npc.reset_at(_npc_start)
	ui.queue_redraw()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_ESCAPE:
			paused = not paused
			$Player.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_PAUSABLE
			$NPC.process_mode = Node.PROCESS_MODE_DISABLED if paused else Node.PROCESS_MODE_PAUSABLE
			$Player/Intent.clear_pending()
			player.clear_intent()
			npc.clear_intent()
		KEY_R: reset_room()
		KEY_H: player.apply_pause(0.12)
		KEY_I: player.apply_impulse(Vector2(-player.facing*300,-150))
		KEY_1: player.double_jump_enabled = not player.double_jump_enabled
		KEY_2: player.air_dash_enabled = not player.air_dash_enabled
		KEY_3: player.coyote_enabled = not player.coyote_enabled
		KEY_4: player.variable_jump_enabled = not player.variable_jump_enabled
		KEY_5: player.input_buffer_enabled = not player.input_buffer_enabled
		KEY_6: $NPC/Intent.chase_enabled = not $NPC/Intent.chase_enabled
		KEY_F8: get_tree().change_scene_to_file("res://main.tscn")
		KEY_F9:
			recording.clear()
			_capture_index = 0
			_capture_elapsed = 0.0
			DirAccess.make_dir_recursive_absolute("res://delivery/movement_capture")
			recording_left = 8.0
		KEY_F12:
			get_viewport().get_texture().get_image().save_png("res://delivery/MOKSHA-Movement-Lab.png")

func reset_room() -> void:
	paused = false
	$Player.process_mode = Node.PROCESS_MODE_PAUSABLE
	$NPC.process_mode = Node.PROCESS_MODE_PAUSABLE
	$Player/Intent.clear_pending()
	player.reset_at(_player_start)
	camera.position.y = 350.0
	npc.reset_at(_npc_start)
	if $NPC/Intent.has_method("reset"): $NPC/Intent.reset()

func _draw() -> void:
	for x in range(0,1921,40): draw_line(Vector2(x,90),Vector2(x,620),Color(0.12,0.18,0.22,0.6),1)
	for y in range(100,621,40): draw_line(Vector2(0,y),Vector2(1920,y),Color(0.12,0.18,0.22,0.6),1)
	draw_string(ThemeDB.fallback_font,Vector2(40,335),"01  REVERSE / BRAKE / CHASE",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("adc0cd"))
	draw_string(ThemeDB.fallback_font,Vector2(670,190),"02  SLOPE / LEDGE / JUMP",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("adc0cd"))
	draw_string(ThemeDB.fallback_font,Vector2(1330,180),"03  THIN WALL / CEILING / AIR DASH",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("adc0cd"))
