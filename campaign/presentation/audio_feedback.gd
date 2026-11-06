extends RefCounted
## Campaign-only ownership of modal feedback and retiring room one-shots.
## No audio generation, cue remapping, noise emission or global mix changes.
var _pending_hurt:WeakRef
var _hurt_physics_frame:=-1
func observe_damage(audio:Node,first_child:int)->void:
	_pending_hurt=null;_hurt_physics_frame=-1
	for i in range(first_child,audio.get_child_count()):
		var voice=audio.get_child(i)
		if voice is AudioStreamPlayer2D and voice.stream==audio.cache.get("hurt"):
			_pending_hurt=weakref(voice)
			_hurt_physics_frame=Engine.get_physics_frames()
	if audio.get_tree().paused:finish_damage()
func finish_damage()->void:
	var voice=_pending_hurt.get_ref() if _pending_hurt!=null else null
	var current_frame:=_hurt_physics_frame==Engine.get_physics_frames()
	_pending_hurt=null;_hurt_physics_frame=-1
	# Defeat can follow committed hurt noise before its first physics callback.
	# Never promote an older already-playing world cue.
	if current_frame and is_instance_valid(voice) and not voice.is_queued_for_deletion() and voice.get_playback_position()==0.0:
		_finish(voice)
func finish_modal_since(audio:Node,first_child:int,key:String)->void:
	# Only the fresh cue belonging to this interaction crosses the pause.
	for i in range(first_child,audio.get_child_count()):
		var voice=audio.get_child(i)
		if voice is AudioStreamPlayer2D and voice.stream==audio.cache.get(key):_finish(voice)
func _finish(voice:AudioStreamPlayer2D)->void:
	voice.process_mode=Node.PROCESS_MODE_ALWAYS
	voice.stream_paused=false
func retire_room(audio:Node)->void:
	_pending_hurt=null;_hurt_physics_frame=-1
	if not is_instance_valid(audio):return
	for voice in audio.get_children():
		if voice is AudioStreamPlayer2D:
			voice.stop();voice.queue_free()
