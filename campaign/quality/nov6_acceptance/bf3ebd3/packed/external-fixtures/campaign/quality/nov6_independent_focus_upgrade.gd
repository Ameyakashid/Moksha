extends SceneTree
## Level-completion fixtures isolate an asynchronous navigation transaction.
## Required objectives/captain completion are initialized, not played through.
var host: Node
var checks := 0
var failures: Array[String] = []
var before_sector := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func key(code: int) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.pressed = true
	Input.parse_input_event(event); Input.flush_buffered_events()
	event = InputEventKey.new(); event.physical_keycode = code; event.pressed = false
	Input.parse_input_event(event); Input.flush_buffered_events()
func completed_level_fixture() -> void:
	for i in range(host.sectors.size() - 1):
		if host.sectors[i].level != host.sectors[i + 1].level:
			before_sector = i
			break
	host.load_sector(before_sector)
	for enemy in host.enemies: enemy.queue_free()
	for goal in host.goals: goal.completed = true
	host.relay_on = true
	await frames(3)
	host._update_gate()
	var district: Dictionary = host.sectors[before_sector]
	host.player.position = Vector2(float(district.width) - 45, float(district.get("gate_y", 300)))
	host.interact()
	check(host.state == "upgrade", "real authored exit enters upgrade from completed-level fixture")
	key(KEY_L)
	check(host._pending_sector == before_sector + 1 and host.upgrades == ["vitality"], "one selected upgrade queued with next level")
func run() -> void:
	host = load("res://campaign/campaign.tscn").instantiate(); host.save_enabled = false
	root.add_child(host); host.start_new(true); host.input_override = {}
	await completed_level_fixture()
	root.focus_exited.emit()
	key(KEY_R)
	key(KEY_ESCAPE)
	await frames(3)
	# Retrying the old level must either preserve the committed onward transition
	# or roll back its uncommitted upgrade; otherwise this exit can be farmed.
	check(host.sector == before_sector + 1 or host.upgrades.is_empty(), "focus retry cannot retain upgrade while returning to old level")
	check(host.sector == before_sector + 1 or (host.level_receipts.is_empty() and host.metrics.is_empty()), "focus retry rolls back uncommitted level receipt and district metric")
	var retry_observation := {"sector": host.sector, "old_level_exit": before_sector, "upgrades": host.upgrades.duplicate(), "receipts": host.level_receipts.duplicate()}
	host.start_new(true); await completed_level_fixture()
	root.focus_exited.emit()
	key(KEY_N)
	check(host.state == "title", "focus title command returns title")
	check(host.sector == before_sector + 1 or host.upgrades.is_empty(), "focus title checkpoint cannot retain upgrade at old level exit")
	check(host.sector == before_sector + 1 or (host.level_receipts.is_empty() and host.metrics.is_empty()), "focus title rolls back uncommitted level receipt and district metric")
	var title_observation := {"sector": host.sector, "upgrades": host.upgrades.duplicate(), "receipts": host.level_receipts.duplicate()}
	host.start_new(true); await completed_level_fixture()
	root.focus_exited.emit(); key(KEY_ESCAPE); await frames(3)
	check(host.sector == before_sector + 1 and host.upgrades == ["vitality"] and host.level_receipts.size() == 1 and host.metrics.size() == 1, "explicit resume commits exactly one upgrade receipt and metric on onward load")
	host.load_sector(host.sector)
	check(host.upgrades == ["vitality"] and host.level_receipts.size() == 1 and host.metrics.size() == 1, "retry after committed transition preserves earned upgrade and receipts")
	print("NOV6_INDEPENDENT_FOCUS_UPGRADE " + JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "retry_observation": retry_observation, "title_observation": title_observation, "scope": "Initialized authored level completion plus genuine keyboard exit/focus commands, not boss/goal playthrough."}))
	host.free(); quit(0 if failures.is_empty() else 1)
