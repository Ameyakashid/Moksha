extends SceneTree
const ACTIONS := ["cp_left","cp_right","cp_up","cp_down","cp_jump","cp_roll","cp_attack","cp_shield"]
var host: Node
var checks := 0
var failures: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var label := "boot"
var hz := 60
var output := ""
var native: Dictionary = {}
var baseline_path := "res://campaign/quality/independent_multipad/baseline_campaign.gd"
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): hz=int(arg.trim_prefix("--hz="))
		if arg.begins_with("--out="): output=arg.trim_prefix("--out=" )
	Engine.physics_ticks_per_second=hz
	run.call_deferred()
func check(ok: bool, what: String, detail: Variant = null) -> void:
	checks+=1
	if not ok: failures.append({"case":label,"label":what,"detail":detail})
func frames(count: int) -> void:
	for i in count: await physics_frame; await process_frame
func key(code: int, pressed: bool) -> void:
	var e:=InputEventKey.new();e.physical_keycode=code;e.pressed=pressed
	Input.parse_input_event(e);Input.flush_buffered_events()
func joy(device: int, button: int, pressed: bool) -> void:
	var e:=InputEventJoypadButton.new();e.device=device;e.button_index=button;e.pressed=pressed
	Input.parse_input_event(e);Input.flush_buffered_events()
func axis(device: int, which: int, value: float) -> void:
	var e:=InputEventJoypadMotion.new();e.device=device;e.axis=which;e.axis_value=value
	Input.parse_input_event(e);Input.flush_buffered_events()
func release_all() -> void:
	for code in [KEY_A,KEY_D,KEY_W,KEY_S,KEY_LEFT,KEY_RIGHT,KEY_J,KEY_K,KEY_F,KEY_U,KEY_SPACE,KEY_C,KEY_SHIFT]:key(code,false)
	for device in [0,1,3]:
		for button in [JOY_BUTTON_A,JOY_BUTTON_B,JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_BACK,JOY_BUTTON_START,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER,JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT,JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN]:joy(device,button,false)
		axis(device,JOY_AXIS_LEFT_X,0);axis(device,JOY_AXIS_LEFT_Y,0)
	for name in InputMap.get_actions():Input.action_release(name)
func snapshot_native() -> Dictionary:
	var result: Dictionary={}
	for action in ACTIONS:
		var rows: Array=[]
		for event in InputMap.action_get_events(action):
			var properties: Dictionary={}
			for prop in event.get_property_list():
				if int(prop.usage)&PROPERTY_USAGE_STORAGE:properties[str(prop.name)]=event.get(prop.name)
			rows.append({"event":event,"id":event.get_instance_id(),"properties":properties})
		result[action]={"deadzone":InputMap.action_get_deadzone(action),"events":rows}
	return result
func check_native(what: String) -> void:
	for action in ACTIONS:
		check(InputMap.has_action(action),what+" native action retained "+action)
		var events:=InputMap.action_get_events(action)
		check(InputMap.action_get_deadzone(action)==native[action].deadzone,what+" exact native deadzone "+action)
		check(events.size()==native[action].events.size(),what+" native event count "+action)
		for i in mini(events.size(),native[action].events.size()):
			var old:Dictionary=native[action].events[i]
			check(events[i].get_instance_id()==old.id,what+" native event identity "+action)
			for prop in old.properties:check(events[i].get(prop)==old.properties[prop],what+" native property "+action+"/"+prop)
func restore_native() -> void:
	release_all()
	for action in ACTIONS:
		if not InputMap.has_action(action):InputMap.add_action(action,native[action].deadzone)
		InputMap.action_erase_events(action);InputMap.action_set_deadzone(action,native[action].deadzone)
		for row in native[action].events:
			for prop in row.properties:
				if row.event.get(prop)!=row.properties[prop]:row.event.set(prop,row.properties[prop])
			InputMap.action_add_event(action,row.event)
func create_host(baseline := false) -> Node:
	var node:Node=load(baseline_path).new() if baseline else load("res://campaign/campaign.tscn").instantiate()
	node.name="ProbeCampaign";node.save_enabled=false;root.add_child(node);node.start_new(true)
	return node
func fresh() -> void:
	release_all()
	if is_instance_valid(host):host.free()
	paused=false;await frames(2)
	host=create_host();await frames(3)
func aliases() -> Array:
	var result:Array=[]
	for action in InputMap.get_actions():
		if str(action).begins_with("__moksha_pad_"):result.append(action)
	return result
func dispatch_source(source: String, action: String, down: bool) -> void:
	var keys: Dictionary={"jump":KEY_SPACE,"attack":KEY_J,"shield":KEY_K,"roll":KEY_SHIFT}
	var buttons:Dictionary={"jump":JOY_BUTTON_A,"attack":JOY_BUTTON_X,"shield":JOY_BUTTON_LEFT_SHOULDER,"roll":JOY_BUTTON_RIGHT_SHOULDER}
	if source=="key":key(keys[action],down)
	else:joy(int(source),buttons[action],down)
func merged_edges() -> void:
	for action in ["jump","attack","shield","roll"]:
		for order in [["key","0","1","3"],["1","3","0","key"]]:
			label="merge_"+action+"_"+"_".join(order);await fresh()
			for index in order.size():
				dispatch_source(order[index],action,true)
				var raw:Dictionary=host._raw_campaign_input()
				observations.append({"case":label,"operation":"press "+order[index],"held":raw.get(action),"pressed":raw.get(action+"_pressed"),"released":raw.get(action+"_released",false)})
				check(bool(raw.get(action,false)),"any held source keeps action held",observations[-1])
				check(bool(raw.get(action+"_pressed",false))==(index==0),"only aggregate false-to-true makes pressed",observations[-1])
				check(not bool(raw.get(action+"_released",false)),"additional hold cannot release",observations[-1])
				await frames(2)
			for index in order.size():
				dispatch_source(order[index],action,false)
				var raw:Dictionary=host._raw_campaign_input()
				observations.append({"case":label,"operation":"release "+order[index],"held":raw.get(action),"pressed":raw.get(action+"_pressed"),"released":raw.get(action+"_released",false)})
				check(bool(raw.get(action,false))==(index<order.size()-1),"release one source preserves others",observations[-1])
				check(not bool(raw.get(action+"_pressed",false)),"release cannot press",observations[-1])
				check(bool(raw.get(action+"_released",false))==(index==order.size()-1),"only aggregate true-to-false makes released",observations[-1])
				await frames(2)
	check_native("after merged input")
func opposite_axes() -> void:
	label="opposite_axes";await fresh()
	var steps:Array=[ ["keyD",true,1.0],["joy1left",true,0.0],["keyD",false,-1.0],["joy3right",true,0.0],["joy1left",false,1.0],["joy3right",false,0.0] ]
	for step in steps:
		match step[0]:
			"keyD":key(KEY_D,step[1])
			"joy1left":joy(1,JOY_BUTTON_DPAD_LEFT,step[1])
			"joy3right":joy(3,JOY_BUTTON_DPAD_RIGHT,step[1])
		var raw:Dictionary=host._raw_campaign_input()
		check(is_equal_approx(float(raw.right)-float(raw.left),step[2]),"opposed native sources cancel and reappear",{"step":step,"left":raw.left,"right":raw.right})
		await frames(2)
	for device in [0,1,3]:
		axis(device,JOY_AXIS_LEFT_X,0.75);await frames(2)
		var raw:Dictionary=host._raw_campaign_input()
		check(float(raw.right)>0 and float(raw.left)==0,"stick uses corresponding positive axis",{"device":device,"raw":raw})
		axis(device,JOY_AXIS_LEFT_X,-0.75);await frames(2);raw=host._raw_campaign_input()
		check(float(raw.left)>0 and float(raw.right)==0,"stick reversal uses corresponding negative axis",{"device":device,"raw":raw})
		axis(device,JOY_AXIS_LEFT_X,0);await frames(2)
	check_native("after opposite axes")
func overlapping_hosts() -> void:
	label="overlapping_hosts";await fresh()
	var first:Node=host
	var first_names:Array=aliases()
	var second:Node=create_host();await frames(3)
	var second_names:Array=[]
	for action in aliases():
		if not first_names.has(action):second_names.append(action)
	check(first_names.size()==8 and second_names.size()==8 and aliases().size()==16,"overlapping hosts own disjoint aliases")
	key(KEY_D,true);joy(1,JOY_BUTTON_DPAD_RIGHT,true);await frames(2)
	check(first._raw_campaign_input().right==1.0 and second._raw_campaign_input().right==1.0,"both hosts independently receive held movement")
	check(Input.get_action_strength("cp_right")==1.0,"keyboard keeps original native action held")
	first.free();host=second
	check(aliases().size()==8,"one host releases only its eight aliases")
	check(Input.get_action_strength("cp_right")==1.0 and second._raw_campaign_input().right==1.0,"teardown keeps keyboard/native and surviving alias held")
	joy(1,JOY_BUTTON_DPAD_RIGHT,false);await frames(2)
	check(Input.get_action_strength("cp_right")==1.0 and second._raw_campaign_input().right==1.0,"nonzero pad release cannot cancel held keyboard")
	key(KEY_D,false);await frames(2)
	check(second._raw_campaign_input().right==0.0,"surviving host clears after last source release")
	joy(3,JOY_BUTTON_DPAD_RIGHT,true);await frames(2)
	second.free();host=null
	check(aliases().is_empty(),"last host restores alias namespace")
	joy(3,JOY_BUTTON_DPAD_RIGHT,false);await frames(2)
	host=create_host();await frames(3)
	check(host._raw_campaign_input().right==0.0,"new host has no retired nonzero-device held action")
	check_native("after overlapping hosts")
func live_remapping() -> void:
	label="custom_layout_at_entry"
	if is_instance_valid(host):host.free();host=null
	release_all()
	var custom:=InputEventKey.new();custom.physical_keycode=KEY_F
	InputMap.action_erase_events("cp_attack");InputMap.action_add_event("cp_attack",custom);InputMap.action_set_deadzone("cp_right",0.6)
	host=create_host();await frames(3)
	check(not host._controller_bindings._aliases.has("cp_attack"),"custom action is not replaced by default alias")
	key(KEY_F,true);await frames(2)
	check(host.player._input.attack,"custom keyboard action passes through original mapping")
	key(KEY_F,false);joy(1,JOY_BUTTON_X,true);await frames(2)
	check(not host.player._input.attack,"nonzero default pad does not silently override custom action")
	joy(1,JOY_BUTTON_X,false);axis(1,JOY_AXIS_LEFT_X,0.5);await frames(2)
	check(host._raw_campaign_input().right==0.0,"alias preserves customized native deadzone")
	axis(1,JOY_AXIS_LEFT_X,0.8);await frames(2)
	check(host._raw_campaign_input().right>0.0,"alias admits above customized native deadzone")
	release_all();host.free();host=null;restore_native();await fresh()
	label="live_custom_remap"
	var attack_alias:String=host._controller_bindings._aliases.cp_attack.name
	InputMap.action_erase_events("cp_attack");InputMap.action_add_event("cp_attack",custom)
	joy(1,JOY_BUTTON_X,true);await frames(2)
	check(not host.player._input.attack,"live custom remap disables stale alias")
	key(KEY_F,true);await frames(2)
	check(host.player._input.attack,"live custom remap reads current native input")
	key(KEY_F,false);joy(1,JOY_BUTTON_X,false);await frames(2)
	var custom_id:int=custom.get_instance_id()
	host.free();host=null
	check(InputMap.action_get_events("cp_attack").size()==1 and InputMap.action_get_events("cp_attack")[0].get_instance_id()==custom_id,"teardown preserves external live remap identity")
	check(not InputMap.has_action(attack_alias),"disabled private alias cleaned up")
	restore_native();await fresh()
	label="alias_external_edit_collision"
	var alias:String=host._controller_bindings._aliases.cp_right.name
	var events:=InputMap.action_get_events(alias)
	var edited:InputEvent=events[0]
	var existing:InputEvent=events[1]
	check(edited is InputEventKey and existing is InputEventKey,"collision fixture identifies two keyboard bindings")
	edited.physical_keycode=existing.physical_keycode
	var edited_id:=edited.get_instance_id()
	host.free();host=null
	var remaining:Array=InputMap.action_get_events(alias)
	check(remaining.any(func(event):return event.get_instance_id()==edited_id),"teardown preserves an externally edited alias resource even when it matches another owned binding",{"edited_id":edited_id,"remaining_ids":remaining.map(func(event):return event.get_instance_id())})
	if InputMap.has_action(alias):InputMap.erase_action(alias)
	restore_native();check_native("after live remapping")
func pre_ready_ownership() -> void:
	label="pre_ready_ownership"
	if is_instance_valid(host):host.free();host=null
	await frames(3)
	var before:int=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var prepass:Node=load("res://campaign/quality/independent_multipad/prepass_campaign.gd").new()
	prepass.free()
	var prepass_delta:int=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))-before
	var old:Node=load(baseline_path).new()
	var old_navigation:Node=old.gamepad_navigation
	old.free()
	var b2_unowned:=is_instance_valid(old_navigation)
	if is_instance_valid(old_navigation):old_navigation.free()
	before=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var candidate:Node=load("res://campaign/campaign.tscn").instantiate()
	var navigation:Node=candidate.gamepad_navigation
	var bindings:Node=candidate._controller_bindings
	var before_ready:Dictionary=candidate._raw_campaign_input()
	check(before_ready.has("right"),"unentered scene retains safe raw input fallback")
	candidate.free()
	var candidate_delta:int=int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))-before
	observations.append({"case":label,"prepass_orphan_delta":prepass_delta,"b2_navigation_unowned":b2_unowned,"candidate_orphan_delta":candidate_delta,"candidate_navigation_unowned":is_instance_valid(navigation),"candidate_bindings_unowned":is_instance_valid(bindings)})
	check(prepass_delta==0,"frozen pre-pass source creates no orphan on unentered disposal",observations[-1])
	check(candidate_delta==0 and not is_instance_valid(navigation) and not is_instance_valid(bindings),"candidate creates zero unentered-scene orphans relative to pre-pass source",observations[-1])
	# Test cleanup only: keep diagnostic process itself free of leaked nodes.
	if is_instance_valid(navigation):navigation.free()
	if is_instance_valid(bindings):bindings.free()
func snapshot_action(action: String) -> Dictionary:
	if not InputMap.has_action(action):return {"exists":false}
	var events:Array=[]
	for event in InputMap.action_get_events(action):
		var props:Dictionary={}
		for prop in event.get_property_list():
			if int(prop.usage)&PROPERTY_USAGE_STORAGE:props[str(prop.name)]=event.get(prop.name)
		events.append({"id":event.get_instance_id(),"properties":props})
	return {"exists":true,"deadzone":InputMap.action_get_deadzone(action),"events":events,"strength":Input.get_action_strength(action),"pressed":Input.is_action_pressed(action)}
func alias_adoption() -> void:
	if is_instance_valid(host):host.free();host=null
	release_all();await frames(2)
	for kind in ["insert","replace","remove","delete","deadzone_large","deadzone_small","axis_small","collision"]:
		label="alias_adoption_"+kind
		var adapter:Node=load("res://campaign/input/controller_bindings.gd").new();root.add_child(adapter)
		var alias:String=adapter._aliases.cp_right.name
		var events:=InputMap.action_get_events(alias)
		var initial:Dictionary=snapshot_action(alias)
		match kind:
			"insert":
				var extra:=InputEventKey.new();extra.physical_keycode=KEY_U;InputMap.action_add_event(alias,extra)
			"replace":
				var replaced:=events.duplicate();replaced[0]=events[0].duplicate();InputMap.action_erase_events(alias)
				for event in replaced:InputMap.action_add_event(alias,event)
			"remove":InputMap.action_erase_event(alias,events[0])
			"delete":InputMap.erase_action(alias)
			"deadzone_large":InputMap.action_set_deadzone(alias,0.6)
			"deadzone_small":InputMap.action_set_deadzone(alias,initial.deadzone+0.000001)
			"axis_small":events[-1].axis_value+=0.000001
			"collision":events[0].physical_keycode=events[1].physical_keycode
		key(KEY_RIGHT,true);await frames(2)
		var expected:Dictionary=snapshot_action(alias)
		check(expected!=initial,"fixture actually mutates engine-owned alias contents or identity",{"kind":kind})
		adapter.free()
		var after:Dictionary=snapshot_action(alias)
		observations.append({"case":label,"before":expected,"after":after})
		check(expected==after,"teardown preserves adopted alias exact contents, identity, deadzone and held state",{"kind":kind,"expected":expected,"actual":after})
		key(KEY_RIGHT,false);await frames(2)
		if InputMap.has_action(alias):InputMap.erase_action(alias)
	check_native("after alias adoption")
func keyboard_route(baseline: bool) -> Array:
	release_all()
	if is_instance_valid(host):host.free();host=null
	paused=false;await frames(3)
	host=create_host(baseline);await frames(4)
	var result:Array=[]
	for frame in 70:
		match frame:
			0:key(KEY_D,true)
			8:key(KEY_SPACE,true)
			9:key(KEY_SPACE,false)
			12:key(KEY_D,false)
			13:key(KEY_K,true)
			17:key(KEY_K,false)
			18:key(KEY_SHIFT,true)
			19:key(KEY_SHIFT,false)
			24:key(KEY_J,true)
			25:key(KEY_J,false)
			35:key(KEY_A,true)
			43:key(KEY_A,false)
			44:key(KEY_SPACE,true)
			45:key(KEY_SPACE,false)
		await frames(1)
		result.append({"position":host.player.position,"velocity":host.player.velocity,"action":host.player.main_action,"weapon":host.player.weapon_phase,"shield":host.player.shield_phase,"input":host.player._input.duplicate(true),"health":host.health.current_health})
	return result
func keyboard_parity() -> void:
	label="keyboard_physics_parity"
	var before:Array=await keyboard_route(true)
	var after:Array=await keyboard_route(false)
	for i in before.size():
		check(before[i].position.is_equal_approx(after[i].position) and before[i].velocity.is_equal_approx(after[i].velocity),"paired native keyboard position/velocity frame "+str(i),{"before":before[i],"after":after[i]})
		for field in ["action","weapon","shield","input","health"]:check(before[i][field]==after[i][field],"paired native keyboard "+field+" frame "+str(i))
	check_native("after keyboard parity")
func paused_release_one(baseline: bool, source: String, pause_frames: int) -> Dictionary:
	release_all()
	if is_instance_valid(host):host.free();host=null
	paused=false;await frames(3)
	host=create_host(baseline);await frames(4)
	dispatch_source(source,"jump",true);await frames(2)
	var before:float=host.player.velocity.y
	var cap:float=host.player.profile.jump_release_rise_cap
	key(KEY_ESCAPE,true);key(KEY_ESCAPE,false)
	var at_pause:Vector2=host.player.position
	dispatch_source(source,"jump",false);await frames(pause_frames)
	check(host.state=="paused" and host.player.position==at_pause,"pause freezes admitted jump while release arrives",{"source":source,"baseline":baseline})
	key(KEY_ESCAPE,true);key(KEY_ESCAPE,false);await frames(1)
	var result:Dictionary={"baseline":baseline,"source":source,"pause_frames":pause_frames,"before_velocity":before,"after_velocity":host.player.velocity.y,"release_cap":cap,"jump_released":host.player._input.jump_released,"jump":host.player._input.jump}
	check(before < -cap,"fixture starts a genuine rising jump",result)
	check(host.player._input.jump_released and not host.player._input.jump and host.player.velocity.y >= -cap-1.0,"paused release reaches actor and cuts ascent",result)
	return result
func paused_release_parity() -> void:
	label="paused_release_parity"
	for count in [1,2,5,8]:
		var reference:Dictionary=await paused_release_one(true,"key",count)
		observations.append(reference)
		for source in ["key","0","1","3"]:
			var candidate:Dictionary=await paused_release_one(false,source,count)
			observations.append(candidate)
			check(is_equal_approx(reference.before_velocity,candidate.before_velocity) and is_equal_approx(reference.after_velocity,candidate.after_velocity),"keyboard/device jump release agrees with exact b2 keyboard trajectory",{"reference":reference,"candidate":candidate})
	check_native("after paused release")
func alias_namespace_and_reentry() -> void:
	label="alias_namespace_collision"
	if is_instance_valid(host):host.free();host=null
	release_all();await frames(2)
	var adapter:Node=load("res://campaign/input/controller_bindings.gd").new()
	var sentinel:String="__moksha_pad_%d_cp_right"%adapter.get_instance_id()
	var event:=InputEventKey.new();event.physical_keycode=KEY_U
	InputMap.add_action(sentinel,0.61);InputMap.action_add_event(sentinel,event)
	var sentinel_deadzone:float=InputMap.action_get_deadzone(sentinel)
	root.add_child(adapter)
	check(adapter._aliases.cp_right.name!=sentinel and InputMap.has_action(adapter._aliases.cp_right.name),"private alias collision uses a distinct owned name")
	adapter.free()
	check(InputMap.has_action(sentinel) and InputMap.action_get_deadzone(sentinel)==sentinel_deadzone and InputMap.action_get_events(sentinel).size()==1 and InputMap.action_get_events(sentinel)[0]==event,"teardown preserves preexisting namespace collision identity and deadzone")
	InputMap.erase_action(sentinel)
	label="host_tree_reentry";await fresh()
	var names:Array=aliases()
	joy(1,JOY_BUTTON_DPAD_RIGHT,true);await frames(2)
	root.remove_child(host)
	check(aliases().is_empty(),"removing host retires owned aliases")
	joy(1,JOY_BUTTON_DPAD_RIGHT,false);await frames(2)
	root.add_child(host);await frames(2)
	check(aliases().size()==8 and host._raw_campaign_input().right==0.0,"reentered host recreates aliases without held residue",{"aliases":aliases(),"raw":host._raw_campaign_input(),"source":InputMap.action_get_events("cp_right").map(func(e):return e.as_text())})
	joy(3,JOY_BUTTON_DPAD_RIGHT,true);await frames(2)
	check(host._raw_campaign_input().right==1.0,"reentered host admits a fresh nonzero controller")
	joy(3,JOY_BUTTON_DPAD_RIGHT,false);await frames(2)
	check_native("after alias namespace/reentry")

func dispatch_movement(source: String, down: bool, echo_event := false) -> void:
	if source=="key":
		var e:=InputEventKey.new();e.physical_keycode=KEY_D;e.pressed=down;e.echo=echo_event
		Input.parse_input_event(e);Input.flush_buffered_events()
	elif source.begins_with("axis"):
		axis(int(source.trim_prefix("axis")),JOY_AXIS_LEFT_X,0.9 if down else 0.0)
	else:joy(int(source),JOY_BUTTON_DPAD_RIGHT,down)
func premount_held_boundaries() -> void:
	for source in ["key","0","1","3","axis0","axis1","axis3"]:
		label="premount_held_movement_"+source
		await fresh();dispatch_movement(source,true);await frames(2)
		check(host.player._input.x>0,"fixture admits movement before prior host teardown")
		host.free();host=null
		host=create_host();await frames(3)
		check(host.player._input.x==0,"already held movement does not cross new-host start boundary")
		dispatch_movement(source,true,true);await frames(2)
		check(host.player._input.x==0,"repeat event for preheld movement does not bypass new-host boundary",{"source":source,"raw":host._raw_campaign_input(),"actor":host.player._input})
		dispatch_movement(source,false);await frames(2)
		dispatch_movement(source,true);await frames(2)
		check(host.player._input.x>0,"fresh movement after release rearms new host")
		dispatch_movement(source,false);await frames(2)
	for source in ["key","0","1","3"]:
		for action in ["jump","attack","shield","roll"]:
			label="premount_held_"+action+"_"+source
			await fresh();dispatch_source(source,action,true);await frames(2)
			check(bool(host.player._input.get(action)),"fixture admits action before prior host teardown")
			host.free();host=null
			host=create_host();await frames(3)
			check(not bool(host.player._input.get(action)),"already held action does not cross new-host start boundary")
			if source=="key":
				var keys:Dictionary={"jump":KEY_SPACE,"attack":KEY_J,"shield":KEY_K,"roll":KEY_SHIFT}
				var e:=InputEventKey.new();e.physical_keycode=keys[action];e.pressed=true;e.echo=true
				Input.parse_input_event(e);Input.flush_buffered_events()
			else:dispatch_source(source,action,true)
			await frames(2)
			check(not bool(host.player._input.get(action)),"repeat event for preheld action does not bypass new-host boundary",{"source":source,"action":action,"raw":host._raw_campaign_input(),"actor":host.player._input})
			dispatch_source(source,action,false);await frames(2)
			dispatch_source(source,action,true);await frames(1)
			check(bool(host.player._input.get(action)),"fresh action after release rearms new host")
			dispatch_source(source,action,false);await frames(2)
	check_native("after premount held boundaries")
func overlap_during_hold() -> void:
	for source in ["key","0","1","3","axis1","axis3"]:
		label="overlap_during_hold_"+source
		await fresh();dispatch_movement(source,true);await frames(2)
		var first:Node=host
		check(first.player._input.x>0,"first host admits fresh held input")
		var second:Node=create_host();await frames(2)
		check(first.player._input.x>0 and second.player._input.x==0,"new host quarantines preheld input without muting existing host")
		dispatch_movement(source,true,true);await frames(2)
		check(first.player._input.x>0 and second.player._input.x==0,"repeat while hosts overlap remains local to admitted host")
		second.free();await frames(2)
		check(first.player._input.x>0,"quarantined host teardown preserves other host held state")
		dispatch_movement(source,false);await frames(2)
		check(first.player._input.x==0,"existing host releases normally after overlapping teardown")
	check_native("after overlap during hold")

func detached_disconnect() -> void:
	label="detached_disconnect";await fresh()
	joy(1,JOY_BUTTON_DPAD_RIGHT,true);await frames(2)
	check(host.gamepad_navigation.active_controller==1,"fixture selects active controller through actual event")
	root.remove_child(host)
	Input.joy_connection_changed.emit(3,false)
	check(host.state=="playing" and not paused,"unrelated disconnect cannot affect detached host")
	Input.joy_connection_changed.emit(1,false)
	check(host.state=="playing" and not host._focus_pause_active and not paused,"active disconnect outside SceneTree leaves host state intact")
	# A window focus callback can also outlive tree membership.
	host._on_window_focus_exited()
	check(host.state=="playing" and not host._focus_pause_active and not paused,"detached direct focus notification is harmless")
	joy(1,JOY_BUTTON_DPAD_RIGHT,false);await frames(2)
	root.add_child(host);await frames(2)
	check(host.state=="playing" and not paused,"re-added host retains consistent gameplay/tree pause state")
	joy(3,JOY_BUTTON_DPAD_RIGHT,true);await frames(2)
	Input.joy_connection_changed.emit(1,false)
	check(host.state=="playing" and not paused,"re-added host ignores unrelated disconnect")
	Input.joy_connection_changed.emit(3,false)
	check(host.state=="paused" and host._focus_pause_active and paused,"re-added host still pauses for active disconnect")
	joy(3,JOY_BUTTON_DPAD_RIGHT,false);key(KEY_ESCAPE,true);key(KEY_ESCAPE,false);await frames(2)
	check(host.state=="playing" and not paused,"explicit resume works after re-added active disconnect")
	check_native("after detach/disconnect")

func run() -> void:
	preload("res://combat_pc/player.gd").ensure_default_inputs();native=snapshot_native()
	await merged_edges();await opposite_axes();await overlapping_hosts();await live_remapping();await pre_ready_ownership();await alias_adoption();await keyboard_parity();await paused_release_parity();await alias_namespace_and_reentry();await premount_held_boundaries();await overlap_during_hold();await detached_disconnect()
	release_all()
	if is_instance_valid(host):host.free();host=null
	await frames(2)
	check(aliases().is_empty(),"no unowned aliases after cleanup")
	var result:Dictionary={"passed":failures.is_empty(),"checks":checks,"failures":failures,"observations":observations,"hz":hz,"harness_sha256":FileAccess.get_sha256(get_script().resource_path),"scope":"Independent real Input.parse_input_event composition/lifecycle tests, exact native InputMap identity/property/deadzone preservation, and paired keyboard actor physics against b2. Explicit alias-edit and unentered-scene disposal fixtures are isolated API lifecycle tests, not full gameplay."}
	if not output.is_empty():FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("INDEPENDENT_MULTIPAD_RESULT "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
