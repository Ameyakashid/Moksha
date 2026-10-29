extends SceneTree

var failures: Array[String] = []
var checked := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func run() -> void:
	var cases := [
		["res://scenes/levels/city_prologue.tscn", {
			"Crate01":"Street", "Barrel02":"Street", "Canister03":"Street",
			"Barrel04":"LoadingDeck", "Crate05":"LoadingDeck", "Canister06":"RelayDeck",
			"Crate07":"Street", "Barrel08":"Street", "Canister09":"Street",
			"Barrel10":"MaintenanceDeck", "Crate11":"MaintenanceDeck",
			"Barrel12":"CheckpointDeck", "Canister13":"CheckpointDeck",
			"Crate14":"Street", "Canister15":"EntryLanding",
		}],
		["res://scenes/levels/arcology_one.tscn", {
			"Crate01":"IntakeFloor", "Canister02":"IntakeFloor", "Barrel03":"Ascent01",
			"Crate04":"Ascent02", "Canister05":"Ascent02", "Canister06":"Ascent03",
			"Barrel07":"Ascent04", "Crate08":"Ascent05", "Crate09":"Ascent06",
			"Canister10":"Ascent07", "Barrel11":"Ascent08", "Crate12":"ExitLanding",
		}],
	]
	for test_case in cases:
		var level = load(test_case[0]).instantiate()
		root.add_child(level)
		level.get_node("Actors/Player").input_enabled = false
		check(level.get_node("Actors/Props").get_child_count() == test_case[1].size(),"Every placed prop must have an expected supporting surface")
		# Run the actual placed scenes with their normal physics and enemy patrols.
		# No prop is frozen or relocated by this test.
		for _frame in range(240):
			await physics_frame
			await process_frame
		for prop_name in test_case[1]:
			var prop = level.get_node_or_null("Actors/Props/"+prop_name)
			check(is_instance_valid(prop),"Placed prop disappeared while settling: "+prop_name)
			if not is_instance_valid(prop): continue
			var surface = level.get_node("Terrain/"+test_case[1][prop_name])
			var shape = prop.get_node("CollisionShape2D")
			var half: Vector2 = shape.shape.size*0.5
			var bottom := -INF
			for corner in [Vector2(-half.x,-half.y),Vector2(half.x,-half.y),Vector2(half.x,half.y),Vector2(-half.x,half.y)]:
				bottom = maxf(bottom,shape.to_global(corner).y)
			check(absf(bottom-surface.global_position.y)<3.0,"%s/%s fell from %s: bottom %.2f, expected %.2f" % [level.name,prop_name,surface.name,bottom,surface.global_position.y])
			check(prop.global_position.x>surface.global_position.x and prop.global_position.x<surface.global_position.x+surface.width,"Prop drifted off intended ledge: "+prop_name)
			checked += 1
			print("SETTLED ",level.name,"/",prop_name," on ",surface.name," bottom=",snappedf(bottom,0.01))
		level.free()
	print("PLACED PROP SETTLING: ",checked," checked after 2 seconds; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
