extends SceneTree
func _initialize():run.call_deferred()
func frames(n):
 for i in n:await physics_frame;await process_frame
func key(down,echo_=false):
 var e=InputEventKey.new();e.physical_keycode=KEY_D;e.pressed=down;e.echo=echo_;Input.parse_input_event(e);Input.flush_buffered_events()
func host_new():
 var h=load("res://campaign/campaign.tscn").instantiate();h.save_enabled=false;root.add_child(h);return h
func run():
 var a=host_new();a.start_new(true);await frames(3);key(true);await frames(2);a.free()
 var b=host_new();b.start_new(true);await frames(3)
 print("PRE_ECHO cp ",Input.get_action_strength("cp_right")," raw ",b._raw_campaign_input().right," actor ",b.player._input.x)
 key(true,true);await frames(2)
 print("POST_ECHO cp ",Input.get_action_strength("cp_right")," raw ",b._raw_campaign_input().right," actor ",b.player._input.x)
 key(false);b.free();quit()
