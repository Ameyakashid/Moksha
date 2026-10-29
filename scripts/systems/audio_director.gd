extends Node
## Audio presentation service. Actors request sounds through signals.
@export_range(-40.0, 0.0) var ambience_volume_db := -3.0
var muted := false
var cache: Dictionary = {}
var ambient: AudioStreamPlayer
var last_spatial_sound: Dictionary = {}

func _ready():
	for key in ["swing","hit","jump","dash","prop","hurt","win","ambience","tap","step","guard_draw"]:
		cache[key] = load("res://audio/"+key+".wav")
	ambient = AudioStreamPlayer.new()
	ambient.stream = cache.ambience
	if ambient.stream is AudioStreamWAV:
		ambient.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		ambient.stream.loop_end = 220500
	ambient.volume_db = ambience_volume_db
	add_child(ambient)
	if DisplayServer.get_name() != "headless": ambient.play()

func play_sound(key: String, db := -10.0, pitch := 1.0):
	if muted or DisplayServer.get_name()=="headless" or not cache.has(key): return
	var voice := AudioStreamPlayer.new()
	voice.stream = cache[key]
	voice.volume_db = db
	voice.pitch_scale = pitch*randf_range(0.95,1.05)
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

func play_at(key: String, origin: Vector2, db := -10.0, pitch := 1.0) -> void:
	## Keep actual noise origins audible in space as well as visible through sonar.
	last_spatial_sound = {"key": key, "origin": origin, "volume_db": db, "pitch": pitch}
	if muted or DisplayServer.get_name()=="headless" or not cache.has(key): return
	var voice := AudioStreamPlayer2D.new()
	voice.stream = cache[key]
	voice.position = origin
	voice.volume_db = db
	voice.pitch_scale = pitch
	voice.max_distance = 520.0
	voice.attenuation = 1.25
	voice.panning_strength = 1.15
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()

func toggle_mute():
	muted = not muted
	AudioServer.set_bus_mute(0,muted)

func _exit_tree():
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer2D:
			child.stop()
			child.stream = null
	cache.clear()
