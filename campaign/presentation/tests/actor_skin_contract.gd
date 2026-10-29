extends SceneTree
const Adapter = preload("res://campaign/presentation/actor_presentation.gd")
var failures: Array[String] = []
var checks := 0
func check(condition: bool, message: String) -> void:
	checks+=1
	if not condition:failures.append(message)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var mission = load("res://campaign/campaign.tscn").instantiate()
	mission.save_enabled=false;root.add_child(mission)
	await process_frame
	mission.start_new(true)
	await process_frame
	# Detach host paint for an isolated adapter test; no controllers are altered.
	for existing in mission.find_children("*","",true,false):
		if existing.get_script()==Adapter:existing.clear()
	# Instantiate independently so optional host binding cannot skew visibility.
	var adapter = Node.new();adapter.set_script(Adapter);mission.add_child(adapter)
	var visual: Node2D = mission.player.get_node("Visual")
	var original_script = visual.get_script()
	var original_id := visual.get_instance_id()
	var event_connections: int = mission.player.movement_event.get_connections().size()
	adapter.bind(mission.player,mission.enemies)
	check(visual.get_instance_id()==original_id and visual.get_script()==original_script,"approved original Visual unchanged")
	check(mission.player.movement_event.get_connections().size()==event_connections,"no second motor-event animation subscriber")
	check(not visual.visible and adapter.operative.visible,"filled view default, original still live")
	adapter.operative.source_visual=null
	for facing in [-1,1]:
		for mode in ["idle","run","jump","fall","roll_travel","ledge_hang","climb_ascend","wall_slide","attack_slash_active","attack_backhand_active","attack_finisher_active","shield_hold","hurt"]:
			for phase in [0.0,.25,.5,.75,1.0]:
				var pose: Dictionary = visual.evaluate_pose(mode,phase,{"facing":facing,"velocity":Vector2(facing*218,0),"gait_phase":phase,"grounded":true})
				var baseline := pose.duplicate(true)
				adapter.operative.set_pose(pose)
				check(adapter.operative.get_pose()==baseline,"snapshot unchanged "+mode)
				check(pose==baseline,"caller pose not mutated "+mode)
				check(adapter.operative._head_point(Vector2(0,-2)).is_finite(),"head transform finite "+mode)
				check(adapter.operative.get_pose().get("weapon",{})==baseline.get("weapon",{}),"weapon geometry preserved "+mode)
				check(adapter.operative.get_pose().get("shield",{})==baseline.get("shield",{}),"shield geometry preserved "+mode)
				await process_frame
	adapter.set_sight_enabled(false)
	check(not adapter.operative.visible,"full-color player concealed while blind")
	for skin in adapter.security:check(not skin.visible,"enemy fill concealed while blind")
	check(visual.get_instance_id()==original_id and visual.has_method("get_pose"),"proprioception pose source retained")
	adapter.set_sight_enabled(true);adapter.set_debug_wireframe(true)
	check(visual.visible and not adapter.operative.visible,"original debug wireframe selectable")
	adapter.set_debug_wireframe(false)
	check(not visual.visible and adapter.operative.visible,"color view reselectable")
	for skin in adapter.security:
		check(skin.show_behind_parent,"enemy fill below original attack telegraphs")
		var actor: Node2D = skin.actor
		for state in [&"patrol",&"windup",&"active"]:
			var sample: Dictionary=skin.geometry(float(actor.facing),actor.velocity,state,1000)
			var f:float=actor.facing
			var expected:=Vector2(f*10,-20)
			if state==&"windup":expected=Vector2(-f*9,-27)
			elif state==&"active":expected=Vector2(f*18,-22)
			check(sample.hand==expected,"enemy authoritative hand formula "+str(state))
	adapter.clear()
	check(visual.visible,"detaching restores original view")
	mission.queue_free();await process_frame
	if failures.is_empty():print("ACTOR_SKIN_CONTRACT_PASS: ",checks," pose/telegraph/visibility/lifecycle checks")
	else:for failure in failures:push_error(failure)
	quit(0 if failures.is_empty() else 1)
