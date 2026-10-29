extends SceneTree
## Scene contracts and editor-style save/reload of exported overrides.
var checks: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks.append({"pass": ok, "check": label})
	print("PASS " if ok else "FAIL ", label)

func disable_actors(level: Node) -> void:
	for actor in level.get_node("Actors").find_children("*", "", true, false):
		if actor is CharacterBody2D or actor is RigidBody2D:
			actor.simulation_enabled = false

func run() -> void:
	var paths := ["res://scenes/levels/city_prologue.tscn", "res://scenes/levels/arcology_one.tscn"]
	var level_files: Array[String] = []
	for filename in DirAccess.get_files_at("res://scenes/levels"):
		if filename.ends_with(".tscn"): level_files.append(filename)
	check(level_files.size() == 2, "playable level directory contains exactly two scenes")
	for path in paths:
		var packed: PackedScene = load(path)
		check(packed != null, "load reusable level " + path)
		var level: Node2D = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		disable_actors(level)
		root.add_child(level)
		await process_frame
		check(level.get_script().is_tool(), "level exports are available in editor " + level.name)
		check(level.has_node("Actors/Player") and level.has_node("Terrain") and level.has_node("GateAnchor"), "level owns placed player, terrain and exit " + level.name)
		check(level.get_node("Actors/Player").scene_file_path == "res://scenes/actors/player.tscn", "player remains a reusable scene instance " + level.name)
		var modular_actors := true
		for actor in level.get_node("Actors/Enemies").get_children():
			modular_actors = modular_actors and not actor.scene_file_path.is_empty() and actor.tuning != null
		for actor in level.get_node("Actors/Props").get_children():
			modular_actors = modular_actors and not actor.scene_file_path.is_empty() and actor.tuning != null and actor is RigidBody2D
		check(modular_actors, "enemy and physical prop scenes retain tuning resources " + level.name)
		var terrain_modular := true
		for platform in level.get_node("Terrain").get_children():
			terrain_modular = terrain_modular and not platform.scene_file_path.is_empty() and platform is StaticBody2D
		check(terrain_modular, "terrain uses reusable physical platform scenes " + level.name)
		var player: CharacterBody2D = level.get_node("Actors/Player")
		var original_tuning: Resource = player.tuning
		var original_speed: float = original_tuning.move_speed
		player.tuning = original_tuning.duplicate(true)
		player.tuning.move_speed = 333.0
		var platform: StaticBody2D = level.get_node("Terrain").get_child(0)
		var original_width: float = platform.width
		var original_one_way: bool = platform.one_way_collision
		platform.width = original_width + 37.0
		platform.one_way_collision = not original_one_way
		level.subtitle = "EDITOR ROUND TRIP"
		check(is_equal_approx(platform.get_node("CollisionShape2D").shape.size.x, original_width + 37), "platform width override updates collider " + level.name)
		check(platform.get_node("CollisionShape2D").one_way_collision == not original_one_way, "one-way override updates collider " + level.name)
		var edited := PackedScene.new()
		check(edited.pack(level) == OK, "edited instance packs " + level.name)
		var save_path := "user://flow_" + level.name + ".tscn"
		check(ResourceSaver.save(edited, save_path) == OK, "edited instance saves " + level.name)
		var reloaded: PackedScene = ResourceLoader.load(save_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
		var copy: Node2D = reloaded.instantiate()
		disable_actors(copy)
		root.add_child(copy)
		await process_frame
		check(copy.subtitle == "EDITOR ROUND TRIP", "level export survives editor-style save/reload " + level.name)
		check(is_equal_approx(copy.get_node("Terrain").get_child(0).width, original_width + 37), "platform override survives save/reload " + level.name)
		check(copy.get_node("Terrain").get_child(0).one_way_collision == not original_one_way, "one-way override survives save/reload " + level.name)
		check(is_equal_approx(copy.get_node("Actors/Player").tuning.move_speed, 333.0), "per-instance tuning survives save/reload " + level.name)
		check(is_equal_approx(original_tuning.move_speed, original_speed), "per-instance tuning does not mutate baseline " + level.name)
		var fresh: Node2D = packed.instantiate()
		check(is_equal_approx(fresh.get_node("Actors/Player").tuning.move_speed, original_speed) and is_equal_approx(fresh.get_node("Terrain").get_child(0).width, original_width), "fresh scene keeps default tuning and geometry " + level.name)
		fresh.free()
		copy.free()
		level.free()
		DirAccess.remove_absolute(save_path)
		await process_frame
	var failures := checks.filter(func(record): return not record.pass)
	var report := {"engine": Engine.get_version_info().string, "scope": "Headless instantiation plus editor-style PackedScene save/reload, not native editor UI", "checks": checks, "passed": checks.size() - failures.size(), "failed": failures.size()}
	var file := FileAccess.open("res://tests/flow_scene_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	print("SCENE RESULT ", checks.size() - failures.size(), "/", checks.size(), " passed")
	quit(1 if not failures.is_empty() else 0)
