extends SceneTree
var results: Array = []
var failures: Array[String] = []
func _initialize():run.call_deferred()
func legacy(name: String):
 if name=="mission_ladder":
  var ladder=load("res://combat_pc/components/climbable.tscn").instantiate()
  return ladder
 if name=="mission_cargo":
  var cargo=load("res://scenes/props/crate.tscn").instantiate();cargo.set_script(load("res://demo/components/mission_prop.gd"));cargo.collision_mask=43;return cargo
 var script_name={"moving_lift":"mission_lift","relay_shutter":"relay_shutter","freight_receiver":"freight_receiver","freight_cradle":"freight_cradle"}[name]
 var script:=GDScript.new();script.source_code=FileAccess.get_file_as_string("res://simulation/evidence/physical_scene_baseline/"+script_name+".gd.txt");assert(script.reload()==OK)
 return script.new()
func stop(node):
 node.set_process(false);node.set_physics_process(false)
 if node is RigidBody2D:node.freeze=true
 for child in node.get_children():stop(child)
func viewport():
 var v:=SubViewport.new();v.size=Vector2i(640,360);v.world_2d=World2D.new();v.transparent_bg=true;v.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(v);return v
func bytes_sha(data: PackedByteArray):
 var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(data);return hash.finish().hex_encode()
func run():
 if DisplayServer.get_name()=="headless":push_error("Native rendering required");quit(2);return
 for name in ["moving_lift","relay_shutter","freight_receiver","freight_cradle","mission_ladder","mission_cargo"]:
  for variant in ["default","configured","hidden"]:
   var old=legacy(name);var fresh=load("res://simulation/world/"+name+".tscn").instantiate()
   var a=viewport();var b=viewport()
   for item in [old,fresh]:
    item.position=Vector2(320,240)
    if name=="freight_cradle":item.auto_spawn=false
    if variant=="configured":
     match name:
      "moving_lift":item.platform_size=Vector2(145,18)
      "relay_shutter":item.shutter_size=Vector2(31,161);item.set_open(true)
      "freight_receiver":item.interior_width=200;item.is_latched=true
      "freight_cradle":item.replacement_enabled=false
      "mission_ladder":item.height=200;item.width=28
    if variant=="hidden":item.hide()
   a.add_child(old);b.add_child(fresh);stop(old);stop(fresh)
   await process_frame
   await RenderingServer.frame_post_draw
   await RenderingServer.frame_post_draw
   var ai=a.get_texture().get_image();var bi=b.get_texture().get_image()
   var ad=ai.get_data();var bd=bi.get_data();var same=ad==bd;var label=name+"_"+variant
   var content_pixels:=0
   for index in range(3,ad.size(),4):
    if ad[index]>0:content_pixels+=1
   var content_ok:bool=content_pixels==0 if variant=="hidden" else content_pixels>0
   same= same and content_ok and ai.get_width()==640 and ai.get_height()==360
   results.append({"label":label,"passed":same,"old_rgba_sha256":bytes_sha(ad),"new_rgba_sha256":bytes_sha(bd),"width":ai.get_width(),"height":ai.get_height(),"content_pixels":content_pixels,"content_valid":content_ok})
   if not same:failures.append(label)
   if variant!="hidden":
    ai.save_png("res://simulation/evidence/physical_scene_"+label+"_old.png");bi.save_png("res://simulation/evidence/physical_scene_"+label+"_new.png")
   a.free();b.free()
 var report={"records":results,"failures":failures,"display_server":DisplayServer.get_name(),"scope":"Frozen native offscreen original-script vs packaged-scene presentation; not gameplay or audio."}
 var f=FileAccess.open("res://simulation/evidence/physical_scene_pixels.json",FileAccess.WRITE);f.store_string(JSON.stringify(report,"\t"));f.close();print("PHYSICAL SCENE PIXELS ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
