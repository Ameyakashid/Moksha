extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for path in ["res://scenes/actors/player.tscn", "res://scenes/actors/enemy.tscn", "res://scenes/actors/elite_enemy.tscn", "res://scenes/props/crate.tscn", "res://scenes/props/barrel.tscn", "res://scenes/props/canister.tscn"]:
		var packed = load(path)
		if packed == null:
			push_error("Cannot load " + path)
			quit(1)
			return
		var actor = packed.instantiate()
		root.add_child(actor)
		actor.simulation_enabled = false
		print("LOADED ", path)
	await process_frame
	quit(0)
