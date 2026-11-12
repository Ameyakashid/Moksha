extends SceneTree
const Layout=preload("res://campaign/layouts/level_03.gd")
const Original=preload("res://demo/areas/upper_residential_crossing.gd")
const Codec=preload("res://demo/components/checkpoint_codec.gd")
const CampaignCodec=preload("res://campaign/logic/checkpoint_codec.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
func _initialize()->void:
 var areas=Layout.sectors()
 var h:Dictionary=areas[3]
 var original=Original.sector()
 check(h.id=="l3_homes","Stable district identity")
 for key in ["ladders","enemies","width","gate_y"]:check(h[key]==original[key],"Preserved "+key)
 check(h.platforms.slice(0,-1)==original.platforms,"Original platforms untouched")
 check(h.cache.distance_to(Vector2(2940,300))>45+52,"Nonoverlapping interaction disks")
 check(h.objectives[1].id=="shelter" and h.objectives[1].at==Vector2(2940,300) and h.objectives[1].requires==["list"] and not h.objectives[1].get("optional",false),"Shelter remains mandatory and stationary")
 check(h.objectives[2].requires==["shelter"] and h.objective_doors[0].requires==["roofs"],"Shelter still gates roof and exit")
 var previous=areas.duplicate(true)
 previous[3].cache=Vector2(2940,300)
 previous[3].platforms=original.platforms
 for blind in [false,true]:
  for collected in [false,true]:
   var state={"sector":3,"caches":[3] if collected else [],"metrics":[],"blind":blind,"kills":0,"deaths":0,"seconds":12.0}
   var before=Codec.encode(state,previous)
   var after=Codec.encode(state,areas)
   check(before==after,"Byte-equivalent save data for sight/cache combination")
   var raw={"campaign_version":1,"progress":before.data,"lens":"neutral","upgrades":[],"rewards":{},"level_seconds":{},"level_receipts":[]}
   var decoded=CampaignCodec.decode(raw,areas)
   check(decoded.ok and decoded.sector==3 and decoded.caches==state.caches and decoded.blind==blind,"Old checkpoint decoded with unchanged identity and archive semantics")
 print("RESIDENTIAL_CONTRACT ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
