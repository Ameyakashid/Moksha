extends SceneTree
class NativeCampaign:
	extends "res://campaign/logic/campaign.gd"
	func start_new(_skip_intro:=false)->void:super.start_new(true)
func _initialize()->void:call_deferred("run")
func run()->void:
	var host=NativeCampaign.new();host.save_enabled=false;root.add_child(host)
	host.sectors.assign([{"id":"native_health_qa","title":"NATIVE HEALTH ASSEMBLY QA","subtitle":"Controlled encounter, original actor/contact pipeline","text":"J attacks. Let the guard defeat you, then R retries. F10 ends recording.","hint":"Manual keyboard verification; synthetic encounter, not campaign level footage.","level":1,"level_name":"QA","width":1000,"theme":"interior","platforms":[],"enemies":[[108,"sentinel",300]],"props":[],"spawn":Vector2(75,300)}])
	var output:="user://native-health-qa"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var cleanup_only:=OS.get_cmdline_user_args().has("--cleanup-only")
	if cleanup_only:host.start_new(true)
	var previous:="";var actor_id:=0;var events:Array=[]
	for tick in (10 if cleanup_only else 5400):
		await process_frame
		if is_instance_valid(host.player) and host.player.get_instance_id()!=actor_id:
			actor_id=host.player.get_instance_id()
			for enemy in host.enemies:enemy.attack_damage_override=12.0
			print("NATIVE_ASSEMBLY_ACTOR ",actor_id," health=",host.health.get_script().resource_path)
		if host.state!=previous:
			previous=host.state
			var event:={"state":host.state,"deaths":host.deaths,"tick":tick}
			events.append(event);print("NATIVE_ASSEMBLY_STATE ",JSON.stringify(event))
			if not cleanup_only:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output+"/state-%d-%s.png"%[events.size(),host.state])
		if Input.is_physical_key_pressed(KEY_F10):break
	print("NATIVE_ASSEMBLY_DONE ",JSON.stringify(events))
	host.free();paused=false
	await process_frame
	quit()
