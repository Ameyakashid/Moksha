extends SceneTree
const Caption=preload("res://campaign/views/objective_caption.gd")
const HUD=preload("res://campaign/views/campaign_hud.gd")
var checks:=0
var failures:Array=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var view=HUD.new();root.add_child(view)
 for width in [320,640]:
  for guidance in ["Select coolant feed: position 1 [E]","Very long guidance ".repeat(15)]:
   for controller in [false,true]:
    view.set_snapshot({"guidance":guidance,"input_device":"controller" if controller else "keyboard","prompt":"[E] Recover foundry service harness"})
    var layout=view.playing_layout(view.data)
    var safe=view.caption_safe_rect().intersection(Rect2(0,0,width,360))
    check(is_equal_approx(safe.position.y,layout.header_height),"Safe boundary matches actual wrapped header")
    check(safe.end.y<=layout.context_top+.01,"Safe boundary excludes bottom prompt")
    for state in [[false,false],[false,true],[true,true]]:
     var description=Caption.describe("recover","Recover foundry service harness",state[0],state[1],-1,1,true,controller)
     var lines=Caption._wrap(description.title,10,width-24)
     var details=Caption._wrap(description.detail,9,width-24)
     var size=Vector2(width-24,lines.size()*13+details.size()*12+4)
     for y in [12,80,180,350]:
      var transform=Transform2D(0,Vector2(width/2.0,y))
      var result=Caption.place_block(Vector2(-60,-80),size,10,transform,Rect2(0,0,width,360),safe)
      check(result.draw,"Visible caption with room retained")
      if result.draw:check(safe.encloses(result.screen_box),"Whole caption avoids HUD")
    var offscreen=Caption.place_block(Vector2.ZERO,Vector2(100,30),10,Transform2D(0,Vector2(-50,150)),Rect2(0,0,width,360),safe)
    check(not offscreen.draw,"No offscreen captions pulled into safe region")
    var under_header=Caption.place_block(Vector2.ZERO,Vector2(100,30),10,Transform2D(0,Vector2(100,10)),Rect2(0,0,width,360),safe)
    check(under_header.draw,"HUD occlusion is not offscreen culling")
 var viewport=Rect2(0,0,640,360)
 var transform=Transform2D(0,Vector2(330,80))
 var old=Caption.place_block(Vector2(-60,-80),Vector2(230,30),10,transform,viewport)
 var fixed=Caption.place_block(Vector2(-60,-80),Vector2(230,30),10,transform,viewport,Rect2(0,57,640,282))
 check(old.screen_box.position.y<57 and fixed.screen_box.position.y>=65,"Old header-overlap negative control")
 check(not Caption.place_block(Vector2.ZERO,Vector2(100,60),10,transform,viewport,Rect2(0,100,640,20)).draw,"Insufficient safe space hides instead of covering HUD")
 # Regression: HUD-clamped caption must not cover its own painted icon.
 var Paint=load("res://campaign/views/objective_view.gd")
 for header in [57,71]:
  var hud_safe=Rect2(0,header,640,339-header)
  var icon=Rect2(316.5,81.5,28,28)
  var anchor=Transform2D(0,Vector2(330.5,115.5))
  var previous=Caption.place_block(Vector2(-60,-80),Vector2(163,27),10,anchor,viewport,hud_safe)
  check(previous.screen_box.intersects(icon),"0f52083 own-icon regression negative")
  var revised=Caption.place_block(Vector2(-60,-80),Vector2(163,27),10,anchor,viewport,hud_safe,icon)
  check(revised.draw and not revised.screen_box.intersects(icon.grow(4)),"Side placement clears harness ring and HUD")
 for kind in ["recover","rescue","plate","breaker","route","install","terminal"]:
  for width in [320,640]:
   for zoom in [.5,1.0,2.0]:
    for x in [12.0,width*.5,width-12.0]:
     for y in [70.0,180.0,320.0]:
      var tx=Transform2D(Vector2(zoom,0),Vector2(0,zoom),Vector2(x,y))
      var paint:Rect2=tx*Paint.painted_bounds(kind)
      var safe=Rect2(0,57,width,282)
      var result=Caption.place_block(Vector2(-60,-80),Vector2(110,35),10,tx,Rect2(0,0,width,360),safe,paint)
      check(not result.draw or (safe.grow(-8).encloses(result.screen_box) and not result.screen_box.intersects(paint.grow(4))),"Kind/edge/zoom placement clear or safely culled")
 view.position=Vector2(11,19);view.scale=Vector2(1.5,1.5)
 view.set_snapshot({"guidance":"Wrapped guidance ".repeat(15),"prompt":"[E] Harness"})
 var transformed=view.caption_safe_rect()
 var layout=view.playing_layout(view.data)
 check(is_equal_approx(transformed.position.y,19+1.5*layout.header_height),"HUD translated/scaled header bound")
 check(is_equal_approx(transformed.end.y,19+1.5*layout.context_top),"HUD translated/scaled footer bound")
 var presentation=Node2D.new();root.add_child(presentation)
 var caption=Caption.new();presentation.add_child(caption);presentation.hide()
 check(not caption.is_visible_in_tree(),"Blind-hidden parent remains authoritative")
 presentation.free();view.free();await process_frame
 print("CAPTION_SAFE_CONTRACT ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
