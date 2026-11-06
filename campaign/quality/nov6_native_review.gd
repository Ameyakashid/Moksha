extends Node
## Native QA fixtures only. Direct district/position setup is NOT route proof.
## The production scenes, physics, HUD and renderer remain unchanged.
var host:Node
var capture_all:=false
var capture_ui:=false
var output_path:="user://nov6_native_review"
func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_title("MOKSHA / NATIVE QA FIXTURE (not route proof)")
	host=load("res://campaign/campaign.tscn").instantiate()
	host.save_enabled=false
	add_child(host)
	for arg in OS.get_cmdline_user_args():
		if arg=="--capture-all":capture_all=true
		elif arg=="--capture-ui":capture_ui=true
		elif arg.begins_with("--output="):output_path=arg.trim_prefix("--output=")
	if capture_ui:run_ui_capture.call_deferred()
	elif capture_all:run_capture.call_deferred()
	else:setup.call_deferred()
func setup()->void:
	var index:=0
	var at:Variant=null
	var mode:="playing"
	var notice_text:=""
	var trade:=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--district="):index=int(arg.trim_prefix("--district="))
		elif arg.begins_with("--point="):
			var parts:=arg.trim_prefix("--point=").split(",")
			at=Vector2(float(parts[0]),float(parts[1]))
		elif arg.begins_with("--state="):mode=arg.trim_prefix("--state=")
		elif arg.begins_with("--notice="):notice_text=arg.trim_prefix("--notice=")
		elif arg=="--blind":trade=true
	host.start_new(true);host.load_sector(index)
	if at is Vector2:
		host.player.position=at;host.camera.position=host.camera_follow.reset(at,host.sectors[index])
	if trade:
		host.state="choice";host.choose_sight(true)
	host.state=mode;host.chapter_left=0
	if not notice_text.is_empty():host.announce(notice_text,60)
	get_tree().paused=mode!="playing"
	print("NOV6_NATIVE_FIXTURE ",JSON.stringify({"district":host.sectors[index].id,"position":host.player.position,"state":mode,"blind":trade}))
func _input(event:InputEvent)->void:
	if not event is InputEventKey or not event.pressed or event.echo:return
	var key:int=event.physical_keycode if event.physical_keycode!=0 else event.keycode
	if key==KEY_F12:
		get_viewport().set_input_as_handled()
		capture.call_deferred("manual-%d"%Time.get_ticks_msec())
	elif key==KEY_PAGEUP or key==KEY_PAGEDOWN:
		get_viewport().set_input_as_handled()
		host.load_sector(posmod(host.sector+(1 if key==KEY_PAGEDOWN else -1),host.sectors.size()))
func capture(label:String)->void:
	if DisplayServer.get_name()=="headless":push_error("Native renderer required for actual image capture.");return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_path))
	var file:=output_path+"/"+label+".png"
	var err:=get_viewport().get_texture().get_image().save_png(file)
	print("NATIVE_CAPTURE ",JSON.stringify({"file":file,"error":err,"district":host.sectors[host.sector].id,"state":host.state,"position":host.player.position,"camera":host.camera.position,"fixture":true}))
func run_capture()->void:
	host.start_new(true)
	for index in host.sectors.size():
		host.load_sector(index);host.input_override={}
		for frame in 4:await get_tree().physics_frame
		host.chapter_left=0
		await capture("%02d-%s-start"%[index+1,host.sectors[index].id])
		var goals:Array=host.sectors[index].get("objectives",[])
		if not goals.is_empty():
			var spec:Dictionary=goals[goals.size()-1]
			host.player.position=spec.at-Vector2(40,0)
			host.player.velocity=Vector2.ZERO
			host.camera.position=host.camera_follow.reset(host.player.position,host.sectors[index])
			for frame in 4:await get_tree().physics_frame
			await capture("%02d-%s-objective"%[index+1,host.sectors[index].id])
	print("NOV6_NATIVE_CAPTURE_COMPLETE")
	await finish_capture()
func run_ui_capture()->void:
	# Deliberate UI setup, never a progression, save or controller-hardware test.
	host.start_new(true);host.input_override={}
	for device in ["keyboard","controller"]:
		host.gamepad_navigation.input_device=device
		for mode in ["title","paused","journal","choice","upgrade","final_choice","dead","complete"]:
			host.state=mode;host.chapter_left=0;host.campaign_ending="public_record"
			get_tree().paused=true
			for frame in 3:await get_tree().process_frame
			await capture("ui-%s-%s"%[device,mode])
	host.gamepad_navigation.input_device="keyboard"
	host.state="title";host._checkpoint_error="The campaign checkpoint contains incomplete or invalid progress."
	for frame in 3:await get_tree().process_frame
	await capture("ui-checkpoint-invalid")
	host._checkpoint_error="";host._checkpoint_write_error="The campaign checkpoint could not be committed.";host.continue_available=true
	for frame in 3:await get_tree().process_frame
	await capture("ui-checkpoint-write-failure")
	host._checkpoint_write_error=""
	for index in [0,6,12,18,25]:
		host.start_new(true);host.load_sector(index);host.chapter_left=0;host.input_override={}
		host.state="choice";host.choose_sight(true)
		for frame in 60:await get_tree().physics_frame
		await capture("blind-%02d-dark"%[index+1])
		var tap:=InputEventKey.new();tap.pressed=true;tap.physical_keycode=KEY_Q
		host._unhandled_key_input(tap)
		for frame in 20:await get_tree().physics_frame
		await capture("blind-%02d-sonar"%[index+1])
	print("NOV6_NATIVE_UI_CAPTURE_COMPLETE")
	await finish_capture()
func finish_capture()->void:
	# Let active audio/render callbacks retire before engine shutdown. This is
	# fixture teardown, not a change to preserved runtime audio or scene rules.
	host.queue_free()
	get_tree().paused=false
	for frame in 3:await get_tree().process_frame
	get_tree().quit()
