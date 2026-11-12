extends SceneTree
## Font-bound geometry check, not a substitute for native visual review.
const Layout=preload("res://campaign/layouts/level_03.gd")
const Appearance=preload("res://demo/views/sign_appearance.gd")
var failures:Array[String]=[]
var checks:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures.append(message)
func _initialize()->void:call_deferred("run")
func run()->void:
 var style=Appearance.new()
 var face:Font=style.font if style.font!=null else ThemeDB.fallback_font
 var words:="ROOFS ^   SUPPLIES >"
 var size:=face.get_string_size(words,style.alignment,style.width,style.font_size)
 var extent:=Vector2(size.x,face.get_height(style.font_size))
 var offset:=Vector2(0,face.get_ascent(style.font_size))
 var matches:Array=[]
 for area in Layout.sectors():
  if area.id=="l3_homes":
   for sign_data in area.signs:
    if sign_data[1]==words:matches.append(sign_data[0])
 check(matches.size()==1,"Exactly one direction label")
 var p:Vector2=matches[0] if matches.size()==1 else Vector2.ZERO
 var wall:=Rect2(2580,245,80,55)
 var ladder:=Rect2(2722,25,16,275)
 var bounds:=Rect2(p-offset,extent)
 check(p==Vector2(2625,230),"Reviewed direction label placement")
 check(not bounds.intersects(wall),"Direction text clears retaining wall")
 check(not bounds.intersects(ladder),"Direction text clears ladder")
 check(Rect2(Vector2(2680,265)-offset,extent).intersects(ladder),"Original ladder-overlap negative control")
 check(Rect2(Vector2(2590,265)-offset,extent).intersects(wall),"Rejected wall-overlap negative control")
 print("RESIDENTIAL_LABEL_CLEARANCE ",checks," checks; bounds=",bounds," failures=",failures)
 quit(0 if failures.is_empty() else 1)
