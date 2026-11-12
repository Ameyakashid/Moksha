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
 var presentation=Node2D.new();root.add_child(presentation)
 var caption=Caption.new();presentation.add_child(caption);presentation.hide()
 check(not caption.is_visible_in_tree(),"Blind-hidden parent remains authoritative")
 presentation.free();view.free();await process_frame
 print("CAPTION_SAFE_CONTRACT ",checks," checks; failures=",failures)
 quit(0 if failures.is_empty() else 1)
