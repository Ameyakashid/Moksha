extends "res://demo/mission.gd"
const CampaignIdentity=preload("res://demo/tests/campaign_identity.gd")
## Isolated arena fixture. Sight configuration occurs before active physics.
func _ready()->void:
 super._ready()
 save_enabled=false
 start_new(true)
 for arg in OS.get_cmdline_user_args():
  if arg=="--sacrifice":blind=true
 load_sector(CampaignIdentity.index(sectors,"lift_warden"))
