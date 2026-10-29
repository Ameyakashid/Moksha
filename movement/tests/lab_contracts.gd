extends SceneTree
## Actual lab contract checks, including engine input dispatch and scene round-trip.
## Run: godot --headless --path . --fixed-fps 120 --script res://movement/tests/lab_contracts.gd
const LAB := preload("res://movement/movement_lab.tscn")
const PLAYER := preload("res://movement/actors/player.tscn")
const NPC := preload("res://movement/actors/npc.tscn")
const SURFACE := preload("res://movement/geometry/test_surface.tscn")
const ROUNDTRIP_PATH := "user://lab_contract_roundtrip.tscn"
var lab: Node2D
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	Engine.physics_ticks_per_second = 120
	_run.call_deferred()

func _check(ok: bool, label: String, detail: String = "") -> void:
	checks += 1
	if not ok:
		var message := label + (" | " + detail if not detail.is_empty() else "")
		failures.append(message)
		printerr("FAIL: " + message)

func _ticks(count: int = 1) -> void:
	for _index in count:
		await physics_frame
	await process_frame

func _key(code: Key, pressed: bool = true, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _tap(code: Key) -> void:
	_key(code)
	_key(code, false)

func _motors(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	if node is MokshaMovementMotor:
		found.append(node)
	for child in node.get_children():
		found.append_array(_motors(child))
	return found

func _new_lab() -> void:
	if is_instance_valid(lab):
		lab.free()
	lab = LAB.instantiate()
	root.add_child(lab)
	await _ticks(30)

func _run() -> void:
	await _new_lab()
	_test_scene_contract()
	await _test_serialization()
	await _new_lab()
	await _test_feature_toggles()
	await _test_pause_resume()
	await _test_reset_state()
	await _test_reset_pending_adapter_events()
	await _test_pause_pending_adapter_events()
	lab.free()
	if FileAccess.file_exists(ROUNDTRIP_PATH):
		DirAccess.remove_absolute(ROUNDTRIP_PATH)
	print("LAB CONTRACTS: %d checks, %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("  FAILED: " + failure)
	quit(0 if failures.is_empty() else 1)

func _test_scene_contract() -> void:
	var player: MokshaMovementMotor = lab.get_node("Player")
	var npc: MokshaMovementMotor = lab.get_node("NPC")
	_check(_motors(lab).size() == 2, "actual lab contains exactly two movement motors")
	_check(get_nodes_in_group("movement_players").size() == 1 and get_nodes_in_group("movement_npcs").size() == 1, "exactly one PC and one NPC belong to the intended actor groups")
	_check(player.scene_file_path == PLAYER.resource_path and npc.scene_file_path == NPC.resource_path, "PC and NPC are separate reusable prefab instances")
	_check(player.get_script() == npc.get_script(), "both prefabs use the same motor implementation")
	_check(player.tuning != npc.tuning and player.tuning.resource_path.ends_with("player.tres") and npc.tuning.resource_path.ends_with("npc.tres"), "prefabs use separate player and NPC tuning resources")
	_check(player.get_node("Intent").get_script() != npc.get_node("Intent").get_script(), "player and NPC use separate intent adapters")
	_check(player.get_node("Wireframe").get_script() == npc.get_node("Wireframe").get_script(), "both actors use the shared wireframe view")
	_check(player.is_on_floor() and npc.is_on_floor(), "both actors settle on actual lab geometry")
	var all_prefabs := true
	for surface in lab.get_node("Geometry").get_children():
		all_prefabs = all_prefabs and surface.scene_file_path == SURFACE.resource_path
	_check(all_prefabs, "all lab geometry remains editable surface prefab instances")
	print("CHECKED: real lab actor and prefab contract")

func _test_serialization() -> void:
	var player: MokshaMovementMotor = lab.get_node("Player")
	var npc: MokshaMovementMotor = lab.get_node("NPC")
	var original_player_tuning: Resource = player.tuning
	var original_player_speed: float = player.tuning.run_speed
	var original_npc_speed: float = npc.tuning.run_speed
	player.tuning = player.tuning.duplicate(true)
	player.tuning.resource_local_to_scene = true
	player.tuning.run_speed = original_player_speed + 37.0
	var runway: StaticBody2D = lab.get_node("Geometry/Runway")
	var edited_points := PackedVector2Array([Vector2(0, 0), Vector2(650, 0), Vector2(650, 75), Vector2(0, 75)])
	runway.points = edited_points
	runway.label = "roundtrip edit"
	runway.one_way = true
	_check(original_player_tuning.run_speed == original_player_speed and npc.tuning.run_speed == original_npc_speed, "local tuning edit leaves shared source and NPC unchanged")
	_check(runway.get_node("Collision").polygon == edited_points and runway.get_node("Collision").one_way_collision, "surface point/property edit immediately synchronizes collision")
	var packed := PackedScene.new()
	var pack_error := packed.pack(lab)
	_check(pack_error == OK, "modified lab can be packed", str(pack_error))
	if pack_error != OK:
		return
	var save_error := ResourceSaver.save(packed, ROUNDTRIP_PATH)
	_check(save_error == OK, "modified lab can be saved", str(save_error))
	if save_error != OK:
		return
	lab.free()
	lab = null
	var reloaded := ResourceLoader.load(ROUNDTRIP_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	_check(reloaded != null, "saved lab reloads as PackedScene")
	if reloaded == null:
		return
	lab = reloaded.instantiate()
	root.add_child(lab)
	await _ticks(3)
	player = lab.get_node("Player")
	npc = lab.get_node("NPC")
	runway = lab.get_node("Geometry/Runway")
	_check(player.tuning.run_speed == original_player_speed + 37.0 and player.tuning.resource_local_to_scene, "per-instance tuning edit survives save/reload")
	_check(npc.tuning.run_speed == original_npc_speed, "NPC tuning remains unchanged after round-trip")
	_check(runway.points == edited_points and runway.get_node("Collision").polygon == edited_points, "edited surface polygon and actual collider survive save/reload")
	_check(runway.label == "roundtrip edit" and runway.one_way and runway.get_node("Collision").one_way_collision, "surface labels and one-way collision survive save/reload")
	_check(player.scene_file_path == PLAYER.resource_path and npc.scene_file_path == NPC.resource_path and runway.scene_file_path == SURFACE.resource_path, "round-trip preserves prefab identity")
	var fresh_player: MokshaMovementMotor = PLAYER.instantiate()
	var fresh_surface: StaticBody2D = SURFACE.instantiate()
	_check(fresh_player.tuning.run_speed == original_player_speed, "fresh player prefab retains unmodified source tuning")
	_check(fresh_surface.points != edited_points and not fresh_surface.one_way, "fresh surface prefab retains its original polygon and flags")
	fresh_player.free()
	fresh_surface.free()
	print("CHECKED: tuning and surface serialization isolation")

func _test_feature_toggles() -> void:
	var owners: Array[Node] = [lab.player, lab.player, lab.player, lab.player, lab.player, lab.npc.get_node("Intent")]
	var properties := ["double_jump_enabled", "air_dash_enabled", "coyote_enabled", "variable_jump_enabled", "input_buffer_enabled", "chase_enabled"]
	var keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
	for index in keys.size():
		var original: bool = owners[index].get(properties[index])
		_tap(keys[index])
		_check(owners[index].get(properties[index]) != original, "parsed key toggles " + properties[index])
		_key(keys[index], true, true)
		_key(keys[index], false)
		_check(owners[index].get(properties[index]) != original, "keyboard repeat does not retrigger " + properties[index])
		_tap(keys[index])
		_check(owners[index].get(properties[index]) == original, "second key press restores " + properties[index])
	await _ticks(2)
	print("CHECKED: repeated feature toggles through parsed physical keys")

func _test_pause_resume() -> void:
	for iteration in 2:
		_tap(KEY_ESCAPE)
		_check(lab.paused and lab.player.process_mode == Node.PROCESS_MODE_DISABLED and lab.npc.process_mode == Node.PROCESS_MODE_DISABLED, "Escape pauses both actors, cycle %d" % iteration)
		var pc_at: Vector2 = lab.player.position
		var npc_at: Vector2 = lab.npc.position
		_tap(KEY_SPACE)
		_tap(KEY_K)
		await _ticks(24)
		_check(lab.player.position == pc_at and lab.npc.position == npc_at, "paused actors remain physically still, cycle %d" % iteration)
		_tap(KEY_ESCAPE)
		await _ticks(3)
		_check(not lab.paused and lab.player.process_mode == Node.PROCESS_MODE_PAUSABLE and lab.npc.process_mode == Node.PROCESS_MODE_PAUSABLE, "Escape resumes both actors, cycle %d" % iteration)
		_check(lab.player.is_on_floor() and lab.player.dash_left <= 0 and lab.player.jump_buffer <= 0 and lab.player.dash_buffer <= 0, "inputs made entirely during room pause are not replayed")
	print("CHECKED: pause/resume cycles through parsed keys")

func _test_reset_state() -> void:
	for iteration in 2:
		_tap(KEY_ESCAPE)
		for actor in [lab.player, lab.npc]:
			actor.position += Vector2(30, -20)
			actor.velocity = Vector2(150, -200)
			actor.set_intent(-1, true, true, true)
			actor.jump_count = 2
			actor.air_dash_count = 1
			actor.dash_left = 0.1
			actor.dash_cooldown = 0.3
			actor.pause_left = 0.2
			actor.stun_left = 0.2
			actor.coyote = 0.04
		_tap(KEY_R)
		_check(not lab.paused and lab.player.position == Vector2(120, 400) and lab.npc.position == Vector2(480, 400), "R resumes and returns both actors to scene starts")
		for actor in [lab.player, lab.npc]:
			_check(actor.velocity == Vector2.ZERO and actor.jump_buffer == 0 and actor.dash_buffer == 0 and not actor.jump_release_pending and actor.axis == 0, "R clears motor movement and input buffers: " + actor.name)
			_check(actor.jump_count == 0 and actor.air_dash_count == 0 and actor.dash_left == 0 and actor.dash_cooldown == 0 and actor.pause_left == 0 and actor.stun_left == 0 and actor.coyote == 0, "R clears action budgets, pause, stun, cooldown, and grace: " + actor.name)
		await _ticks(4)
		_check(lab.player.is_on_floor() and lab.player.dash_left <= 0, "reset stays grounded without unsolicited action")
	print("CHECKED: paused R reset state")

func _test_reset_pending_adapter_events() -> void:
	for code in [KEY_SPACE, KEY_K]:
		_tap(KEY_R)
		await _ticks(3)
		_tap(code)
		_tap(KEY_R)
		await _ticks(2)
		_check(lab.player.is_on_floor() and lab.player.position.distance_to(Vector2(120, 400)) < 0.2 and lab.player.dash_left <= 0 and lab.player.jump_count == 0, "R discards pre-reset same-frame adapter event: " + OS.get_keycode_string(code), "position=%s jump_count=%d dash_left=%.3f" % [lab.player.position, lab.player.jump_count, lab.player.dash_left])
	print("CHECKED: reset does not replay pending adapter events")

func _test_pause_pending_adapter_events() -> void:
	for code in [KEY_SPACE, KEY_K]:
		_tap(KEY_R)
		await _ticks(3)
		_tap(code)
		_tap(KEY_ESCAPE)
		await _ticks(5)
		_tap(KEY_ESCAPE)
		await _ticks(2)
		_check(lab.player.is_on_floor() and lab.player.position.distance_to(Vector2(120, 400)) < 0.2 and lab.player.dash_left <= 0 and lab.player.jump_count == 0, "room pause discards pending same-frame adapter event: " + OS.get_keycode_string(code), "position=%s jump_count=%d dash_left=%.3f" % [lab.player.position, lab.player.jump_count, lab.player.dash_left])
	print("CHECKED: room pause clears pending adapter events")
