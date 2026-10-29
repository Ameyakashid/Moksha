extends "res://demo/tests/warden_order_route_bot.gd"
var survivor_fell:=false
var strike_started:=false
func _initialize():
 super._initialize()
 scene_path="res://demo/tests/warden_right_displaced_review.tscn"
 approach="displaced_right"
func run():
 source_hashes["res://demo/tests/warden_right_displaced_route_bot.gd"]=FileAccess.get_sha256("res://demo/tests/warden_right_displaced_route_bot.gd")
 await super.run()
 if not survivor_fell:failures.append("No living right sentry observed on lower real support after genuine strike")
 var original="res://demo/evidence/warden_order_displaced_right_%s_%dhz.json"%["traded" if sacrifice else "retained",hz]
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(original))
 report.merge({"survivor_fell":survivor_fell,"setup":"Explicit pre-clock original right sentry1245/245 at shelf edge; player starts normally. Health/stats unchanged. Measured displacement onto lower floor/cargo support uses real player strike; no impulses or position writes.","failures":failures,"passed":failures.is_empty()},true)
 var destination="res://demo/evidence/warden_right_displaced_%dhz.json"%hz
 FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("WARDEN RIGHT DISPLACED ",destination," failures=",failures)
 quit(0 if failures.is_empty() else 1)
func decide()->Dictionary:
 if str(host.sectors[host.sector].id)=="lift_warden" and not survivor_fell:
  var sentry=host.enemies[2]
  if sentry.health<2 and not sentry.dead:
   if sentry.grounded and sentry.position.y>260:
    survivor_fell=true
    events.append({"event":"actual_living_right_sentry_lower_support","position":str(sentry.position),"health":sentry.health,"frame":frame,"support_body":str(sentry._support.name) if is_instance_valid(sentry._support) else "none"})
   else:return {}
 return super.decide()
