extends "res://campaign/tests/full_campaign_route.gd"
## Observer-only use of existing ladder for slower Strength approach.
func navigate(target:Vector2,d:Dictionary)->Dictionary:
 if str(d.id)=="l2_stamping_galleries" and not host.goal_done("die") and (host.player.position.y>110 or host.player.main_action==&"climb"):
  return {"target":Vector2(1340,100),"up":true,"jump":false,"drop":false}
 return super.navigate(target,d)
