extends "res://simulation/components/boundary_scope.gd"
## Mission-level composition only. The preserved PC owns movement and combat;
## detachable enemies, health, noise and sensory services own their domains.
const Data = preload("res://demo/mission_data.gd")
const PlayerScene = preload("res://combat_pc/player.tscn")
const RoomScript = preload("res://demo/components/mission_room.gd")
const HealthScene = preload("res://combat_pc/components/health_component.tscn")
const DefeatScene = preload("res://combat_pc/components/defeat_response.tscn")
const RelayScene = preload("res://combat_pc/components/noise_relay.tscn")
const Checkpoint = preload("res://demo/components/checkpoint_codec.gd")
const SAVE := "user://first_ascent_expanded_checkpoint.json"
var sectors: Array[Dictionary] = Data.sectors()
var sector := 0
var room: Node2D
var player: CharacterBody2D
var health: Node
var sonar: CanvasLayer
var audio: Node
var camera: Camera2D
var hud: Node2D
var body_echo: Node2D
var bus: Node
var state := "title"
var blind := false
var traded_here := false
var relay_on := false
var relay_states: Array[int] = []
var enemies: Array[Node] = []
var caches: Array[int] = []
var kills := 0
var deaths := 0
var elapsed := 0.0
var sector_elapsed := 0.0
var notice := ""
var notice_left := 0.0
var chapter_left := 0.0
var tap_cooldown := 0.0
var intro_time := 0.0
var intro_caught := false
var archive_text := ""
var input_override: Variant = null
var metrics: Array[Dictionary] = []
var _checkpoint_error := ""
var _checkpoint_write_error := ""
var save_enabled := true
var continue_available := false
var _pending_sector := -1
var _pending_retry := false
var _base_speed := 218.0
var _base_roll: Array[float] = []

func _ready() -> void:
	super._ready()
	process_mode = Node.PROCESS_MODE_ALWAYS
	bus = get_node("/root/NoiseBus")
	bus.noise_emitted.connect(_on_noise)
	camera = Camera2D.new()
	camera.position = Vector2(320,180)
	add_child(camera)
	sonar = CanvasLayer.new()
	sonar.set_script(preload("res://demo/components/mission_sonar.gd"))
	sonar.tuning = preload("res://resources/sensory/sonar_default.tres").duplicate(true)
	add_child(sonar)
	sonar.tuning.draw_proprioception = false
	var body_layer := CanvasLayer.new()
	body_layer.layer = 21
	add_child(body_layer)
	body_echo = preload("res://simulation/ui/body_echo.tscn").instantiate()
	body_layer.add_child(body_echo)
	audio = Node.new()
	audio.set_script(preload("res://scripts/systems/audio_director.gd"))
	audio.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(audio)
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	hud = preload("res://simulation/ui/mission_hud.tscn").instantiate()
	layer.add_child(hud)
	continue_available = _valid_save()
	hud.set_snapshot(_hud_snapshot())
	get_tree().paused = true

func start_new(skip_intro := false) -> void:
	blind = false
	sector = 0
	caches.clear()
	kills = 0
	deaths = 0
	elapsed = 0
	metrics.clear()
	load_sector(0)
	if not skip_intro:
		state = "intro"
		intro_time = 0
		intro_caught = false
		get_tree().paused = true

func _create_player_health() -> Node:
	# Assembly hook: select the health authority before the actor enters the tree.
	return HealthScene.instantiate()

func load_sector(index: int) -> void:
	get_tree().paused = false
	if is_instance_valid(room):
		sonar.bind_level(null,null)
		room.free()
	enemies.clear()
	bus.clear_history()
	sector = clampi(index,0,sectors.size()-1)
	sector_elapsed = 0
	relay_on = false
	relay_states.clear()
	traded_here = blind
	room = Node2D.new()
	room.set_script(RoomScript)
	room.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(room)
	room.build(sectors[sector])
	room.set_cache_found(caches.has(sector))
	player = PlayerScene.instantiate()
	player.name = "Player"
	player.automatic_physics = false
	player.profile = preload("res://combat_pc/resources/air_response_agile.tres").duplicate(true)
	player.combat_profile = preload("res://combat_pc/resources/combat_profile.tres").duplicate(true)
	player.melee_chain = preload("res://combat_pc/resources/responsive_chain.tres")
	# View remains optional and can be swapped without affecting any contact.
	var lithe = load("res://combat_pc/visuals/lithe_wireframe.gd") if ResourceLoader.exists("res://combat_pc/visuals/lithe_wireframe.gd") else null
	if lithe != null: player.get_node("Visual").set_script(lithe)
	player.get_node("Visual").ground_presentation = preload("res://combat_pc/resources/ground_presentation_agile.tres")
	health = _create_player_health()
	health.name = "Health"
	health.maximum_health = 60.0
	player.add_child(health)
	var defeat = DefeatScene.instantiate()
	defeat.name = "DefeatResponse"
	player.add_child(defeat)
	var relay = RelayScene.instantiate()
	relay.name = "NoiseRelay"
	relay.set_script(preload("res://demo/components/mission_noise_relay.gd"))
	player.add_child(relay)
	var incoming = preload("res://simulation/components/incoming_strike_receiver.tscn").instantiate()
	incoming.counterable = true
	player.get_node("BodyShape").add_child(incoming)
	var contact_config := Node.new()
	contact_config.name = "ContactConfig"
	contact_config.set_script(preload("res://simulation/components/actor_contact_config.gd"))
	contact_config.profile = preload("res://demo/resources/player_contact.tres")
	player.add_child(contact_config)
	var impact = preload("res://simulation/components/physical_impact_receiver.tscn").instantiate()
	player.add_child(impact)
	player.add_child(preload("res://simulation/components/boundary_receiver.tscn").instantiate())
	var projectile_receiver := Node.new()
	projectile_receiver.name = "ProjectileReceiver"
	projectile_receiver.set_script(preload("res://simulation/components/projectile_receiver.gd"))
	projectile_receiver.accepted_source_layers = 32
	player.add_child(projectile_receiver)
	room.add_child(player)
	relay.bind(player,bus)
	player.reset_actor(sectors[sector].get("spawn",Vector2(75,300)),1)
	_base_speed = player.profile.run_speed
	_base_roll = [player.combat_profile.roll_start_speed,player.combat_profile.roll_end_speed,player.combat_profile.roll_exit_speed_limit]
	_apply_trade()
	defeat.defeat_started.connect(_on_player_defeat.bind(weakref(player), weakref(defeat)))
	for spec in sectors[sector].enemies:
		var scene_path := "res://demo/components/enemy.tscn"
		if str(spec[1]) in ["sentinel", "listener"]: scene_path = "res://demo/components/shared_sentinel.tscn"
		elif str(spec[1]) == "sentry": scene_path = "res://demo/components/shared_sentry.tscn"
		elif str(spec[1]) == "warden": scene_path = "res://demo/components/shared_warden.tscn"
		var scene = load(scene_path)
		if scene == null: continue
		var enemy = scene.instantiate()
		enemy.kind = str(spec[1])
		if enemy.kind == "listener": enemy.archetype_profile = preload("res://demo/resources/listener_archetype.tres")
		enemy.attack_damage_override = 18.0 if enemy.kind == "warden" else 12.0
		if enemy.kind == "warden": enemy.max_health = 16.0
		enemy.room_left = 40
		enemy.room_right = float(sectors[sector].width)-50
		enemy.position = Vector2(float(spec[0]),float(spec[2]) if spec.size()>2 else room.surface_y(float(spec[0])))
		room.add_child(enemy)
		enemy.configure(player,bus)
		enemy.defeated.connect(_on_enemy_defeated)
		enemies.append(enemy)
	for x in sectors[sector].props:
		var prop = preload("res://simulation/world/mission_cargo.tscn").instantiate()
		var prop_x := float(x[0]) if x is Array else float(x)
		var prop_y: float = float(x[1]) if x is Array else room.surface_y(prop_x)
		prop.position = Vector2(prop_x,prop_y-15)
		room.add_child(prop)
	sonar.bind_level(room,player)
	sonar.set_blind(blind)
	sonar.preview_when_sighted = true
	sonar.process_mode = Node.PROCESS_MODE_PAUSABLE
	camera.position = Vector2(320,180)
	state = "playing"
	chapter_left = 6.0
	notice_left = 0
	tap_cooldown = 0
	_update_gate()
	_save_checkpoint()

func _apply_trade() -> void:
	var scale := 1.25 if blind else 1.0
	player.profile.run_speed = _base_speed*scale
	player.combat_profile.roll_start_speed = _base_roll[0]*scale
	player.combat_profile.roll_end_speed = _base_roll[1]*scale
	player.combat_profile.roll_exit_speed_limit = _base_roll[2]*scale
	sonar.tuning.base_range = 440.0 if blind else 370.0
	sonar.tuning.trail_seconds = 0.67 if blind else 0.53

func _physics_process(dt: float) -> void:
	if _pending_sector >= 0:
		var next := _pending_sector
		_pending_sector = -1
		load_sector(next)
	if _pending_retry:
		_pending_retry = false
		load_sector(sector)
	if state != "playing": return
	elapsed += dt
	sector_elapsed += dt
	tap_cooldown = maxf(0,tap_cooldown-dt)
	notice_left = maxf(0,notice_left-dt)
	chapter_left = maxf(0,chapter_left-dt)
	player.physics_tick(dt,input_override)
	camera.position.x = clampf(player.position.x+player.velocity.x*0.13,320,float(sectors[sector].width)-320)
	camera.position.y = clampf(player.position.y-105,float(sectors[sector].get("top",-100))+180,180)
	_update_gate()

func _process(dt: float) -> void:
	if state == "intro":
		intro_time += dt
		if intro_time > 1.15 and not intro_caught:
			intro_caught = true
			audio.play_sound("hit",-8,0.85)
		if intro_time >= 3.7:
			state = "playing"
			get_tree().paused = false
	if is_instance_valid(hud): hud.set_snapshot(_hud_snapshot())
	if is_instance_valid(body_echo):
		body_echo.enabled = blind and is_instance_valid(player) and state not in ["title", "complete"]
		body_echo.source_visual = player.get_node_or_null("Visual") if is_instance_valid(player) else null

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode
	if key == KEY_M:
		audio.toggle_mute()
		return
	if key == KEY_F12 and DisplayServer.get_name() != "headless":
		get_viewport().get_texture().get_image().save_png("user://first_ascent_%d.png" % Time.get_ticks_msec())
		return
	match state:
		"title":
			if key == KEY_ENTER: start_new()
			elif key == KEY_C and continue_available: continue_run()
		"intro":
			if key in [KEY_ENTER,KEY_SPACE,KEY_ESCAPE]:
				state = "playing"
				get_tree().paused = false
		"playing":
			if key == KEY_ESCAPE:
				state = "paused"
				get_tree().paused = true
			elif key == KEY_Q: tap_weapon()
			elif key == KEY_E: interact()
			elif key == KEY_R: _pending_retry = true
		"archive":
			if key in [KEY_E,KEY_ESCAPE,KEY_ENTER]:
				state="playing"
				get_tree().paused=false
		"choice":
			if key == KEY_J: choose_sight(true)
			elif key in [KEY_K,KEY_ESCAPE]: choose_sight(false)
		"paused":
			if key == KEY_ESCAPE:
				state = "playing"
				get_tree().paused = false
			elif key == KEY_R:
				_pending_retry = true
			elif key == KEY_N: show_title()
		"dead":
			if key in [KEY_R,KEY_ENTER]: _pending_retry = true
			elif key == KEY_N: show_title()
		"complete":
			if key in [KEY_N,KEY_ENTER]: show_title()

func tap_weapon() -> void:
	if state != "playing" or tap_cooldown > 0: return
	tap_cooldown = 0.36
	bus.emit_noise(player.global_position+Vector2(player.facing*12,-17),&"weapon_tap",1.0,player)

func interact() -> void:
	if state != "playing": return
	var d: Dictionary = sectors[sector]
	if d.has("freight") and _near(d.freight.cradle,60):
		if room.freight_receiver.is_latched:
			announce("FREIGHT SEATED · passage unlocked",2)
		else:
			room.freight_cradle.replace_cargo()
			sonar.refresh_geometry()
			announce("CARGO REPLACED · stand left and strike J toward the receiver",3)
		return
	var relay_points := _relay_points()
	for relay_index in relay_points.size():
		if _near(relay_points[relay_index]) and not relay_states.has(relay_index):
			relay_states.append(relay_index)
			room.activated_relays = relay_states.duplicate()
			relay_on = relay_states.size() == relay_points.size()
			room.relay_on = relay_on
			bus.emit_noise(relay_points[relay_index]-Vector2(0,20),&"prop_impact",1.4,room)
			announce("RELAY ONLINE · %d / %d active" % [relay_states.size(),relay_points.size()],3)
			_update_gate()
			return
	if d.has("station") and _near(d.station) and not blind:
		state = "choice"
		get_tree().paused = true
		return
	if d.has("cache") and _near(d.cache) and not caches.has(sector):
		caches.append(sector)
		room.set_cache_found(true)
		sonar.refresh_geometry()
		_save_checkpoint()
		health.reset_to_full()
		bus.emit_noise(d.cache-Vector2(0,10),&"weapon_tap",0.8,room)
		announce("FIELD CACHE · health restored · archive %d / %d" % [caches.size(),_cache_total()],4)
		archive_text = d.get("archive","A field record recovered.")
		state="archive"
		get_tree().paused=true
		return
	if _near(Vector2(float(d.width)-45,float(d.get("gate_y",300))),65):
		if not room.gate_open:
			announce("Seat freight in the receiver first" if d.has("freight") and not room.freight_receiver.is_latched else "Restore the remaining relay circuits" if not _relay_points().is_empty() and not relay_on else "Security seal · defeat the remaining guards",3)
			return
		metrics.append({"sector":sector,"seconds":snappedf(sector_elapsed,0.01),"blind":blind,"health":health.current_health})
		if d.get("ending",false): complete_run()
		else: _pending_sector = sector+1
	else: announce("E: use a nearby relay, cache, station or onward door",2)

func _cache_total() -> int:
	var total:=0
	for area in sectors:
		if area.has("cache"): total+=1
	return total

func _relay_points() -> Array:
	var d: Dictionary = sectors[sector]
	return d.get("relays",[d.relay] if d.has("relay") else [])

func _near(point: Vector2, radius := 45.0) -> bool:
	return player.global_position.distance_to(point) < radius

func choose_sight(accept: bool) -> void:
	if state != "choice": return
	if accept:
		blind = true
		traded_here = true
		_apply_trade()
		health.reset_to_full()
		sonar.set_blind(true)
	state = "playing"
	get_tree().paused = false
	if accept:
		bus.emit_noise(player.global_position-Vector2(0,16),&"prop_impact",1.8,player)
		announce("SIGHT TRADED · +25% run / roll · Q reveals the way",5)
		_save_checkpoint()
	else: announce("SIGHT RETAINED · the onward route remains open",3)

func _update_gate() -> void:
	var d: Dictionary = sectors[sector]
	room.gate_open = (not d.has("freight") or room.freight_receiver.is_latched) and (_relay_points().is_empty() or relay_on) and (not d.get("lock",false) or remaining_enemies()==0)

func remaining_enemies() -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead: count += 1
	return count

func _on_enemy_defeated(_enemy: Node) -> void:
	kills += 1
	_update_gate()

func _on_player_defeat(actor_ref: WeakRef, response_ref: WeakRef) -> void:
	var actor: Variant = actor_ref.get_ref()
	var response: Variant = response_ref.get_ref()
	if not is_instance_valid(actor) or actor != player or not is_instance_valid(response) or response != player.get_node_or_null("DefeatResponse"): return
	if not actor.is_inside_tree() or actor.is_queued_for_deletion() or not response.active or not actor.is_defeated_by(response): return
	if not is_instance_valid(health) or health.get_bound_actor() != actor or health.current_health > 0.0: return
	_on_defeat()

func _on_defeat() -> void:
	if state != "playing": return
	deaths += 1
	state = "dead"
	get_tree().paused = true

func _on_noise(origin: Vector2, kind: StringName, _loudness: float, source: Node) -> void:
	if not is_instance_valid(room) or not is_instance_valid(source) or not room.is_ancestor_of(source) and source != room: return
	var key := "step"
	match kind:
		&"weapon_tap": key="tap"
		&"enemy_windup": key="guard_draw"
		&"enemy_damage", &"enemy_death", &"parry", &"guard": key="hit"
		&"player_damage": key="hurt"
		&"attack", &"swing", &"enemy_attack": key="swing"
		&"prop_impact", &"prop_break", &"prop_launch", &"landing": key="prop"
		&"jump", &"air_jump": key="jump"
		&"roll": key="dash"
	audio.play_at(key,origin,-16 if key=="step" else -10,1.0)

func announce(text: String, seconds := 3.0) -> void:
	notice = text
	notice_left = seconds

func show_title() -> void:
	if is_instance_valid(room): _save_checkpoint()
	state = "title"
	get_tree().paused = true
	sonar.set_blind(false)
	continue_available = _valid_save()

func complete_run() -> void:
	state = "complete"
	get_tree().paused = true
	sonar.set_blind(false)
	audio.play_sound("win",-8,1)
	if save_enabled:
		var file = FileAccess.open("user://first_ascent_expanded_results.json",FileAccess.WRITE)
		if file: file.store_string(JSON.stringify({"seconds":elapsed,"deaths":deaths,"kills":kills,"caches":caches.size(),"blind":blind,"sectors":metrics},"\t"))

func _read_checkpoint() -> Dictionary:
	if not FileAccess.file_exists(SAVE):
		_checkpoint_error = ""
		return {"ok":false,"error":"No checkpoint exists."}
	var result := Checkpoint.decode(Checkpoint.parse(FileAccess.get_file_as_string(SAVE)),sectors)
	_checkpoint_error = "" if result.ok else str(result.error)
	return result

func _valid_save() -> bool:
	return _read_checkpoint().ok

func _save_checkpoint() -> void:
	if not save_enabled: return
	var encoded := Checkpoint.encode({"metrics":metrics,"sector":sector,"blind":blind,"caches":caches,"kills":kills,"deaths":deaths,"seconds":elapsed},sectors)
	if not encoded.ok:
		_checkpoint_write_error = encoded.error
		return
	# Preserve legacy/invalid originals before any explicit new-run replacement
	# or successful migration checkpoint. Never rewrite during validation.
	if FileAccess.file_exists(SAVE):
		var old = Checkpoint.parse(FileAccess.get_file_as_string(SAVE))
		if not old is Dictionary or old.get("version") != Checkpoint.VERSION or not Checkpoint.decode(old,sectors).ok:
			var original_hash := FileAccess.get_sha256(SAVE)
			var backup := SAVE+".preserved-"+original_hash+".json"
			if not FileAccess.file_exists(backup) and DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE),ProjectSettings.globalize_path(backup)) != OK:
				_checkpoint_write_error = "Could not preserve the previous checkpoint."
				return
			if FileAccess.get_sha256(backup) != original_hash or FileAccess.get_sha256(SAVE) != original_hash:
				_checkpoint_write_error = "Previous checkpoint preservation could not be verified."
				return
	var temporary := SAVE+".pending"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		_checkpoint_write_error = "Could not write a checkpoint."
		return
	file.store_string(JSON.stringify(encoded.data));file.flush()
	var write_error := file.get_error();file.close()
	if write_error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(SAVE)) != OK:
		_checkpoint_write_error = "Could not commit the checkpoint; previous progress is unchanged."
		return
	_checkpoint_write_error = ""
	_checkpoint_error = ""
	continue_available = true

func continue_run() -> void:
	var saved := _read_checkpoint()
	if not saved.ok:
		continue_available = false
		return
	blind = saved.blind
	caches.assign(saved.caches)
	kills = saved.kills
	deaths = saved.deaths
	elapsed = saved.seconds
	metrics.assign(saved.metrics)
	load_sector(saved.sector)

func _hud_snapshot() -> Dictionary:
	var data: Dictionary = {
		"state": state, "continue_available": continue_available,
		"authored_area_count": sectors.filter(func(area): return not area.get("ending",false)).size(),
		"ending_count": sectors.filter(func(area): return area.get("ending",false)).size(),
		"intro_time": intro_time, "player_present": is_instance_valid(player),
		"blind": blind, "elapsed": elapsed,
		"cache_count": caches.size(), "cache_total": _cache_total(),
		"archive_text": archive_text, "deaths": deaths, "kills": kills
	}
	if state == "title" and not _checkpoint_error.is_empty():
		data.merge({"panel_override":true,"panel_title":"CHECKPOINT UNAVAILABLE","panel_body":_checkpoint_error+"\n\nThe existing checkpoint has not been changed.\nStart a new mission to play; the original will be preserved.","panel_footer":"ENTER  New mission"})
		return data
	if state == "title" and not _checkpoint_write_error.is_empty():
		var retained := "The previous checkpoint remains available." if continue_available else "No new checkpoint was saved."
		data.merge({"panel_override":true,"panel_title":"CHECKPOINT NOT UPDATED","panel_body":_checkpoint_write_error+"\n\n"+retained,"panel_footer":"ENTER  New mission"+("     C  Continue previous checkpoint" if continue_available else "")})
		return data
	if not is_instance_valid(player): return data
	var d: Dictionary = sectors[sector]
	data.merge({"sector_title": d.title, "sector_text": d.text, "sector_hint": d.hint,
		"has_freight": d.has("freight"), "health_current": float(health.current_health),
		"health_capacity": float(health.capacity), "chapter_visible": chapter_left > 0,
		"notice_visible": notice_left > 0, "notice": notice})
	var objective := "Reach the onward door [E]"
	if d.has("freight") and not room.freight_receiver.is_latched: objective="Seat freight: J launch / E replace"
	elif not _relay_points().is_empty() and not relay_on: objective="Activate relays: %d / %d [E]" % [relay_states.size(),_relay_points().size()]
	elif d.get("lock",false) and remaining_enemies()>0: objective="Security seal: %d guards remain" % remaining_enemies()
	elif d.get("ending",false): objective="Enter the lift [E]"
	data["objective"] = objective
	var prompt := ""
	if state == "playing" and notice_left <= 0:
		if d.has("freight") and _near(d.freight.cradle,60): prompt="[E] Replace lost cargo · [J] strike from left" if not room.freight_receiver.is_latched else "FREIGHT SEATED · passage open"
		elif d.has("station") and _near(d.station) and not blind: prompt="[E] THE EXCHANGE · choose whether to trade sight"
		elif _relay_points().any(func(p): return _near(p)) and not relay_on: prompt="[E] Activate relay"
		elif d.has("cache") and _near(d.cache) and not caches.has(sector): prompt="[E] Field cache · restore health / collect archive"
		elif _near(Vector2(float(d.width)-45,float(d.get("gate_y",300))),65): prompt="[E] Continue" if room.gate_open else "DOOR SEALED · complete the objective"
	data["prompt"] = prompt
	return data
