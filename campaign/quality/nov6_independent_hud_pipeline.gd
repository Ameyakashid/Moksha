extends SceneTree
## Independent end-to-end HUD contract: exercise the real owner forwarding path,
## never send a host snapshot directly to its View. Fixtures are not playthroughs.
const FIELDS := ["district_index", "district_count", "level_index", "lens", "required_done", "required_total", "gate_open", "guidance", "input_device"]
var host: Node
var failures: Array[String] = []
var checks := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in count: await process_frame

func compare_pipeline(label: String) -> void:
	var expected: Dictionary = host._hud_snapshot()
	var owned: Dictionary = host.hud.get_snapshot()
	var shown: Dictionary = host.hud.get_node("View").data
	for key in FIELDS:
		check(expected.has(key), label + " host has " + key)
		check(owned.get(key) == expected.get(key), label + " owner forwards " + key)
		check(shown.get(key) == expected.get(key), label + " View receives " + key)
	check(host.hud.appearance != null and host.hud.get_node("View").appearance == host.hud.appearance, label + " appearance retained")

func rejected(candidate: Dictionary, label: String) -> void:
	var owned: Dictionary = host.hud.get_snapshot()
	var shown: Dictionary = host.hud.get_node("View").data.duplicate(true)
	check(not host.hud.set_snapshot(candidate), label + " rejected")
	check(host.hud.get_snapshot() == owned, label + " leaves owner unchanged")
	check(host.hud.get_node("View").data == shown, label + " leaves View unchanged")

func run() -> void:
	host = load("res://campaign/campaign.tscn").instantiate()
	host.save_enabled = false
	root.add_child(host)
	await frames(3)
	compare_pipeline("title boot")
	host.lens = "agility"
	await frames(2)
	compare_pipeline("title lens selection")
	host.start_new(true)
	host.input_override = {}
	for i in host.sectors.size():
		host.load_sector(i)
		await frames(2)
		compare_pipeline("district " + str(i))
		var expected: Dictionary = host._hud_snapshot()
		check(host.hud.set_snapshot(expected), "valid real snapshot accepted " + str(i))
		# Unknown fields are ignored, preserving the owner's existing allowlist policy.
		expected["untrusted_unused_field"] = {"bad": NAN}
		check(host.hud.set_snapshot(expected), "unknown extra accepted by ignoring " + str(i))
		check(not host.hud.get_snapshot().has("untrusted_unused_field") and not host.hud.get_node("View").data.has("untrusted_unused_field"), "unknown extra not forwarded " + str(i))
	var valid: Dictionary = host._hud_snapshot()
	for mutation in [
		{"health_capacity": 0}, {"health_current": NAN}, {"elapsed": INF},
		{"player_present": 1}, {"sector_title": null}, {"authored_area_count": -1},
		{"district_index": "1"}, {"district_count": []}, {"level_index": 1.0},
		{"lens": []}, {"required_done": true}, {"required_total": {}},
		{"gate_open": 0}, {"guidance": 14}, {"input_device": 1}, {"input_device": "unknown"}
	]:
		var candidate: Dictionary = valid.duplicate(true)
		candidate.merge(mutation, true)
		rejected(candidate, "malformed " + str(mutation.keys()[0]))
	# Both read and write boundaries own their copied data.
	var candidate: Dictionary = valid.duplicate(true)
	host.hud.set_snapshot(candidate)
	candidate.guidance = "MUTATED CALLER"
	check(host.hud.get_node("View").data.get("guidance") == valid.guidance, "caller mutation cannot alter View")
	var retrieved: Dictionary = host.hud.get_snapshot()
	retrieved.guidance = "MUTATED READER"
	check(host.hud.get_snapshot().get("guidance") == valid.guidance, "reader mutation cannot alter owner")
	check(host.hud.set_snapshot({}), "empty optional snapshot accepted")
	var empty: Dictionary = host.hud.get_snapshot()
	check(empty.get("guidance", "") != valid.guidance and empty.state == "title", "missing fields do not leak stale gameplay")
	# The unchanged demo owner's whitelist remains narrow outside campaign mode.
	var base = load("res://simulation/ui/mission_hud.gd").new()
	check(base.set_snapshot(valid), "base owner still accepts ordinary campaign superset")
	for key in FIELDS: check(not base.get_snapshot().has(key), "base owner does not adopt campaign-only " + key)
	base.free()
	print("NOV6_INDEPENDENT_HUD_PIPELINE " + JSON.stringify({"passed": failures.is_empty(), "checks": checks, "failures": failures, "scope": "Real host-to-owner-to-View path, all32 authored scenes, malformed input atomicity and isolated base owner. No direct-to-View bypass."}))
	host.free()
	quit(0 if failures.is_empty() else 1)
