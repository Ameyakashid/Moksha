extends SceneTree
var failures: Array[String] = []
func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var mission = load("res://campaign/campaign.tscn").instantiate()
	mission.save_enabled = false
	root.add_child(mission)
	await process_frame
	mission.start_new(true)
	await process_frame
	check(is_instance_valid(mission.art),"runtime attaches art")
	check(mission.art.visible,"sighted runtime art visible")
	check(mission.art.z_index == -5,"art behind actors and above old terrain")
	check(not mission.room.backdrop.visible,"old wireframe backdrop disabled")
	mission.state = "choice"
	mission.choose_sight(true)
	check(mission.blind and mission.sonar.blind,"real sight trade enables sonar")
	check(not mission.art.visible,"sight trade hides art immediately")
	check(not mission.art.backdrop.is_visible_in_tree(),"no skyline leak")
	check(not mission.art.terrain_paint.is_visible_in_tree(),"no terrain skin leak")
	mission.load_sector(0)
	await process_frame
	check(not mission.art.visible and mission.sonar.blind,"blind retry rebuild keeps concealment")
	check(not mission.art.backdrop.is_visible_in_tree() and not mission.art.terrain_paint.is_visible_in_tree(),"rebuilt child paint concealed")
	mission.start_new(true)
	await process_frame
	check(mission.art.visible and not mission.blind,"new run restores sight")
	mission.queue_free()
	await process_frame
	if failures.is_empty():print("RUNTIME_SIGHT_CONTRACT_PASS: sighted, sacrifice, immediate tree hide, retry, new run")
	else:for failure in failures:push_error(failure)
	quit(0 if failures.is_empty() else 1)
