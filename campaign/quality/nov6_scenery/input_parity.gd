extends SceneTree
## Bounded real-physics fixtures: identical input with art attached and removed.
## Covers one start in each level, not a full campaign route or combat guarantee.
var checks := 0
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label); push_error(label)
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func trace(index: int, remove_scenery: bool) -> Array:
	seed(90632)
	var host = load("res://campaign/campaign.tscn").instantiate()
	host.save_enabled = false
	root.add_child(host)
	host.start_new(true); host.load_sector(index); host.input_override = {}
	if remove_scenery:
		host.art.free()
		host.art = null
	await frames(3)
	var samples: Array = []
	for tick in 120:
		host.input_override = {"right": 1.0, "jump": tick >= 10 and tick < 22, "attack": tick == 55, "shield": tick >= 70 and tick < 78, "roll": tick == 94}
		await frames(1)
		var p: Node = host.player
		samples.append([p.position, p.velocity, str(p.main_action), str(p.action_phase), str(p.weapon_phase), str(p.shield_phase), p.grounded, p.facing, host.health.current_health])
	host.queue_free(); await frames(2)
	return samples
func run() -> void:
	for index in [0, 7, 12, 19, 25]:
		var painted: Array = await trace(index, false)
		var stripped: Array = await trace(index, true)
		check(painted.size() == 120 and stripped.size() == 120, "120 real input steps per fixture")
		for tick in painted.size():
			var a: Array = painted[tick]
			var b: Array = stripped[tick]
			check(a[0].distance_to(b[0]) < .001 and a[1].distance_to(b[1]) < .001, "district %d tick %d same position/velocity with scenery removed" % [index, tick])
			check(a.slice(2) == b.slice(2), "district %d tick %d same movement/combat/health/facing state" % [index, tick])
	if failures.is_empty(): print("NOV6_SCENERY_INPUT_PARITY_PASS: ", checks, " checks; 5 starts x 120 real input ticks, attached vs removed scenery")
	else: print("NOV6_SCENERY_INPUT_PARITY_FAIL: ", failures.size(), " failures / ", checks)
	quit(0 if failures.is_empty() else 1)
