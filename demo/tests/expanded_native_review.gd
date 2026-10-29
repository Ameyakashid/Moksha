extends "res://demo/mission.gd"
const CampaignIdentity=preload("res://demo/tests/campaign_identity.gd")
## Expanded-build native screenshots. Direct-state fixture positions, not a route.
func _ready()->void:
	super._ready()
	save_enabled=false
	capture_sequence.call_deferred()
func capture_sequence()->void:
	await get_tree().create_timer(0.8).timeout
	await capture_expanded("title")
	start_new(true)
	load_sector(CampaignIdentity.index(sectors,"lift_warden"))
	player.reset_actor(Vector2(895,300),1)
	chapter_left=0
	input_override={"shield":true}
	await get_tree().create_timer(1.2).timeout
	await capture_expanded("warden")
	load_sector(CampaignIdentity.index(sectors,"above_the_rain"))
	player.reset_actor(Vector2(655,300),1)
	input_override={}
	interact()
	await get_tree().create_timer(0.8).timeout
	await capture_expanded("ending")
	get_tree().quit()
func capture_expanded(label:String)->void:
	await RenderingServer.frame_post_draw
	print("EXPANDED NATIVE ",label," ",get_viewport().get_texture().get_image().save_png("res://demo/evidence/expanded_native_"+label+".png"))
