extends "res://campaign/tests/full_campaign_route.gd"
## Observer-only correction: finish an admitted west-facing catch using normal Up.
## Production/controller/health state is never changed by this policy.
func decide() -> Dictionary:
 var p=host.player
 if district_id=="works_three_crews" and p.main_action==&"ledge" and absf(p._ledge_anchor.x-1080)<2 and absf(p._ledge_anchor.y-190)<2:
  return {"up":1.0}
 return super.decide()
