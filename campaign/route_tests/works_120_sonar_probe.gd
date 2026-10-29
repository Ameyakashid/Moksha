extends "res://campaign/route_tests/l23_route.gd"
## Isolated ordinary-input diagnostic. No production mutations.
func _initialize() -> void:
 district_id="works_three_crews"
 super._initialize()
func decide() -> Dictionary:
 var p=host.player
 # Finish an already admitted catch before graph steering can reverse away
 # from its lip. Up is an ordinary pull command through the complete phase.
 if district_id=="works_three_crews" and p.main_action==&"ledge" and absf(p._ledge_anchor.x-1080)<2 and absf(p._ledge_anchor.y-190)<2:
  if frame%hz==0:print("WORKS_LEDGE_UP ",p.position," phase=",p.action_phase)
  return {"up":1.0}
 return super.decide()
