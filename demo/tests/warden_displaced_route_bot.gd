extends "res://demo/tests/warden_order_route_bot.gd"
var survivor_fell:=false
var strike_started:=false
func _initialize():
 super._initialize()
 scene_path="res://demo/tests/warden_displaced_review.tscn"
 approach="displaced"
func run():
 source_hashes["res://demo/tests/warden_displaced_route_bot.gd"]=FileAccess.get_sha256("res://demo/tests/warden_displaced_route_bot.gd")
 await super.run()
 if not survivor_fell:failures.append("No living sentry observed on floor after genuine strike")
 var original="res://demo/evidence/warden_order_displaced_%s_%dhz.json"%["traded" if sacrifice else "retained",hz]
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(original))
 report.merge({"survivor_fell":survivor_fell,"setup":"Explicit pre-clock PC780/190 and original sentry805/190 at shelf edge. Health/stats unchanged. Measured fall uses real player strike; no impulses or position writes.","failures":failures,"passed":failures.is_empty()},true)
 var destination="res://demo/evidence/warden_displaced_%dhz.json"%hz
 FileAccess.open(destination,FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
 print("WARDEN DISPLACED ",destination," failures=",failures)
 quit(0 if failures.is_empty() else 1)
func decide()->Dictionary:
 if str(host.sectors[host.sector].id)=="lift_warden" and not survivor_fell:
  var sentry=host.enemies[0]
  if sentry.health<2 and not sentry.dead:
   if sentry.grounded and sentry.position.y>290:
    survivor_fell=true
    events.append({"event":"actual_living_displaced_sentry_landed","position":str(sentry.position),"health":sentry.health,"frame":frame})
   else:return {}
  elif not strike_started:
   strike_started=true
   return {"attack":true}
 return super.decide()
