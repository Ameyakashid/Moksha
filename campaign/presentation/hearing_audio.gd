extends "res://scripts/systems/audio_director.gd"
## Listener-only sensory gate. NoiseBus and enemy perception remain untouched.
var hearing_enabled := true
func set_hearing_enabled(value: bool) -> void:
	if hearing_enabled==value:return
	hearing_enabled=value
	last_spatial_sound.clear()
	if not value:
		for voice in get_children():
			if voice is AudioStreamPlayer2D or (voice is AudioStreamPlayer and voice!=ambient):
				voice.stop();voice.queue_free()
		if is_instance_valid(ambient):ambient.stop()
	elif is_instance_valid(ambient) and DisplayServer.get_name()!="headless":ambient.play()
func play_at(key: String, origin: Vector2, db := -10.0, pitch := 1.0) -> void:
	if hearing_enabled:super.play_at(key,origin,db,pitch)
func play_sound(key: String, db := -10.0, pitch := 1.0):
	# Win is non-diegetic completion feedback. Intro hit and all world/body cues
	# are diegetic, including taps: captions and tactile state remain separate.
	if hearing_enabled or key=="win":super.play_sound(key,db,pitch)

func _ready() -> void:
	super._ready()
	cache["irritant_warning"] = load("res://audio/irritant_warning.wav")
	cache["irritant_hiss"] = load("res://audio/irritant_hiss.wav")
