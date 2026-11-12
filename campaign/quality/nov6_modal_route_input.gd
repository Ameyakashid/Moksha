extends RefCounted
## Observer-only accommodation of the campaign's intentional modal input rearm.
## Release controls just as a player would before fresh movement after a menu.
## The normal route key dispatcher still owns E/choice/upgrade commands.
const MODALS := ["title","intro","archive","choice","hearing_choice","upgrade","journal","paused","dead"]

static func release_after_resume(host:Node,previous_state:String,events:Array[Dictionary],frame:int)->void:
	if previous_state not in MODALS or host.state not in ["playing","transition"]:return
	var previous_raw:Variant=host.input_override.duplicate() if host.input_override is Dictionary else null
	var before_tick:=Engine.get_physics_frames()
	host.input_override={}
	await host.get_tree().physics_frame
	await host.get_tree().process_frame
	events.append({"event":"observer_modal_controls_released","observer_revision":"nov6_modal_rearm_v1","frame":frame,
		"from_state":previous_state,"to_state":host.state,"superseded_raw_frame":previous_raw,
		"neutral_physics_frames":Engine.get_physics_frames()-before_tick,
		"position":str(host.player.position),"active_seconds":host.elapsed,
		"method":"Ordinary neutral raw input only; no actor/world/health/objective mutation."})
