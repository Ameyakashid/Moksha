extends SceneTree
const Caption=preload("res://campaign/views/objective_caption.gd")
const HUD=preload("res://campaign/views/campaign_hud.gd")
const Owner=preload("res://campaign/views/campaign_hud_owner.gd")
var checks:=0
var failures:Array[String]=[]
func check(value:bool,label:String)->void:
 checks+=1
 if not value:failures.append(label);push_error(label)
func _initialize()->void:call_deferred("run")
func run()->void:
 var owner=Owner.new();var view=HUD.new();view.name="View";owner.add_child(view);root.add_child(owner)
 var snap:={"state":"playing","player_present":true,"guidance":"Isolate the stall bus: position 2 [E]","notice_visible":true,"notice":"Recover market flood key · COMPLETE — The key hangs over the stall it used to protect."}
 view.set_snapshot(snap)
 var exclusions:Array[Rect2]=view.caption_exclusion_rects()
 var layout:Dictionary=view.playing_layout(view.data)
 check(exclusions.size()==1,"One currently painted notice exclusion")
 check(exclusions[0]==Rect2(layout.context_x,layout.context_top,layout.context_width,layout.context_height),"Notice bounds derive from actual measured layout")
 check(owner.caption_exclusion_rects()==exclusions,"HUD owner forwards same geometry")
 var viewport:=Rect2(0,0,640,360)
 var tx:=Transform2D(0,Vector2(320,156))
 var paint:=Rect2(306,122,28,28)
 var old:=Caption.place_block(Vector2(-60,-66),Vector2(180,28),10,tx,viewport,view.caption_safe_rect(),paint)
 var revised:=Caption.place_block(Vector2(-60,-66),Vector2(180,28),10,tx,viewport,view.caption_safe_rect(),paint,null,exclusions)
 check(old.draw and old.screen_box.intersects(exclusions[0]),"Recorded key-toast overlap negative control")
 check(revised.draw and not revised.screen_box.intersects(exclusions[0].grow(4)),"Key caption moves clear of toast")
 check(not revised.screen_box.intersects(paint.grow(4)),"Moved caption still avoids its object")
 for text in ["Short notice",str(snap.notice),"Wrapped authored notice ".repeat(8)]:
  snap.notice=text;view.set_snapshot(snap)
  exclusions=view.caption_exclusion_rects()
  for width in [320,480,640]:
   var vp:=Rect2(0,0,width,360)
   var safe:Rect2=view.caption_safe_rect().intersection(vp)
   for zoom in [.5,1.0,2.0]:
    for x in [12.0,width*.5,width-12.0]:
     for y in [40.0,100.0,320.0]:
      var canvas:=Transform2D(Vector2(zoom,0),Vector2(0,zoom),Vector2(x,y))
      var icon:=Rect2(Vector2(x-12,y-30),Vector2(24,30))
      var result:=Caption.place_block(Vector2(-60,-60),Vector2(150,28),10,canvas,vp,safe,icon,null,exclusions)
      var valid:bool=not result.draw
      if result.draw:
       valid=safe.grow(-8).encloses(result.screen_box) and not result.screen_box.intersects(icon.grow(4))
       for obstacle in exclusions:valid=valid and not result.screen_box.intersects(obstacle.grow(4))
      check(valid,"Wrapped/edge/zoom caption wholly safe or hidden")
 var offscreen:=Caption.place_block(Vector2.ZERO,Vector2(100,30),10,Transform2D(0,Vector2(700,100)),viewport,view.caption_safe_rect(),null,null,exclusions)
 check(not offscreen.draw,"No offscreen objective dragged around a notice")
 check(not Caption.place_block(Vector2.ZERO,Vector2(100,30),10,Transform2D(0,Vector2(300,100)),viewport,Rect2(0,57,640,282),null,null,[Rect2(0,0,640,360)]).draw,"No available space hides caption")
 var dense:Array[Rect2]=[Rect2(0,0,320,360),Rect2(320,0,320,360)]
 check(not Caption.avoid_occupied(Rect2(200,100,100,30),Rect2(8,65,624,266),dense).draw,"Multiple occupied regions cannot bounce caption into another")
 snap.notice_visible=false;view.set_snapshot(snap)
 check(view.caption_exclusion_rects().is_empty(),"Disappeared notice retires exclusion immediately")
 var cleared:=Caption.place_block(Vector2(-60,-66),Vector2(180,28),10,tx,viewport,view.caption_safe_rect(),paint,null,view.caption_exclusion_rects())
 check(cleared==old,"No-notice layout retains original placement exactly")
 snap.notice_visible=true;snap.notice="";view.set_snapshot(snap)
 check(view.caption_exclusion_rects().is_empty(),"Empty notice has no occupied geometry")
 snap.notice="Notice";snap.state="paused";view.set_snapshot(snap)
 check(view.caption_exclusion_rects().is_empty(),"Modal does not expose stale playing notice")
 snap.state="playing";snap.panel_override=true;view.set_snapshot(snap)
 check(view.caption_exclusion_rects().is_empty(),"Override panel has no painted playing notice")
 snap.panel_override=false;view.position=Vector2(11,19);view.scale=Vector2(1.5,1.5);view.set_snapshot(snap)
 layout=view.playing_layout(view.data)
 var expected:Rect2=view.get_global_transform_with_canvas()*Rect2(layout.context_x,layout.context_top,layout.context_width,layout.context_height)
 check(view.caption_exclusion_rects()==[expected],"Translated/scaled HUD notice matches its paint")
 var parent=Node2D.new();var caption=Caption.new();parent.add_child(caption);root.add_child(parent);parent.hide()
 check(not caption.is_visible_in_tree(),"Blind-hidden parent remains authoritative")
 parent.free();owner.free();await process_frame
 print("NOTICE_CAPTION_RESULT ",JSON.stringify({"checks":checks,"failures":failures,"passed":failures.is_empty()}))
 quit(0 if failures.is_empty() else 1)
