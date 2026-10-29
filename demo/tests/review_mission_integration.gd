extends SceneTree
## Independent integration regression: true physics for PC strike/hurt/landing,
## input-driven enemy warning/schema probes, marker geometry and checkpoint boundaries.
## Run with isolated XDG dirs. Existing checkpoint bytes are restored afterward.
class SchemaInput extends Node:
	var frame := {}
	func sample_raw(_actor: Node, _dt: float) -> Dictionary: return frame
var host
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var observed: Array[Dictionary] = []
var committed: Array[Dictionary] = []
var diagnostics: Dictionary = {}
var hz := 120
var had_save := false
var save_bytes := PackedByteArray()
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz=int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second=hz
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks.append({"label":label,"passed":ok})
	if not ok:
		failures.append(label)
		push_error(label)
func on_bus(origin: Vector2, kind: StringName, loudness: float, source: Node) -> void:
	if is_instance_valid(host) and source == host.player:
		observed.append({"kind":kind,"origin":origin,"loudness":loudness,"audio":host.audio.last_spatial_sound.get("key","")})
func on_committed(event: Dictionary) -> void:
	committed.append(event.duplicate(true))
func observe_player() -> void:
	observed.clear()
	committed.clear()
	host.player.noise_committed.connect(on_committed)
func count_kind(events: Array, kind: StringName) -> int:
	var n := 0
	for event in events:
		if event.kind == kind: n += 1
	return n
func first_kind(events: Array, kind: StringName) -> Dictionary:
	for event in events:
		if event.kind == kind: return event
	return {}
func has_cache_geometry() -> bool:
	for g in host.sonar.geometry:
		if g.body.get_ref().name == "CacheContour": return true
	return false
func marker_matches(name_: String, at: Vector2, size: Vector2) -> bool:
	var marker = host.room.onward_marker.get_node_or_null("GateContour") if name_ == "Gate" else host.room.get_node_or_null(name_+"Contour")
	if name_ == "Cache": marker = host.room.field_cache.get_node_or_null("CacheContour")
	if name_ == "Station": marker = host.room.exchange_station.get_node_or_null("StationContour")
	if name_ == "Relay" and not host.room.relay_markers.is_empty(): marker = host.room.relay_markers[0].get_node_or_null("RelayContour")
	if marker == null: return false
	var shape: CollisionShape2D = marker.get_child(0)
	var rect: Rect2 = (host.room.global_transform.affine_inverse() * shape.global_transform) * shape.shape.get_rect()
	return rect.is_equal_approx(Rect2(at-Vector2(size.x*0.5,size.y),size))
func neutralize_enemies() -> void:
	for enemy in host.enemies: enemy.ai_enabled=false
func run() -> void:
	host=load("res://demo/mission.tscn").instantiate()
	had_save = FileAccess.file_exists(host.SAVE)
	if had_save: save_bytes = FileAccess.get_file_as_bytes(host.SAVE)
	root.add_child(host)
	host.bus.noise_emitted.connect(on_bus)
	host.start_new(true)
	host.input_override={}
	neutralize_enemies()
	for i in range(3): await physics_frame
	# Ordinary intention tests the genuine warning event; later explicit legacy
	# damage calls are sound-schema boundaries, not claims of physical contact.
	var enemy = host.enemies[0]
	host.sonar.clear_pulses()
	var schema_input := SchemaInput.new()
	enemy.add_child(schema_input)
	enemy.get_node("IntentDriver").source_path = enemy.get_node("IntentDriver").get_path_to(schema_input)
	for i in range(3): await physics_frame
	schema_input.frame = {"attack":true}
	for i in range(12):
		await physics_frame
		if enemy.ai_state == &"windup": break
	schema_input.frame = {}
	var pulse: Dictionary = host.sonar.pulses[-1]
	check(pulse.kind==&"enemy_windup","enemy warning uses shared sensory schema")
	check(not host.sonar.threat_mark(pulse).is_empty(),"enemy warning yields directional threat")
	check(host.audio.last_spatial_sound.key=="guard_draw","enemy warning uses telegraph audio")
	enemy.take_hit(0.1,1)
	pulse=host.sonar.pulses[-1]
	check(pulse.kind==&"enemy_damage" and not host.sonar.contact_mark(pulse).is_empty(),"enemy damage produces true HIT confirmation")
	check(host.audio.last_spatial_sound.key=="hit","enemy damage uses hit audio")
	enemy.take_hit(100,1)
	pulse=host.sonar.pulses[-1]
	check(pulse.kind==&"enemy_death" and not host.sonar.contact_mark(pulse).is_empty(),"enemy defeat produces true DOWN confirmation")
	check(host.sonar.threat_mark(host.sonar.pulses[0]).is_empty(),"later enemy damage retires stale warning")
	check(marker_matches("Gate",Vector2(float(host.sectors[0].width)-45,300),Vector2(40,76)),"gate contour matches rendered bounds")
	var original_room_transform: Transform2D = host.room.transform
	host.room.position=Vector2(31.25,-19.5);host.room.rotation=0.17;host.room.scale=Vector2(1.15,0.85)
	check(marker_matches("Gate",Vector2(float(host.sectors[0].width)-45,300),Vector2(40,76)),"gate local bounds remain exact under transformed room parent")
	host.room.transform=original_room_transform
	check(marker_matches("Cache",host.sectors[0].cache,Vector2(16,18)),"cache contour matches rendered bounds")
	check(has_cache_geometry(),"uncollected cache exists in sonar geometry")
	host.player.reset_actor(host.sectors[0].cache,1)
	host.interact()
	check(host.caches.has(0),"cache pickup records archive")
	check(not has_cache_geometry(),"picked cache is immediately absent from sonar")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(host.SAVE))
	check(saved.cache_ids.has(host.sectors[0].id),"archive pickup persists immediately")
	var kills_before: int=host.kills
	host.show_title()
	host.continue_run()
	check(host.caches.has(0),"title and continue retain collected archive")
	check(host.kills==kills_before,"title and continue retain current kill statistics")
	check(not has_cache_geometry(),"collected cache stays absent after room reload")
	host.load_sector(1)
	check(marker_matches("Relay",host.sectors[1].relay,Vector2(22,31)),"relay contour matches rendered bounds")
	original_room_transform = host.room.transform
	host.room.position=Vector2(31.25,-19.5);host.room.rotation=0.17;host.room.scale=Vector2(1.15,0.85)
	check(marker_matches("Relay",host.sectors[1].relay,Vector2(22,31)),"relay local bounds remain exact under transformed room parent")
	host.room.transform=original_room_transform
	host.load_sector(2)
	check(marker_matches("Station",host.sectors[2].station,Vector2(32,42)),"station contour matches rendered bounds")
	original_room_transform = host.room.transform
	host.room.position=Vector2(31.25,-19.5);host.room.rotation=0.17;host.room.scale=Vector2(1.15,0.85)
	check(marker_matches("Station",host.sectors[2].station,Vector2(32,42)),"station local bounds remain exact under transformed room parent")
	host.room.transform=original_room_transform
	# Genuine input-driven PC attack, with preserved raw commitment as origin oracle.
	host.start_new(true)
	neutralize_enemies()
	observe_player()
	for i in range(3): await physics_frame
	host.input_override={"attack":true}
	await physics_frame
	host.input_override={}
	for i in range(ceili(70.0*hz/120.0)): await physics_frame
	var raw_strike:=first_kind(committed,&"strike")
	var normalized_strike:=first_kind(observed,&"attack")
	check(not raw_strike.is_empty(),"physical PC active phase commits strike event")
	check(count_kind(observed,&"attack")==1 and count_kind(observed,&"strike")==0,"one PC strike becomes one normalized attack")
	check(not normalized_strike.is_empty() and normalized_strike.audio=="swing","physical PC strike uses swing audio")
	check(not raw_strike.is_empty() and not normalized_strike.is_empty() and Vector2(raw_strike.origin).is_equal_approx(normalized_strike.origin),"normalization preserves immutable PC strike origin")
	diagnostics["physical_swing"]=observed.duplicate(true)
	# Real enemy AI and physical rectangle contact, no direct receive_attack call.
	observed.clear()
	committed.clear()
	host.player.reset_actor(Vector2(700,300),1)
	enemy=host.enemies[0]
	enemy.reset_at(Vector2(735,300))
	enemy.ai_enabled=true
	for i in range(ceili(230.0*hz/120.0)): await physics_frame
	var raw_hurt:=first_kind(committed,&"hurt")
	var normalized_hurt:=first_kind(observed,&"player_damage")
	check(is_equal_approx(host.health.current_health,48.0),"one real enemy strike debits player health 60 to 48")
	check(count_kind(committed,&"hurt")==1,"one actual hurt was committed by PC")
	check(count_kind(observed,&"player_damage")==1 and count_kind(observed,&"hurt")==0,"one true hurt produces one damage pulse without duplicate")
	check(not normalized_hurt.is_empty() and normalized_hurt.audio=="hurt","true player damage uses hurt audio")
	check(not raw_hurt.is_empty() and not normalized_hurt.is_empty() and Vector2(raw_hurt.origin).is_equal_approx(normalized_hurt.origin),"damage pulse keeps PC committed origin instead of fabricated offset")
	var landing:=first_kind(observed,&"landing")
	check(not landing.is_empty() and landing.audio=="prop","physical recovery landing uses impact audio")
	diagnostics["physical_hit"]=observed.duplicate(true)
	# Paused hierarchy freezes all gameplay and genuine rigid-body travel.
	host.load_sector(0)
	neutralize_enemies()
	host.input_override={}
	var prop: RigidBody2D = get_nodes_in_group("props")[0]
	prop.launch(1)
	for i in range(10): await physics_frame
	host.state="paused"
	paused=true
	var prop_position:=prop.global_position
	var actor_position: Vector2=host.player.global_position
	var room_time: float=host.room.time
	var play_time: float=host.elapsed
	var sonar_time: float=host.sonar.elapsed
	var event_count: int=host.sonar.accepted_event_count
	for i in range(20): await physics_frame
	check(prop.global_position.is_equal_approx(prop_position),"pause freezes launched rigid prop")
	check(host.player.global_position.is_equal_approx(actor_position),"pause freezes physical player")
	check(is_equal_approx(host.room.time,room_time) and is_equal_approx(host.elapsed,play_time),"pause freezes room and active-play clocks")
	check(is_equal_approx(host.sonar.elapsed,sonar_time) and host.sonar.accepted_event_count==event_count,"pause freezes sonar fade and event intake")
	paused=false
	host.queue_free()
	await process_frame
	if had_save:
		var save=FileAccess.open("user://first_ascent_checkpoint.json",FileAccess.WRITE)
		save.store_buffer(save_bytes)
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path("user://first_ascent_checkpoint.json"))
	var report={"checks":checks,"failures":failures,"diagnostics":diagnostics,"engine":Engine.get_version_info().string,"physics_hz":hz,"scope":"Headless integration review. PC attack/hurt/landing and pause use real physics callbacks; enemy warning uses ordinary input; enemy damage schema, cache interactions and marker bounds use explicitly direct boundary probes. No rendered/manual full-route claim."}
	FileAccess.open("res://demo/evidence/review_mission_integration.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	FileAccess.open("res://demo/evidence/review_mission_integration_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("REVIEW INTEGRATION ",hz,"Hz ",checks.size()," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
