extends "res://demo/tests/expanded_mission_route_bot.gd"
## Generic route-input recovery regression, independent of mission/freight identity.
const Actor = preload("res://simulation/actors/shared_actor.tscn")
class ProbeHost extends Node2D:
	var player: Node2D
	var sector := 0
class Raw extends Node:
	var raw := {}
	func sample_raw(_actor: Node, _dt: float) -> Dictionary: return raw.duplicate(true)
	func reset_intent() -> void: raw.clear()
var checks := 0
var records: Array=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz=int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second=hz
	run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL ",label)
func step(source: Node, raw: Dictionary) -> void:
	source.raw=raw
	await physics_frame;await process_frame
	var pos: Vector2=host.player.position
	if absf(pos.x-last_x)<0.3: stagnant+=1.0/hz
	else: stagnant=0
	last_x=pos.x
func run() -> void:
	for downward in [true,false]:
		for repeat in range(2):
			host=ProbeHost.new();root.add_child(host)
			var room=load("res://demo/components/mission_room.gd").new();host.add_child(room)
			room.build({"theme":"interior","width":2000,"platforms":[]})
			var obstacle=preload("res://simulation/world/static_platform.tscn").instantiate()
			obstacle.position=Vector2(1447.381,256.1996);obstacle.platform_size=Vector2(28,28);obstacle.rotation=0.00206;host.add_child(obstacle)
			var actor=Actor.instantiate();actor.position=Vector2(1478,250)
			var source:=Raw.new();source.name="InputSource";actor.add_child(source);host.add_child(actor);host.player=actor
			last_x=actor.position.x;stagnant=0
			var target:=Vector2(1466,270 if downward else 230)
			check(ledge_waypoint_recovery(target).is_empty(),"moving/nonledge actor receives no recovery")
			var caught:=false
			for i in range(hz):
				await step(source,{"left":1.0} if actor.main_action!=&"ledge" else {})
				if actor.action_phase==&"hang":caught=true;break
			check(caught and not actor.grounded,"ordinary input/gravity catches actual edge")
			check(ledge_waypoint_recovery(target).is_empty(),"new hang does not trigger before stagnation threshold")
			for i in range(ceili(hz*0.6)):await step(source,{})
			check(actor.main_action==&"ledge" and actor.action_phase==&"hang" and not actor.grounded,"unchanged empty steering reproduces dead zone")
			check(project_supported_waypoint(target)==target,"grounded support projection cannot bypass actual airborne hang")
			check(ledge_waypoint_recovery(target+Vector2(30,0)).is_empty(),"waypoint outside horizontal dead zone does not trigger")
			var recovery:=ledge_waypoint_recovery(target)
			check(recovery==({"down":1.0} if downward else {"up":1.0}),"observed lower/upper target selects ordinary release/pull")
			var start: Vector2=actor.position
			await step(source,recovery)
			for i in range(hz):await step(source,ledge_waypoint_recovery(target))
			check(actor.grounded and actor.main_action!=&"ledge","ordinary recovery reaches real supported state")
			check(actor.position.y>start.y+10 if downward else actor.position.y<start.y-5,"release falls or pull climbs through actual controller")
			check(ledge_waypoint_recovery(target).is_empty(),"grounded actor receives no recovery")
			records.append({"downward":downward,"repeat":repeat,"start":str(start),"end":str(actor.position),"grounded":actor.grounded,"raw_recovery":recovery})
			host.queue_free();await physics_frame;await process_frame
	var report={"hz":hz,"checks":checks,"failures":failures,"records":records,"scope":"Initial authored obstacle/actor placement, ordinary raw-input/gravity ledge catch, unchanged waypoint completion, generic input-only recovery. No action, support, position or velocity outcomes assigned."}
	FileAccess.open("res://simulation/evidence/floor_segment_route_%dhz.json"%hz,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("FLOOR ROUTE RECOVERY ",checks," checks, ",failures.size()," failures");quit(0 if failures.is_empty() else 1)
