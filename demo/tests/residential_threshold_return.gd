extends "res://demo/tests/residential_crossing_route.gd"
## Real-input reverse traversal of all three retaining walls; no state positioning.
var reverse_support_distance:=[0.0,0.0,0.0]
var previous_position:=Vector2.ZERO
func begin_sector()->void:
 super.begin_sector()
 route_points=[Vector2(840,300),Vector2(1130,190),Vector2(1230,190),Vector2(1480,300),Vector2(1230,190),Vector2(1130,190),Vector2(840,300),Vector2(1130,190),Vector2(1230,190),Vector2(1480,300),Vector2(2040,300),Vector2(2310,135),Vector2(2420,135),Vector2(2940,300),Vector2(2420,135),Vector2(2310,135),Vector2(2040,300),Vector2(2310,135),Vector2(2420,135),Vector2(2940,300),Vector2(3290,300),Vector2(3670,120),Vector2(3760,120),Vector2(4140,300),Vector2(3760,120),Vector2(3670,120),Vector2(3290,300),Vector2(3670,120),Vector2(3760,120),Vector2(4140,300),Vector2(5050,-85)]
 previous_position=host.player.position
func decide()->Dictionary:
 var p=host.player
 if p.grounded and p._support is StaticBody2D and p._support.get_script()==preload("res://simulation/world/static_platform.gd"):
  for i in thresholds.size():
   if p._support.global_position.is_equal_approx(thresholds[i].get_center()) and p._support.platform_size==thresholds[i].size:
    reverse_support_distance[i]+=maxf(0,previous_position.x-p.position.x)
 previous_position=p.position
 return super.decide()
func run()->void:
 await super.run()
 for i in 3:
  if threshold_receipts[i].frames<hz/10:failures.append("No sustained actual support on threshold%d"%i)
  if reverse_support_distance[i]<60:failures.append("No sustained reverse supported traversal on threshold%d"%i)
 var source="res://demo/evidence/residential_%s_%s_%dhz.json"%[approach,"traded" if sacrifice else "retained",hz]
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source))
 report.merge({"suite":"residential actual right-floor return across all three thresholds","reverse_supported_distance":reverse_support_distance,"passed":failures.is_empty(),"failures":failures,"recovery_observer_sha256":FileAccess.get_sha256("res://demo/tests/residential_threshold_return.gd")},true)
 var path="res://demo/evidence/residential_threshold_return_%s_%dhz.json"%["traded" if sacrifice else "retained",hz]
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("RESIDENTIAL THRESHOLD RETURN ",path," failures=",failures)
 quit(0 if failures.is_empty() else 1)
