extends SceneTree
## Seeded flags and injected real NoiseBus event during inherited room setup.
## No claim of natural choice traversal, native playback or pixel review.
class Probe extends "res://campaign/logic/campaign.gd":
	var inspect_load:=false
	var samples:Array=[]
	func _update_gate()->void:
		super._update_gate()
		if inspect_load and _loading_campaign and is_instance_valid(player) and is_instance_valid(sonar):
			var before:int=sonar.pulses.size()
			bus.emit_noise(player.global_position-Vector2(0,18),&"weapon_tap",1.0,player)
			samples.append({"hearing_retained":hearing_retained,"sonar_enabled":sonar.hearing_enabled,"audio_enabled":audio.hearing_enabled,"geometry":sonar.geometry.size(),"pulse_delta":sonar.pulses.size()-before,"audio_intake":not audio.last_spatial_sound.is_empty()})
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var host=Probe.new();host.save_enabled=false;root.add_child(host);host.start_new(true);host.set_physics_process(false)
	var initial:int=host.sonar.geometry.size()
	check(initial>0,"initial retained New binds real geometry")
	var initial_layers:Array=[]
	for enemy in host.enemies:initial_layers.append([enemy.collision_layer,enemy.collision_mask,enemy.get_node("HearingSensor").enabled])
	host.hearing_retained=false;host._apply_senses();host.audio.muted=true
	check(host.sonar.geometry.is_empty(),"deaf seed has no stale geometry")
	host.inspect_load=true;host.start_new(true);host.set_physics_process(false)
	var restored_geometry:int=host.sonar.geometry.size()
	check(restored_geometry==initial,"New after deaf has identical initial retained geometry")
	check(host.audio.muted,"selected hearing capability does not reset global mute preference")
	check(not host.samples.is_empty(),"inherited setup boundary was actually observed")
	for sample in host.samples:
		check(sample.hearing_retained and sample.sonar_enabled and sample.audio_enabled,"retained gates enabled before inherited setup")
		check(sample.geometry==initial and sample.pulse_delta==1 and sample.audio_intake,"retained setup tap uses normal geometry and listener intake")
	var after_layers:Array=[]
	for enemy in host.enemies:after_layers.append([enemy.collision_layer,enemy.collision_mask,enemy.get_node("HearingSensor").enabled])
	check(initial_layers==after_layers,"New listener transition leaves enemy collision/hearing masks unchanged")
	host.samples.clear();host.hearing_retained=false;host.load_sector(1);host.set_physics_process(false)
	check(not host.samples.is_empty(),"deaf inherited setup boundary was actually observed")
	for sample in host.samples:
		check(not sample.hearing_retained and not sample.sonar_enabled and not sample.audio_enabled,"deaf gates disabled before inherited setup")
		check(sample.geometry==0 and sample.pulse_delta==0 and not sample.audio_intake,"no transient deaf geometry pulse or audio intake during setup")
	check(host.sonar.geometry.is_empty() and host.sonar.pulses.is_empty() and host.sonar.event_history.is_empty(),"deaf output stays empty after setup")
	check(not host.sonar.hearing_enabled and not host.audio.hearing_enabled and host.audio.muted,"deaf gates and independent mute remain unchanged")
	for enemy in host.enemies:check(enemy.get_node("HearingSensor").enabled,"player hearing loss leaves enemy hearing enabled")
	var evidence:Dictionary={"checks":checks,"passed":failures.is_empty(),"failures":failures,"initial_retained_geometry":initial,"new_after_deaf_geometry":restored_geometry,"deaf_load_samples":host.samples.duplicate(true),"scope":"Seeded load-boundary fixture with real NoiseBus injection; not native/audio listening"}
	host.free();await process_frame
	print(JSON.stringify(evidence));quit(0 if failures.is_empty() else 1)
