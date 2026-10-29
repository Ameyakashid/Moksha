extends SceneTree
## Controlled UI fixtures: not a traversal or objective-completion test.
var failures:Array[String]=[]
var checks:=0
func check(value:bool,label:String)->void:
 checks+=1
 if not value:failures.append(label)
func _initialize()->void:run.call_deferred()
func run()->void:
 var host=load("res://campaign/campaign.tscn").instantiate();root.add_child(host);host.save_enabled=false;host.start_new(true)
 var view=load("res://campaign/views/campaign_hud.gd").new()
 for i in host.sectors.size():
  host.state="playing";paused=false;host.load_sector(i);host.upgrades.assign(["force","agility","vitality","force"]);host.state="journal"
  var rows:Array=host._journal_rows()
  check(not rows.is_empty(),"journal has authentic status "+str(i))
  for page in maxi(1,ceili(rows.size()/5.0)):
   host.journal_page=page
   var snap:Dictionary=host._hud_snapshot()
   check(view.panel_lines(snap.panel_body,9).size()*12<=174,"journal bounds "+str(i)+"/"+str(page))
   check("Page %d/"%(page+1) in snap.panel_body,"page indicator "+str(i))
   check("never elapsed time" not in snap.panel_body,"player-facing prose "+str(i))
  var lines:Array=view.panel_lines(host.sectors[i].text.replace("\n"," "),10,594)
  check(lines.size()<=3,"intro words fit "+str(i))
 host.state="playing";host.load_sector(17);host.state="journal";host.journal_page=0
 var right:=InputEventKey.new();right.pressed=true;right.keycode=KEY_RIGHT
 host._unhandled_key_input(right)
 check(host.journal_page==1,"logical arrow key pages forward")
 var left:=InputEventKey.new();left.pressed=true;left.physical_keycode=KEY_LEFT
 host._unhandled_key_input(left)
 check(host.journal_page==0,"physical arrow key pages backward")
 var d_key:=InputEventKey.new();d_key.pressed=true;d_key.physical_keycode=KEY_D
 host._unhandled_key_input(d_key);check(host.journal_page==1,"physical D pages forward")
 d_key.echo=true;host._unhandled_key_input(d_key);check(host.journal_page==1,"held repeat ignored")
 var a_key:=InputEventKey.new();a_key.pressed=true;a_key.physical_keycode=KEY_A
 host._unhandled_key_input(a_key);check(host.journal_page==0,"physical A pages backward")
 var escape:=InputEventKey.new();escape.pressed=true;escape.keycode=KEY_ESCAPE
 host._unhandled_key_input(escape);check(host.state=="playing" and not paused,"logical Esc returns")
 host.state="playing";host.load_sector(0);host.upgrades.clear();host.state="journal"
 check("Activate relay 1" in host._hud_snapshot().panel_body,"legacy relay appears")
 check("Build: neutral /" not in host._hud_snapshot().panel_body,"no dangling build separator")
 host.state="playing";host.load_sector(2)
 var breaker=host.goals.filter(func(goal):return goal.objective_id=="brake")[0]
 host.player.position=breaker.position
 var prompt:String=host._hud_snapshot().prompt
 check(prompt.begins_with("Requires: ") and "Route tram auxiliary current" in prompt and "[J]" not in prompt,"locked breaker explains requirement")
 breaker.completed=true
 check(host._hud_snapshot().prompt.begins_with("COMPLETE"),"latched complete takes precedence over later unset route")
 host.state="paused"
 check("TAB" in host._hud_snapshot().panel_body and "Reset district" in host._hud_snapshot().panel_footer,"pause gives journal/reset guidance")
 host.state="complete"
 check("promised human duration" not in host._hud_snapshot().panel_body,"ending prose no development disclaimer")
 print("PLAYER_GUIDANCE checks=",checks," failures=",failures)
 view.free();quit(0 if failures.is_empty() else 1)
