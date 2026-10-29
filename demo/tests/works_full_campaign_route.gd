extends "res://demo/tests/residential_full_campaign_route.gd"
## Test-only composition retains Freight transport and Residential threshold policies.
var works_stage:=0
var works_supported_count:=0
var works_actual_order:Array=[]
const WORKS_POINTS:Array[Vector2]=[Vector2(1900,245),Vector2(1780,190),Vector2(1660,135),Vector2(1500,80),Vector2(1200,80),Vector2(950,80),Vector2(650,80),Vector2(450,300),Vector2(980,190),Vector2(1250,300),Vector2(1700,300),Vector2(2200,300),Vector2(2600,80),Vector2(2700,-140),Vector2(2890,-195),Vector2(2980,-250),Vector2(3150,-155),Vector2(3200,-430),Vector2(3440,-430),Vector2(3550,-240),Vector2(3920,-240),Vector2(4220,-240),Vector2(4520,-295),Vector2(4890,-240),Vector2(5250,-240),Vector2(5520,-240),Vector2(6200,300)]
func _is_works()->bool:
 return is_instance_valid(host) and host.sector>=0 and host.sector<host.sectors.size() and str(host.sectors[host.sector].get("id",""))=="relay_works"
func begin_sector()->void:
 works_stage=0
 super.begin_sector()
func navigate(target:Vector2,d:Dictionary)->Dictionary:
 if _is_works():
  if works_stage<WORKS_POINTS.size():target=WORKS_POINTS[works_stage]
  if host.player.main_action==&"climb" and target.y<host.player.position.y-5:
   return {"target":Vector2(host.player.position.x,target.y),"up":true,"jump":false,"drop":false}
 return super.navigate(target,d)
func decide()->Dictionary:
 if _is_works():
  works_actual_order=host.relay_states.duplicate()
  if works_stage<WORKS_POINTS.size() and reached_supported_waypoint(WORKS_POINTS[works_stage],18):
   events.append({"event":"full_campaign_works_supported_waypoint","index":works_stage,"target":str(WORKS_POINTS[works_stage]),"position":str(host.player.position),"frame":frame})
   works_stage+=1
   works_supported_count=maxi(works_supported_count,works_stage)
 return super.decide()
func run()->void:
 DirAccess.make_dir_recursive_absolute("res://demo/evidence")
 source_hashes["res://demo/tests/works_full_campaign_route.gd"]=FileAccess.get_sha256("res://demo/tests/works_full_campaign_route.gd")
 await super.run()
 if full_campaign:
  if works_supported_count<WORKS_POINTS.size()-1:failures.append("Full campaign did not traverse required Works branch route")
  if works_actual_order!=[0,1,2]:failures.append("Full campaign Works actual order mismatch")
  var source="res://demo/evidence/residential_composed_%s_%dhz_%s_full_campaign.json"%[approach,hz,"traded" if sacrifice else "retained"]
  var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source))
  report.merge({"works_policy":"Stable-ID-scoped fixed machine floors and real Lift-to-Dispatch crossing; Freight/Residential/other area policies inherited","works_supported_waypoints":works_supported_count,"works_actual_order":works_actual_order,"passed":failures.is_empty(),"failures":failures},true)
  var path="res://demo/evidence/works_composed_%s_%dhz_%s_full_campaign.json"%[approach,hz,"traded" if sacrifice else "retained"]
  FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
  print("WORKS COMPOSED CAMPAIGN ",path," failures=",failures)
 quit(0 if failures.is_empty() else 1)
