extends SceneTree
## Host-observable construction and activation contract; works before extraction.
class DemoTrace:
	extends "res://demo/mission.gd"
	var trace: Array = []
	func _create_player_health() -> Node:
		trace.append(["hook", player.name, player.is_inside_tree(), player.automatic_physics, player.profile.run_speed])
		player.child_entered_tree.connect(func(child): trace.append(["entered", str(child.name)]))
		player.ready.connect(func(): trace.append(["ready", player.get_node("Health").get_bound_actor() == player]))
		return super._create_player_health()
class CampaignTrace:
	extends "res://campaign/logic/campaign.gd"
	var trace: Array = []
	func _create_player_health() -> Node:
		trace.append(["hook", player.name, player.is_inside_tree(), player.automatic_physics, player.profile.run_speed])
		player.child_entered_tree.connect(func(child): trace.append(["entered", str(child.name)]))
		player.ready.connect(func(): trace.append(["ready", player.get_node("Health").get_bound_actor() == player]))
		return super._create_player_health()
var failures: Array[String] = []
var traces: Array = []
func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)
func topology(node: Node) -> Array:
	var rows: Array = []
	for child in node.get_children():
		rows.append([str(child.name), topology(child)])
	return rows
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for scene in [DemoTrace, CampaignTrace]:
		var first = scene.new()
		first.save_enabled = false
		root.add_child(first)
		first.start_new(true)
		var second = scene.new()
		second.save_enabled = false
		root.add_child(second)
		second.start_new(true)
		check(first.trace == second.trace, "same construction trace")
		check(first.trace[0][0] == "hook" and not first.trace[0][2] and not first.trace[0][3], "configured detached hook")
		check(first.trace.has(["ready", true]), "health bound before actor ready observer")
		check(first.player.profile != second.player.profile, "isolated movement profile")
		check(first.player.combat_profile != second.player.combat_profile, "isolated combat profile")
		check((first.player.melee_chain == second.player.melee_chain) == (scene == DemoTrace), "demo shared chain / campaign build copy")
		var speed: float = second.player.profile.run_speed
		first.player.profile.run_speed += 11
		check(second.player.profile.run_speed == speed, "movement mutation isolated")
		traces.append({"trace": first.trace, "topology": topology(first.player)})
		first.free()
		second.free()
		paused = false
	print("PLAYER_RECIPE_RESULT " + JSON.stringify({"passed": failures.is_empty(), "failures": failures, "traces": traces}))
	quit(0 if failures.is_empty() else 1)
