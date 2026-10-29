extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
 var host=load("res://campaign/campaign.tscn").instantiate();root.add_child(host);host.save_enabled=false;host.start_new(true)
 var view=load("res://campaign/views/campaign_hud.gd").new()
 var max_lines:=0;var worst:="";var errors:Array[String]=[]
 for i in host.sectors.size():
  host.load_sector(i);host.upgrades.assign(["force","agility","vitality","force"]);host.state="journal"
  var pages:=maxi(1,ceili(host._journal_rows().size()/5.0))
  for page in pages:
   host.journal_page=page
   var snap:Dictionary=host._hud_snapshot();var lines:Array=view.panel_lines(snap.panel_body,9)
   if lines.size()>max_lines:max_lines=lines.size();worst=host.sectors[i].id
   if lines.size()*12>174:errors.append(host.sectors[i].id+" page"+str(page)+" lines"+str(lines.size()))
   if "neutral /\n" in snap.panel_body:errors.append("dangling separator")
 print("JOURNAL_BOUNDS max=",max_lines," worst=",worst," failures=",errors)
 view.free();quit(0 if errors.is_empty() else 1)
