extends "res://campaign/quality/nov6_full_campaign_route.gd"
func run()->void:
	input_dispatch=InputDispatch.new();input_dispatch.process_mode=Node.PROCESS_MODE_ALWAYS;root.add_child(input_dispatch)
	host=load(scene_path).instantiate();root.add_child(host);host.save_enabled=false
	await key(KEY_ENTER)
	var heard:Array=[]
	var supported_before:=false
	var airborne:=false
	var supported_after:=false
	for tick in range(60*12):
		if host.state=="playing":
			if tick>60*6 and tick<60*8:host.input_override={"right":1.0,"jump":tick%60==0}
			else:host.input_override={}
		if host.state=="playing":
			if tick<60*6 and host.player.grounded and is_instance_valid(host.player._support):supported_before=true
			if tick>60*6 and tick<60*8 and not host.player.grounded:airborne=true
			if tick>60*9 and host.player.grounded and is_instance_valid(host.player._support):supported_after=true
		for id in host.companion.director.seen:
			if not heard.has(id):heard.append(id);print("NATIVE_COMPANION_ACCEPTED ",id," frame=",Engine.get_frames_drawn())

		await physics_frame;await process_frame
	print("NATIVE_OPENING_RESULT ",JSON.stringify({"heard":heard,"deaths":host.deaths,"seconds":host.elapsed,"position":str(host.player.position),"method":"Normal title; ordinary automated inputs, deliberate quiet wait to exercise reminder, then movement/jump. Not full district completion."}))
	var passed:bool=supported_before and airborne and supported_after and host.deaths==0
	print("REAL_GROUNDING_RESULT ",JSON.stringify({"passed":passed,"supported_before":supported_before,"airborne_after_ordinary_jump":airborne,"supported_after_landing":supported_after}))
	host.free();input_dispatch.free();await process_frame;quit(0 if passed else 1)
