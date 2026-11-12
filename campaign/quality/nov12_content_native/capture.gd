extends SceneTree
class MissingCampaign:
	extends "res://campaign/logic/campaign.gd"
	func _load_catalog()->Dictionary:
		return preload("res://campaign/logic/campaign_data.gd").load_catalog(["res://campaign/layouts/not_installed.gd"])
func _initialize()->void:call_deferred("run")
func run()->void:
	for i in 4:await process_frame
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(640,360)
	var host:=MissingCampaign.new();root.add_child(host)
	for i in 8:await process_frame
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	var output:=OS.get_cmdline_user_args()[0]
	var error:=image.save_png(output)
	print("CONTENT_NATIVE ",JSON.stringify({"size":[image.get_width(),image.get_height()],"saved":error==OK,"processing":host.is_processing(),"physics":host.is_physics_processing(),"label":host.get_child(0).get_child(0).get_child(0).text}))
	quit(error)
