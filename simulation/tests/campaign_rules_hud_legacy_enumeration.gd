extends SceneTree
## Actual legacy runner enumeration/setup/snapshot path, without rendering or pixel claims.
func _initialize():run.call_deferred()
func run():
 var runner=preload("res://simulation/tests/hud_pixels.gd").new()
 var areas=runner.legacy_areas();var cases=runner.fixture_cases();var failures:Array[String]=[];var labels:Array=[]
 if areas.size()!=8 or areas.map(func(area):return str(area.id))!=preload("res://demo/components/checkpoint_codec.gd").V3_IDS:failures.append("Legacy area mapping differs")
 for c in cases:
  var index=int(c.get("sector",0))
  if index<0 or index>=areas.size():failures.append("Out-of-bounds case: "+str(c.label));continue
  var oracle=preload("res://simulation/tests/hud_legacy_oracle.gd").new();var mission=preload("res://demo/mission.gd").new()
  if c.has("review"):
   oracle.free();mission.free();oracle=load("res://simulation/tests/hud_"+c.review+"_oracle.gd").new();mission=load("res://demo/tests/"+c.review+".gd").new()
  var garbage=runner.setup(oracle,c);garbage.append_array(runner.setup(mission,c))
  var hud=preload("res://simulation/ui/mission_hud.gd").new()
  if not hud.set_snapshot(mission._hud_snapshot()):failures.append("Rejected snapshot: "+str(c.label))
  labels.append(c.label);hud.free();oracle.free();mission.free()
  for node in garbage:node.free()
 var report={"cases":cases.size(),"labels":labels,"failures":failures,"passed":failures.is_empty(),"rendered":false,"scope":"Actual historical runner case enumeration, both fixture setups and candidate snapshot validation. No pixel readback or visual parity claim."}
 FileAccess.open("res://simulation/evidence/hud_legacy_enumeration.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"));print("HUD LEGACY ENUMERATION ",JSON.stringify(report));runner.free();quit(0 if failures.is_empty() else 1)
