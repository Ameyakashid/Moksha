extends Node
## Visual fixture only. Direct setup is NOT route/progression acceptance.
@export var start_fixture:int=0
var host:Node
func _ready()->void:
 process_mode=Node.PROCESS_MODE_ALWAYS
 DisplayServer.window_set_title("VISUAL QA FIXTURE — MOKSHA (not progression proof)")
 host=load("res://campaign/campaign.tscn").instantiate();add_child(host);host.save_enabled=false
 if start_fixture!=0:show_fixture.call_deferred(start_fixture)
 print("VISUAL_FIXTURE_KEYS F1-F5 levels; F6 sight panel; F7 upgrade; F9 final choice; F10 ending; F11 next district")
func _input(event:InputEvent)->void:
 if not event is InputEventKey or not event.pressed or event.echo:return
 var k:int=event.physical_keycode
 k={KEY_1:KEY_F1,KEY_2:KEY_F2,KEY_3:KEY_F3,KEY_4:KEY_F4,KEY_5:KEY_F5,KEY_6:KEY_F6,KEY_7:KEY_F7,KEY_8:-1,KEY_T:-2,KEY_Y:-3,KEY_H:-4,KEY_U:-5,KEY_V:-6,KEY_9:KEY_F9,KEY_0:KEY_F10,KEY_P:KEY_F11}.get(k,k)
 if k not in [-1,-2,-3,-4,-5,-6,KEY_F1,KEY_F2,KEY_F3,KEY_F4,KEY_F5,KEY_F6,KEY_F7,KEY_F9,KEY_F10,KEY_F11]:return
 get_viewport().set_input_as_handled();show_fixture.call_deferred(k)
func show_fixture(k:int)->void:
 print("VISUAL_FIXTURE_REQUEST ",k)
 get_tree().paused=false;host._pending_sector=-1;host._pending_retry=false
 if k==-6:
  host.blind=false;host.state="playing";host.load_sector(12);host.player.position=Vector2(3500,-760);host.chapter_left=0;return
 if k in [-2,-3,-4,-5]:
  host.blind=false;host.state="playing";host.load_sector(2);host.chapter_left=0
  if k==-2:
   for goal in host.goals:
    if goal.objective_id=="schematic":goal.interact()
   host.player.position=Vector2(3380,-145)
  elif k==-3:host.player.position=Vector2(6210,50)
  else:
   host.player.position=Vector2(2580,300)
   if k==-4:host.state="choice";host.choose_sight(true)
  print("VISUAL_FIXTURE_INITIAL_SETUP district=tram position=",host.player.position," blind=",host.blind)
  return
 if k==-1:
  host.blind=false;host.upgrades.assign(["force","agility","vitality","force"]);host.state="playing";host.load_sector(17);host.state="journal";get_tree().paused=true;return
 if k in [KEY_F1,KEY_F2,KEY_F3,KEY_F4,KEY_F5]:
  host.blind=false;host.state="playing";host.load_sector({KEY_F1:0,KEY_F2:6,KEY_F3:12,KEY_F4:18,KEY_F5:25}[k]);return
 if k==KEY_F11:
  host.state="playing";host.load_sector((host.sector+1)%host.sectors.size());return
 if k==KEY_F6:
  host.blind=false;host.state="playing";host.load_sector(6);host.state="choice";get_tree().paused=true;return
 if k==KEY_F7:
  host.state="playing";host.load_sector(5);host.state="upgrade";get_tree().paused=true;return
 host.blind=false;host.state="playing";host.load_sector(31)
 if k==KEY_F9:host.state="final_choice";get_tree().paused=true
 if k==KEY_F10:host.campaign_ending="public_record";host.complete_run()
