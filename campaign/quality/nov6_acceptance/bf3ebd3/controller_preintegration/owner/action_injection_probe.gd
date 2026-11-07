extends SceneTree
func _initialize(): run.call_deferred()
func run():
 var host=load("res://campaign/campaign.tscn").instantiate();host.save_enabled=false;root.add_child(host);host.start_new(true)
 Input.action_press("cp_right")
 print("ACTION_PRESS ",Input.get_action_strength("cp_right")," CAMPAIGN ",host._raw_campaign_input().right)
 Input.action_release("cp_right")
 var e=InputEventAction.new();e.action="cp_right";e.pressed=true;Input.parse_input_event(e);Input.flush_buffered_events()
 print("EVENT_ACTION ",Input.get_action_strength("cp_right")," CAMPAIGN ",host._raw_campaign_input().right)
 host.input_override={"right":1.0,"jump":true,"jump_pressed":true}
 print("EXPLICIT_OVERRIDE ",JSON.stringify(host._raw_campaign_input()))
 var release=e.duplicate();release.pressed=false;Input.parse_input_event(release);Input.flush_buffered_events();host.free();quit()
