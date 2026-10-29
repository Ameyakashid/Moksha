@tool
extends Node2D
## Decorative deterministic composition. No world/host/audio/sonar dependency.
const Profile=preload("res://demo/views/room_backdrop_profile.gd")
const Style=preload("res://demo/views/favela_profile.gd")
const Building=preload("res://demo/views/favela_building.tscn")
const Cable=preload("res://demo/views/favela_cable.tscn")
const Rooftop=preload("res://demo/views/favela_rooftop.tscn")
@export var profile:Profile:
 set(v):
  if profile!=null and profile.changed.is_connected(_schedule_rebuild):profile.changed.disconnect(_schedule_rebuild)
  profile=v
  if profile!=null and not profile.changed.is_connected(_schedule_rebuild):profile.changed.connect(_schedule_rebuild)
  _schedule_rebuild()
@export var automatic_animation:=false:
 set(v):automatic_animation=v;set_process(v)
var animation_time:=0.0
@export var style:Style:
 set(v):
  if style!=null and style.changed.is_connected(_schedule_rebuild):style.changed.disconnect(_schedule_rebuild)
  style=v
  if style!=null and not style.changed.is_connected(_schedule_rebuild):style.changed.connect(_schedule_rebuild)
  _schedule_rebuild()
var _queued:=false
var _assembly:Node2D
func _enter_tree():
 if is_node_ready():_schedule_rebuild()
func _ready():
 set_process(automatic_animation)
 rebuild()
func _schedule_rebuild():
 queue_redraw()
 if not is_inside_tree() or _queued:return
 _queued=true
 rebuild.call_deferred()
func rebuild():
 _queued=false
 if not is_inside_tree():return
 if is_instance_valid(_assembly):remove_child(_assembly);_assembly.queue_free()
 _assembly=Node2D.new();_assembly.name="DecorativePieces";add_child(_assembly)
 if profile==null or not profile.has_valid_bounds() or style==null or not style.is_valid() or style.appearance==null:queue_redraw();return
 var b:Rect2=profile.room_bounds
 var columns:=clampi(ceili(b.size.x/style.block_spacing)+2,1,256)
 for band in 3:
  var depth:=float(band)/2
  var paint=style.appearance.duplicate(true)
  paint.wall=paint.wall.darkened((1-depth)*.43)
  paint.outline=paint.outline.darkened((1-depth)*.48)
  paint.warm=paint.warm.darkened((1-depth)*.42)
  paint.neon=paint.neon.darkened((1-depth)*.3)
  var last_roof:=Vector2.ZERO
  for col in columns:
   var n:=posmod(col*73+band*131+profile.visual_seed,997)
   var x:=b.position.x+(col-.5)*style.block_spacing+band*29+float(n%23)-11
   var hill:=sin(float(col)*.23+float(posmod(profile.visual_seed,19))*.12)*b.size.y*.095
   var bottom:=b.end.y-(2-band)*b.size.y*.20-hill
   var width:=style.block_spacing*(.63+float(n%19)*.026)
   var height:=b.size.y*(.22+float(n%23)*.006)
   var building=Building.instantiate();building.name="Building_%d_%03d"%[band,col]
   building.position=Vector2(x,bottom);building.dimensions=Vector2(width,height);building.variant=n
   building.appearance=paint;building.neon_amount=style.neon_amount;_assembly.add_child(building)
   var roof:Vector2=building.position+Vector2(width*.76,-height-12)
   if n%3==0:
    var tech=Rooftop.instantiate();tech.name="Roof_%d_%03d"%[band,col]
    tech.position=roof;tech.dimensions=Vector2(28,28+float(n%19));tech.variant=n;tech.appearance=paint
    tech.neon_amount=style.neon_amount;_assembly.add_child(tech)
   if col>0 and col%3==0:
    var wire=Cable.instantiate();wire.name="Cable_%d_%03d"%[band,col]
    wire.position=last_roof;wire.cable_end=roof-last_roof;wire.cable_sag=14+float(n%18)
    wire.appearance=paint;wire.variant=n;_assembly.add_child(wire)
   last_roof=roof
 queue_redraw()
func set_animation_time(seconds:float)->void:
 # Preserve the common absolute clock even though this art is static.
 if not is_finite(seconds):return
 animation_time=seconds
func _process(dt:float)->void:
 if automatic_animation and is_finite(dt) and dt>0:set_animation_time(animation_time+dt)
func _draw():
 if profile==null or not profile.has_valid_bounds() or style==null or not style.is_valid():return
 draw_rect(profile.room_bounds,style.sky)
