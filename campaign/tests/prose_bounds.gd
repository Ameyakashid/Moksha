extends SceneTree
func _initialize()->void:
 var view=load("res://campaign/views/campaign_hud.gd").new()
 var failures:Array[String]=[];var maximum:=0
 for d in preload("res://campaign/logic/campaign_data.gd").sectors():
  var size:=10
  var lines:Array=view.panel_lines(d.text.replace("\n"," "),size,594)
  while lines.size()>3 and size>8:
   size-=1;lines=view.panel_lines(d.text.replace("\n"," "),size,594)
  maximum=maxi(maximum,lines.size())
  if lines.size()>3:failures.append(d.id+" "+str(lines.size()))
 print("PROSE_BOUNDS max_lines=",maximum," failures=",failures)
 view.free();quit(0 if failures.is_empty() else 1)
