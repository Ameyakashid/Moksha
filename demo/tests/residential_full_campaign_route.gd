extends "res://demo/tests/freight_journey_route.gd"
## Test-only composition: preserve Freight transport policy and generic policies,
## replacing navigation waypoints ONLY for the stable Residential chapter ID.
var residential_stage:=0
var residential_supported_count:=0
const RESIDENTIAL_POINTS:Array[Vector2]=[Vector2(840,300),Vector2(1130,190),Vector2(1230,190),Vector2(1480,300),Vector2(2040,300),Vector2(2310,135),Vector2(2420,135),Vector2(2940,300),Vector2(3290,300),Vector2(3670,120),Vector2(3760,120),Vector2(4140,300),Vector2(5050,-85)]
func _is_residential()->bool:
 return is_instance_valid(host) and host.sector>=0 and host.sector<host.sectors.size() and str(host.sectors[host.sector].get("id",""))=="upper_residential_crossing"
func begin_sector()->void:
 residential_stage=0
 super.begin_sector()
func navigate(target:Vector2,d:Dictionary)->Dictionary:
 if _is_residential() and residential_stage<RESIDENTIAL_POINTS.size():target=RESIDENTIAL_POINTS[residential_stage]
 return super.navigate(target,d)
func decide()->Dictionary:
 if _is_residential() and residential_stage<RESIDENTIAL_POINTS.size() and reached_supported_waypoint(RESIDENTIAL_POINTS[residential_stage],18):
  events.append({"event":"full_campaign_residential_supported_waypoint","index":residential_stage,"target":str(RESIDENTIAL_POINTS[residential_stage]),"position":str(host.player.position),"frame":frame})
  residential_stage+=1
  residential_supported_count=maxi(residential_supported_count,residential_stage)
 return super.decide()
func run()->void:
 source_hashes["res://demo/tests/residential_full_campaign_route.gd"]=FileAccess.get_sha256("res://demo/tests/residential_full_campaign_route.gd")
 await super.run()
 if full_campaign:
  if residential_supported_count<RESIDENTIAL_POINTS.size()-1:failures.append("Full campaign did not traverse required Residential service route")
  var base_path="res://demo/evidence/freight_journey_%s_%dhz_%s_full_campaign.json"%[approach,hz,"traded" if sacrifice else "retained"]
  var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base_path))
  report.merge({"residential_policy":"Stable-ID-scoped service-route supported waypoints; other area policies and actual Freight handling inherited unchanged","residential_supported_waypoints":residential_supported_count,"passed":failures.is_empty(),"failures":failures},true)
  var path="res://demo/evidence/residential_composed_%s_%dhz_%s_full_campaign.json"%[approach,hz,"traded" if sacrifice else "retained"]
  FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
  print("RESIDENTIAL COMPOSED CAMPAIGN ",path," failures=",failures)
 quit(0 if failures.is_empty() else 1)
