extends SceneTree
## Presentation fixtures and bounded input parity, not campaign route/playtime proof.
const Scenery = preload("res://campaign/presentation/campaign_scenery.tscn")
const Identity = preload("res://campaign/presentation/district_identity.gd")
const Data = preload("res://campaign/logic/campaign_data.gd")
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)

func _initialize() -> void: run.call_deferred()

func physics_snapshot(node: Node, into: Dictionary) -> void:
	if node is CollisionObject2D:
		into[node.get_instance_id()] = [node.get_class(), node.global_transform, node.collision_layer, node.collision_mask]
	if node is CollisionShape2D:
		into[node.get_instance_id()] = [node.get_class(), node.transform, node.disabled, node.shape.get_instance_id() if node.shape != null else 0]
	for child in node.get_children(): physics_snapshot(child, into)

func reject_simulation_children(node: Node, label: String) -> void:
	check(not node is CollisionObject2D and not node is CollisionShape2D and not node is Timer and not node is CanvasLayer, label + " decoration only: " + node.name)
	for child in node.get_children(): reject_simulation_children(child, label)

func actor_snapshot(host: Node) -> Array:
	var p: Node = host.player
	return [p.position, p.velocity, p.facing, p.grounded, p.main_action, p.action_phase, p.weapon_phase, p.shield_phase, host.health.current_health, p.profile.run_speed, p.get_node("Visual").get_instance_id()]

func run() -> void:
	var sectors := Data.sectors()
	check(sectors.size() == 32, "all 32 authored districts")
	check(Identity.DISTRICTS.size() == sectors.size(), "presentation registry covers exactly campaign IDs")
	var fingerprints: Dictionary = {}
	var seeds: Dictionary = {}
	var first_bay_kinds: Dictionary = {}
	var city_crops: Dictionary = {}
	var scenery = Scenery.instantiate()
	root.add_child(scenery)
	for data in sectors:
		var label := str(data.id)
		var before := data.duplicate(true)
		scenery.configure(data)
		check(before == data, label + " does not mutate caller dictionary")
		check(scenery.get_child_count() == 2, label + " retains two removable paint children")
		var back: Node2D = scenery.backdrop
		var profile: Dictionary = back.identity
		check(profile.authored and profile.id == data.id, label + " explicit district identity")
		check(profile == Identity.profile_for(label, back.theme.motif), label + " deterministic profile")
		check(back.seed_value == Identity.seed_for(label), label + " stable seed")
		check(not seeds.has(profile.seed), label + " distinct seed")
		seeds[profile.seed] = true
		var signature := str([profile.bay_width, profile.skyline_phase, profile.skyline_y, profile.rib_offset, profile.bay_types])
		check(not fingerprints.has(signature), label + " unique decorative composition")
		fingerprints[signature] = true
		for row in 4:
			for column in 12:
				check(Identity.bay_kind(profile, column, row) == Identity.bay_kind(profile.duplicate(true), column, row), label + " stable bay choice")
		first_bay_kinds[Identity.bay_kind(profile, 0, 0)] = true
		var tiles: Array = back.skyline_tiles()
		check(not tiles.is_empty(), label + " skyline has valid tiles")
		if back.theme.motif in ["city", "crown"]:
			var crop_key := str(tiles[0].source)
			check(not city_crops.has(crop_key), label + " skyline opens on a different actual source crop")
			city_crops[crop_key] = true
		var cursor := 0.0
		for tile in tiles:
			var source: Rect2 = tile.source
			var target: Rect2 = tile.destination
			check(source.position.x >= -.001 and source.position.y >= 0 and source.end.x <= back.skyline.get_width() + .001 and source.end.y <= back.skyline.get_height() + .001, label + " crop stays inside original art")
			check(source.size.x > 0 and source.size.y > 0 and target.size.x > 0, label + " nonempty crop")
			check(is_equal_approx(target.size.x / source.size.x, target.size.y / source.size.y), label + " preserves original art aspect ratio")
			check(absf(target.position.x - cursor) < .01, label + " seamless world coverage")
			cursor = target.end.x
		check(absf(cursor - float(data.width)) < .01, label + " covers room width exactly")
		check(back.landmark_origin.y + 116 < 250, label + " first wall landmark clear of floor-standing actor")
		reject_simulation_children(scenery, label)
		var borrowed := profile.duplicate(true)
		borrowed.bay_types[0] = "changed"
		check(Identity.profile_for(label, back.theme.motif).bay_types[0] != "changed", label + " caller cannot change shared registry")
		scenery.set_sight_enabled(false)
		check(not scenery.visible and not back.is_visible_in_tree() and not scenery.terrain_paint.is_visible_in_tree(), label + " all decorative paint disappears when blind")
		scenery.configure(data)
		check(not scenery.visible and not scenery.backdrop.is_visible_in_tree(), label + " blind reconfiguration cannot leak identity")
		scenery.set_sight_enabled(true)
		scenery.backdrop.queue_redraw()
		await process_frame
	check(first_bay_kinds.size() >= 10, "purpose-specific equipment rather than three repeated placements")
	seed(8361)
	var expected_random := randi()
	seed(8361)
	for data in sectors: scenery.configure(data)
	check(randi() == expected_random, "decorating all 32 districts consumes no global simulation randomness")
	scenery.queue_free(); await process_frame
	var host = load("res://campaign/campaign.tscn").instantiate()
	host.save_enabled = false
	root.add_child(host)
	host.start_new(true); host.input_override = {}
	await process_frame
	for index in sectors.size():
		host.load_sector(index)
		var before: Dictionary = {}
		physics_snapshot(host, before)
		var actor_before := actor_snapshot(host)
		var goals_before: Dictionary = host.completed_goals.duplicate(true)
		host.art.set_sight_enabled(false)
		host.art.configure(sectors[index])
		host.art.set_sight_enabled(true)
		host.art.update_view(Vector2(1800, -200), Vector2(640, 360))
		var art: Node = host.art
		var parent: Node = art.get_parent()
		parent.remove_child(art)
		var after: Dictionary = {}
		physics_snapshot(host, after)
		check(before == after, str(sectors[index].id) + " configure/hide/remove preserves every collider, shape, transform, layer and mask")
		check(actor_before == actor_snapshot(host), str(sectors[index].id) + " no actor or source-pose mutation")
		check(goals_before == host.completed_goals, str(sectors[index].id) + " no objective mutation")
		parent.add_child(art)
		await process_frame
	host.queue_free(); await process_frame; await process_frame
	if failures.is_empty():
		print("NOV6_SCENERY_CONTRACT_PASS: ", checks, " checks; 32 authored identities, source crop/aspect/coverage, stable seeds, RNG isolation, all colliders/actors unchanged, blind rebuilds")
	else:
		print("NOV6_SCENERY_CONTRACT_FAIL: ", failures.size(), " failures / ", checks)
	quit(0 if failures.is_empty() else 1)
