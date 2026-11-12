extends SceneTree
const Assembler = preload("res://demo/assembly/player_assembler.gd")
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
func _initialize() -> void:
	var actors: Array[Node] = []
	for i in 2:
		var player = preload("res://combat_pc/player.tscn").instantiate()
		Assembler.configure_actor(player)
		var health = preload("res://combat_pc/components/health_component.tscn").instantiate()
		Assembler.attach_components(player, health)
		check(not player.is_inside_tree() and not player.is_node_ready(), "detached actor")
		check(health.get_bound_actor() == null, "no premature health binding")
		var names: Array = []
		for child in player.get_children():
			names.append(str(child.name))
		check(names == ["BodyShape", "Visual", "ContactAdapter", "ShieldContactAdapter", "Health", "DefeatResponse", "NoiseRelay", "ContactConfig", "PhysicalImpactReceiver", "BoundaryReceiver", "ProjectileReceiver"], "exact child construction order")
		check(player.get_node("BodyShape/IncomingStrikeReceiver").counterable, "incoming parent/configuration")
		check(player.get_node("ProjectileReceiver").accepted_source_layers == 32, "projectile layers")
		check(health.maximum_health == 60, "initial maximum")
		actors.append(player)
	check(actors[0].profile != actors[1].profile, "movement profiles isolated")
	check(actors[0].combat_profile != actors[1].combat_profile, "combat profiles isolated")
	check(actors[0].melee_chain == actors[1].melee_chain, "initial shared chain")
	var speed: float = actors[1].profile.run_speed
	actors[0].profile.run_speed += 10
	check(actors[1].profile.run_speed == speed, "profile mutation isolated")
	for actor in actors:
		actor.free()
	print("DETACHED_PLAYER_RESULT " + JSON.stringify({"passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
