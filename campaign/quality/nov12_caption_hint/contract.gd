extends SceneTree
const Caption=preload("res://campaign/views/objective_caption.gd")
const HUD=preload("res://campaign/views/campaign_hud.gd")
const Paint=preload("res://campaign/views/objective_view.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var hud=HUD.new();root.add_child(hud)
 for width in [320,640]:
  for text in ["Coolant","Wrapped next objective guidance ".repeat(8)]:
   for controller in [false,true]:
    hud.set_snapshot({"guidance":text,"input_device":"controller" if controller else "keyboard","prompt":"[E] Install"})
    var safe=hud.caption_safe_rect().intersection(Rect2(0,0,width,360))
    for state in [[false,false],[false,true],[true,true]]:
     var desc=Caption.describe("install","Connect the closed coolant circuit",state[0],state[1],-1,1,false,controller)
     var lines=Caption._wrap(desc.title,10,width-24)
     var details=Caption._wrap(desc.detail,9,width-24)
     var w:=0.0
     for line in lines:w=maxf(w,ThemeDB.fallback_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x)
     for line in details:w=maxf(w,ThemeDB.fallback_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x)
     var size=Vector2(w+6,lines.size()*13+details.size()*12+4)
     for x in [20.0,width*.7,width-20.0]:
      var tx=Transform2D(0,Vector2(x,250))
      var icon=tx*Paint.painted_bounds("install")
      var base=Caption.place_block(Vector2(-60,-80),size,10,tx,Rect2(0,0,width,360),safe,icon)
      for invalid in [null,"bogus","right",5,{},[]]:
       check(Caption.place_block(Vector2(-60,-80),size,10,tx,Rect2(0,0,width,360),safe,icon,invalid)==base,"Invalid/missing hint preserves exact default")
      var hinted=Caption.place_block(Vector2(-60,-80),size,10,tx,Rect2(0,0,width,360),safe,icon,"left")
      check(not hinted.draw or (safe.grow(-8).encloses(hinted.screen_box) and not hinted.screen_box.intersects(icon.grow(4))),"Hint preserves HUD/icon safety for state/device/width")
      if base.draw:
       var expected=Rect2(Vector2(icon.position.x-4-size.x,base.screen_box.position.y),size)
       if safe.grow(-8).encloses(expected):check(hinted.screen_box==expected,"Fits: exact authored left placement")
       else:check(hinted==base,"Overflow: exact default fallback")
 var viewport=Rect2(0,0,640,360)
 var tx=Transform2D(0,Vector2(320,250))
 var icon=tx*Paint.painted_bounds("install")
 var default=Caption.place_block(Vector2(-60,-80),Vector2(163,27),10,tx,viewport,Rect2(0,57,640,282),icon)
 check(default.screen_box==Rect2(257,160,163,27),"Golden unchanged no-hint placement")
 var left=Caption.place_block(Vector2(-60,-80),Vector2(163,27),10,tx,viewport,Rect2(0,57,640,282),icon,"left")
 check(left.screen_box.end.x<=icon.position.x-4,"Left hint clears object and east ladder lane")
 check(not Caption.place_block(Vector2.ZERO,Vector2(100,30),10,Transform2D(0,Vector2(-50,150)),viewport,viewport,Rect2(-65,130,30,40),"left").draw,"Offscreen still culled")
 var parent=Node2D.new();root.add_child(parent);var child=Caption.new();parent.add_child(child);parent.hide()
 check(not child.is_visible_in_tree(),"Blind-hidden ownership unchanged")
 parent.free();hud.free();await process_frame
 print("CAPTION_HINT_CONTRACT ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
