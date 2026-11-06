extends "res://campaign/quality/nov6_full_campaign_route.gd"
## Small integration fixture for the observer wrapper's real key dispatcher.
## Menu/scene setup is explicit; release and new movement use ordinary inputs.
var checks:=0
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second=hz
	run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:int)->void:
	for index in count:await physics_frame;await process_frame
func run()->void:
	input_dispatch=InputDispatch.new();input_dispatch.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(input_dispatch)
	host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true)
	host.input_override={"right":1.0};await frames(3)
	await key(KEY_TAB)
	check(host.state=="journal" and host._input_gate._blocked.has("right"),"opening journal retains production held-control boundary")
	await key(KEY_ESCAPE)
	check(host.state=="playing" and host.input_override.is_empty() and host._input_gate._blocked.is_empty(),"wrapper dispatch closes menu and physically observes neutral input")
	host.input_override={"right":1.0};await frames(2)
	check(host.player._input.x==1 and host.player.velocity.x>0,"fresh ordinary movement resumes after wrapper release")
	var before:int=events.size()
	await key(KEY_Q)
	check(events.size()==before and host.input_override.get("right")==1.0,"ordinary playing command does not inject neutral or change route timing")
	host.state="choice";paused=true
	await key(KEY_K)
	check(not host.blind and host.input_override.is_empty(),"retained sight choice uses existing command plus neutral release")
	host.state="upgrade";paused=true
	await key(KEY_J)
	check(host.sector==1 and host.upgrades==["force"] and host.input_override.is_empty(),"upgrade transition remains genuine and completes during neutral frame")
	var release_events:Array=events.filter(func(event):return event.get("event")=="observer_modal_controls_released")
	check(release_events.size()==3 and release_events.all(func(event):return event.neutral_physics_frames>=1),"each actual modal return records observed neutral physics evidence")
	print("NOV6_MODAL_ROUTE_OBSERVER_RESULT "+JSON.stringify({"checks":checks,"passed":failures.is_empty(),"failures":failures,"release_events":release_events,"scope":"Explicit menu/scene fixtures for inherited route dispatcher; not full route evidence."}))
	host.free();quit(0 if failures.is_empty() else 1)
