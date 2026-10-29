@tool
extends Node2D
## Optional decoration only. Never creates bodies, shapes, sensors or actors.
const Paint=preload("res://demo/views/favela_appearance.gd")
@export_enum("Building", "Cable", "Rooftop tech") var kind:=0:
 set(v):kind=clampi(v,0,2);queue_redraw()
@export var dimensions:=Vector2(100,86):
 set(v):dimensions=v;queue_redraw()
@export var variant:=0:
 set(v):variant=v;queue_redraw()
@export_range(0.0,1.0,0.01) var neon_amount:=0.25:
 set(v):neon_amount=clampf(v,0,1);queue_redraw()
@export var cable_end:=Vector2(180,12):
 set(v):cable_end=v;queue_redraw()
@export_range(0.0,120.0,1.0) var cable_sag:=22.0:
 set(v):cable_sag=maxf(0,v);queue_redraw()
@export var appearance:Paint:
 set(v):
  if appearance!=null and appearance.changed.is_connected(queue_redraw):appearance.changed.disconnect(queue_redraw)
  appearance=v
  if appearance!=null and not appearance.changed.is_connected(queue_redraw):appearance.changed.connect(queue_redraw)
  queue_redraw()
func _draw():
 if appearance==null or not is_finite(neon_amount):return
 if kind==1:
  if not cable_end.is_finite() or not is_finite(cable_sag):return
  var points:=PackedVector2Array()
  for n in 25:
   var t:=float(n)/24
   points.append(cable_end*t+Vector2(0,4*cable_sag*t*(1-t)))
  draw_polyline(points,appearance.cable,0.8,true)
  # Sparse junction tags, not bright screen-filling signage.
  if posmod(variant,3)==0:draw_rect(Rect2(points[12]-Vector2(2,0),Vector2(4,7)),appearance.inset)
  return
 if not dimensions.is_finite() or dimensions.x<16 or dimensions.y<16:return
 var w:=minf(dimensions.x,600);var h:=minf(dimensions.y,600)
 var v:=posmod(variant,997)
 if kind==2:
  if v%2==0:
   draw_rect(Rect2(-w*.26,-h*.63,w*.52,h*.48),appearance.wall)
   draw_rect(Rect2(-w*.26,-h*.63,w*.52,h*.48),appearance.outline,false,0.8)
   draw_line(Vector2(-w*.2,-h*.15),Vector2(-w*.25,0),appearance.outline,0.9)
   draw_line(Vector2(w*.2,-h*.15),Vector2(w*.25,0),appearance.outline,0.9)
   draw_line(Vector2(-w*.3,-h*.63),Vector2(w*.3,-h*.63),appearance.warm,0.9)
  else:
   draw_line(Vector2.ZERO,Vector2(0,-h),appearance.outline,1)
   draw_line(Vector2(-w*.35,-h*.7),Vector2(w*.35,-h*.7),appearance.outline,0.8)
   draw_arc(Vector2(0,-h*.67),w*.3,0.15,PI-.15,12,appearance.outline,0.8,true)
   draw_circle(Vector2(0,-h),1.2,appearance.neon*neon_amount)
  return
 # Bottom-left origin; irregular stacked roofline authored entirely in local space.
 draw_rect(Rect2(0,-h,w,h),appearance.wall)
 draw_rect(Rect2(0,-h,w,h),appearance.outline,false,0.8)
 var step:=8.0+float(v%4)*3
 draw_line(Vector2(-3,-h),Vector2(w+4,-h),appearance.warm,1)
 draw_line(Vector2(w*.66,-h),Vector2(w*.66,-h-step),appearance.outline,0.9)
 draw_line(Vector2(w*.66,-h-step),Vector2(w*.96,-h-step),appearance.outline,0.9)
 draw_line(Vector2(w*.96,-h-step),Vector2(w*.96,-h),appearance.outline,0.9)
 # Incomplete upper storeys and open terraces break the repeated apartment silhouette.
 if v%3!=1:
  var annex_w:=w*(.35+float(v%3)*.10)
  var annex_h:=h*(.14+float(v%5)*.025)
  var annex_x:=w*.08 if v%2==0 else w-annex_w-4
  var annex:=Rect2(annex_x,-h-annex_h,annex_w,annex_h)
  draw_rect(annex,appearance.wall)
  draw_rect(annex,appearance.outline,false,.9)
  draw_line(annex.position-Vector2(3,0),annex.position+Vector2(annex_w+3,0),appearance.warm,1)
  draw_rect(Rect2(annex_x+6,-h-annex_h+6,10,maxf(8,annex_h-9)),appearance.inset)
  for post in 4:
   var px:=w*.12+post*w*.24
   draw_line(Vector2(px,-h),Vector2(px,-h-6),appearance.outline,.8)
 # Small side stair profile; purely decorative and never climbable.
 if v%4==2:
  for stair in 5:
   var sp:=Vector2(w-19+stair*4,-h*.28-stair*5)
   draw_line(sp,sp+Vector2(6,0),appearance.warm,.8)
 var cols:=maxi(1,int(w/25));var rows:=maxi(1,int((h-14)/27))
 for row in rows:
  for col in cols:
   var p:=Vector2(9+col*24,-h+13+row*25)
   if p.x+11>w-4 or p.y+13> -8:continue
   draw_rect(Rect2(p,Vector2(11,13)),appearance.inset)
   if posmod(row*7+col*3+v,5)==0:
    draw_line(p+Vector2(1,11),p+Vector2(10,11),appearance.warm,1)
   else:
    draw_line(p,p+Vector2(11,0),appearance.outline.darkened(.15),0.6)
 if v%3==0:
  var y:float=-h*.4
  draw_line(Vector2(-5,y),Vector2(w*.53,y),appearance.outline,0.8)
  draw_line(Vector2(-5,y+9),Vector2(w*.53,y+9),appearance.outline,0.8)
  for i in 5:draw_line(Vector2(-5+i*w*.11,y),Vector2(-5+i*w*.11,y+9),appearance.outline,0.7)
 if v%4==1:
  draw_rect(Rect2(w*.72,-h*.65,w*.2,13),appearance.inset)
  for i in 3:draw_line(Vector2(w*.75,-h*.65+3+i*3),Vector2(w*.89,-h*.65+3+i*3),appearance.outline,0.6)
 if v%5==0 and neon_amount>0:
  var neon_ink:=appearance.neon;neon_ink.a*=sqrt(neon_amount)
  draw_line(Vector2(4,-h+5),Vector2(minf(w-4,32),-h+5),neon_ink,2.0,true)
